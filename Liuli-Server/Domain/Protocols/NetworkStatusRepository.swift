import Foundation

/// Repository protocol for monitoring network status
public protocol NetworkStatusRepository: Sendable {
    /// Observe real-time network status updates
    nonisolated func observeStatus() -> AsyncStream<NetworkStatus>

    /// Enable bridge (start listening)
    func enableBridge() async throws

    /// Disable bridge (stop accepting new connections, keep existing)
    func disableBridge() async throws
}
