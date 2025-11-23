import Foundation
import Security
import CryptoKit

/// Actor responsible for generating and managing self-signed TLS certificates
/// Certificates are used for TOFU (Trust-On-First-Use) authentication
actor CertificateGenerator {
    private let keychainService: KeychainServiceProtocol

    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

    /// Generate self-signed certificate on first launch
    /// Returns certificate and SPKI fingerprint (SHA-256)
    func generateSelfSignedCertificate() async throws -> (SecCertificate, String) {
        // Check if certificate already exists
        if let existingCert = try? await keychainService.loadCertificate() {
            let fingerprint = try calculateSPKIFingerprint(certificate: existingCert)
            return (existingCert, fingerprint)
        }

        // Generate new RSA keypair
        let parameters: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: false
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
            throw CertificateError.keyGenerationFailed(error?.takeRetainedValue() as? Error)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CertificateError.publicKeyExtractionFailed
        }

        // Create certificate
        let deviceName = Host.current().localizedName ?? "Liuli-Server"
        let certificate = try createX509Certificate(
            publicKey: publicKey,
            privateKey: privateKey,
            subjectName: "CN=\(deviceName)",
            validityYears: 10
        )

        // Store in Keychain
        try await keychainService.storeCertificate(certificate, privateKey: privateKey)

        // Calculate fingerprint
        let fingerprint = try calculateSPKIFingerprint(certificate: certificate)

        return (certificate, fingerprint)
    }

    /// Calculate SHA-256 fingerprint of certificate's SPKI (Subject Public Key Info)
    /// Returns hex-encoded string (64 characters)
    func calculateSPKIFingerprint(certificate: SecCertificate) throws -> String {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw CertificateError.publicKeyExtractionFailed
        }

        var error: Unmanaged<CFError>?
        guard let spkiData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw CertificateError.spkiExtractionFailed(error?.takeRetainedValue() as? Error)
        }

        let hash = SHA256.hash(data: spkiData)
        return hash.compactMap { String(format: "%02X", $0) }.joined()
    }

    /// Regenerate certificate (e.g., after suspected compromise)
    /// Invalidates all client pins - forces re-TOFU
    func regenerateCertificate() async throws -> (SecCertificate, String) {
        // Delete existing certificate
        try await keychainService.deleteCertificate()

        // Generate new certificate
        return try await generateSelfSignedCertificate()
    }

    // MARK: - Private X.509 Certificate Creation

    private func createX509Certificate(
        publicKey: SecKey,
        privateKey: SecKey,
        subjectName: String,
        validityYears: Int
    ) throws -> SecCertificate {
        // This is a simplified implementation
        // In production, use OpenSSL or Security framework APIs to create proper X.509 certificate

        // For now, we'll create a certificate using SecCertificateCreateWithData
        // In a real implementation, this would involve:
        // 1. Create X.509 certificate structure
        // 2. Add subject, issuer, validity period
        // 3. Add public key
        // 4. Sign with private key
        // 5. Encode as DER

        // Placeholder: Generate minimal self-signed certificate
        let certificateData = try generateMinimalCertificate(
            publicKey: publicKey,
            privateKey: privateKey,
            subjectName: subjectName,
            validityYears: validityYears
        )

        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw CertificateError.certificateCreationFailed
        }

        return certificate
    }

    private func generateMinimalCertificate(
        publicKey: SecKey,
        privateKey: SecKey,
        subjectName: String,
        validityYears: Int
    ) throws -> Data {
        // IMPLEMENTATION NOTE:
        // This is a placeholder. In production, integrate with:
        // - OpenSSL via Swift Package (e.g., swift-crypto)
        // - Or use Security framework's certificate creation APIs
        // - Or shell out to `openssl` command-line tool

        // For MVP: Use simplified approach with Security framework
        // Generate certificate request and self-sign

        throw CertificateError.notImplemented
    }
}

// MARK: - Errors

public enum CertificateError: Error, LocalizedError {
    case keyGenerationFailed(Error?)
    case publicKeyExtractionFailed
    case spkiExtractionFailed(Error?)
    case certificateCreationFailed
    case notImplemented

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let underlying):
            return "Failed to generate RSA keypair: \(underlying?.localizedDescription ?? "unknown error")"
        case .publicKeyExtractionFailed:
            return "Failed to extract public key from certificate"
        case .spkiExtractionFailed(let underlying):
            return "Failed to extract SPKI data: \(underlying?.localizedDescription ?? "unknown error")"
        case .certificateCreationFailed:
            return "Failed to create X.509 certificate"
        case .notImplemented:
            return "Certificate generation not fully implemented - requires OpenSSL integration"
        }
    }
}

// MARK: - Protocol

public protocol KeychainServiceProtocol: Sendable {
    func storeCertificate(_ certificate: SecCertificate, privateKey: SecKey) async throws
    func loadCertificate() async throws -> SecCertificate
    func deleteCertificate() async throws
}
