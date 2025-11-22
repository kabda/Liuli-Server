import Foundation

/// Track and monitor connection statistics use case (FR-031 to FR-035)
public struct TrackStatisticsUseCase: Sendable {
    private let connectionRepository: ConnectionRepository

    public init(connectionRepository: ConnectionRepository) {
        self.connectionRepository = connectionRepository
    }

    /// Get current statistics
    public func execute() async -> ConnectionStatistics {
        await connectionRepository.getStatistics()
    }

    /// Observe real-time statistics updates (FR-028: updated every 1 second)
    public func observeStatistics() -> AsyncStream<ConnectionStatistics> {
        connectionRepository.observeStatistics()
    }

    /// Get active connections
    public func getActiveConnections() async -> [SOCKS5Connection] {
        await connectionRepository.getActiveConnections()
    }
}
