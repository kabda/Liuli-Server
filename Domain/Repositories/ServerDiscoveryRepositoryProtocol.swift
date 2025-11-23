import Foundation

/// Protocol for discovering Liuli-Server instances on local network (iOS/Android clients)
/// Uses mDNS/Bonjour to find available servers
public protocol ServerDiscoveryRepositoryProtocol: Sendable {
    /// Start discovering servers on local network
    /// - Returns: AsyncStream of discovered servers (updates as servers appear/disappear)
    func startDiscovery() -> AsyncStream<DiscoveredServer>

    /// Stop discovering servers
    func stopDiscovery() async
}

// MARK: - Errors

public enum ServerDiscoveryError: Error, LocalizedError {
    case browserFailed(reason: String)
    case permissionDenied
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .browserFailed(let reason):
            return "Server discovery failed: \(reason)"
        case .permissionDenied:
            return "Local network access permission denied"
        case .networkUnavailable:
            return "Network unavailable - ensure WiFi is connected"
        }
    }
}
