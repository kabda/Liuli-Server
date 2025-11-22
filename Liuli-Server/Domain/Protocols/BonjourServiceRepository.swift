import Foundation

/// Bonjour/mDNS service advertisement (FR-001 to FR-006)
public protocol BonjourServiceRepository: Sendable {
    /// Start advertising Bonjour service
    func startAdvertising(port: UInt16, deviceName: String) async throws

    /// Stop advertising Bonjour service
    func stopAdvertising() async throws

    /// Check if currently advertising
    func isAdvertising() async -> Bool
}
