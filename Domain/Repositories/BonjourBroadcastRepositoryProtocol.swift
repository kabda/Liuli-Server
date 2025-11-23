import Foundation

/// Protocol for Bonjour service broadcasting (macOS server)
/// Announces server presence on local network via mDNS
public protocol BonjourBroadcastRepositoryProtocol: Sendable {
    /// Start broadcasting server availability
    /// - Parameter config: Broadcast configuration (device name, port, certificate hash, etc.)
    /// - Throws: BonjourError if broadcast fails
    func startBroadcasting(config: ServiceBroadcast) async throws

    /// Stop broadcasting (e.g., when bridge service stops)
    /// - Throws: BonjourError if not currently broadcasting
    func stopBroadcasting() async throws

    /// Update bridge status in TXT record (without full restart)
    /// - Parameter status: New bridge status (active/inactive)
    /// - Throws: BonjourError if not currently broadcasting
    func updateBridgeStatus(_ status: ServiceBroadcast.BridgeStatus) async throws
}

// MARK: - Errors

public enum BonjourError: Error, LocalizedError {
    case publishFailed(reason: String)
    case notBroadcasting
    case invalidConfiguration

    public var errorDescription: String? {
        switch self {
        case .publishFailed(let reason):
            return "Bonjour broadcast failed: \(reason)"
        case .notBroadcasting:
            return "No active broadcast to update or stop"
        case .invalidConfiguration:
            return "Invalid broadcast configuration"
        }
    }
}
