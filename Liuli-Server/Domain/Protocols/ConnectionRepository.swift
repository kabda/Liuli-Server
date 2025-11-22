import Foundation

/// Connection tracking and statistics (FR-031 to FR-035)
public protocol ConnectionRepository: Sendable {
    /// Track a new connection
    func trackConnection(_ connection: SOCKS5Connection) async

    /// Update connection statistics
    func updateConnection(id: UUID, bytesUploaded: UInt64, bytesDownloaded: UInt64) async

    /// Remove connection (when closed)
    func removeConnection(id: UUID) async

    /// Get all active connections
    func getActiveConnections() async -> [SOCKS5Connection]

    /// Get connection statistics
    func getStatistics() async -> ConnectionStatistics

    /// Observe statistics changes
    func observeStatistics() -> AsyncStream<ConnectionStatistics>
}
