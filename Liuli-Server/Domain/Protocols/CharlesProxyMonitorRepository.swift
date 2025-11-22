import Foundation

/// Repository protocol for checking Charles proxy availability
public protocol CharlesProxyMonitorRepository: Sendable {
    /// Poll Charles availability at regular intervals
    nonisolated func observeAvailability(interval: TimeInterval) -> AsyncStream<CharlesStatus>

    /// Check availability once (for manual refresh)
    func checkAvailability(host: String, port: UInt16) async -> CharlesStatus
}
