import Foundation
import Security

/// Actor providing secure storage for certificates and private keys in macOS Keychain
actor KeychainService: KeychainServiceProtocol {
    private let serviceName = "com.liuli.server.certificate"
    private let certificateLabel = "Liuli Server Certificate"

    // MARK: - Certificate Storage

    func storeCertificate(_ certificate: SecCertificate, privateKey: SecKey) async throws {
        // Store certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecValueRef as String: certificate,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        var status = SecItemAdd(certQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing certificate
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassCertificate,
                kSecAttrLabel as String: certificateLabel
            ]
            let updateAttributes: [String: Any] = [
                kSecValueRef as String: certificate
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }

        // Store private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: certificateLabel.data(using: .utf8)!,
            kSecValueRef as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        status = SecItemAdd(keyQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing key
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationLabel as String: certificateLabel.data(using: .utf8)!
            ]
            let updateAttributes: [String: Any] = [
                kSecValueRef as String: privateKey
            ]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    func loadCertificate() async throws -> SecCertificate {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecReturnRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }

        guard let certificate = result as! SecCertificate? else {
            throw KeychainError.invalidData
        }

        return certificate
    }

    func deleteCertificate() async throws {
        // Delete certificate
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel
        ]

        var status = SecItemDelete(certQuery as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }

        // Delete private key
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: certificateLabel.data(using: .utf8)!
        ]

        status = SecItemDelete(keyQuery as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Private Key Access

    func loadPrivateKey() async throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: certificateLabel.data(using: .utf8)!,
            kSecReturnRef as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }

        guard let privateKey = result as! SecKey? else {
            throw KeychainError.invalidData
        }

        return privateKey
    }
}

// MARK: - Errors

public enum KeychainError: Error, LocalizedError {
    case storeFailed(OSStatus)
    case notFound
    case invalidData
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store item in Keychain: \(status)"
        case .notFound:
            return "Item not found in Keychain"
        case .invalidData:
            return "Invalid data retrieved from Keychain"
        case .deleteFailed(let status):
            return "Failed to delete item from Keychain: \(status)"
        }
    }
}
