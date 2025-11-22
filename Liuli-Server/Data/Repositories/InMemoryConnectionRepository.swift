import Foundation

/// In-memory connection tracking repository (FR-031 to FR-035)
public actor InMemoryConnectionRepository: ConnectionRepository {
    private var activeConnections: [UUID: SOCKS5Connection] = [:]
    private var statistics: ConnectionStatistics
    private var statisticsContinuation: AsyncStream<ConnectionStatistics>.Continuation?

    public init() {
        self.statistics = ConnectionStatistics()
    }

    public func trackConnection(_ connection: SOCKS5Connection) async {
        activeConnections[connection.id] = connection
        updateStatistics()
        Logger.connections.info("Tracking connection: \(connection.id) from \(connection.sourceIP)")
    }

    public func updateConnection(
        id: UUID,
        bytesUploaded: UInt64,
        bytesDownloaded: UInt64
    ) async {
        guard var connection = activeConnections[id] else { return }

        connection = connection.with(
            bytesUploaded: bytesUploaded,
            bytesDownloaded: bytesDownloaded
        )

        activeConnections[id] = connection
        updateStatistics()
    }

    public func removeConnection(id: UUID) async {
        guard let connection = activeConnections.removeValue(forKey: id) else { return }

        // Add to historical connections
        var closedConnection = connection.with(state: .closed)
        statistics = statistics.addingConnection(closedConnection)

        updateStatistics()
        Logger.connections.info("Removed connection: \(id)")
    }

    public func getActiveConnections() async -> [SOCKS5Connection] {
        Array(activeConnections.values)
    }

    public func getStatistics() async -> ConnectionStatistics {
        statistics
    }

    public func observeStatistics() -> AsyncStream<ConnectionStatistics> {
        AsyncStream { continuation in
            self.statisticsContinuation = continuation

            // Send current state immediately
            continuation.yield(self.statistics)
        }
    }

    private func updateStatistics() {
        let activeCount = activeConnections.count
        let totalBytes = activeConnections.values.reduce(0) { $0 + $1.totalBytes }

        statistics = ConnectionStatistics(
            totalConnectionCount: statistics.totalConnectionCount,
            activeConnectionCount: activeCount,
            totalBytesUploaded: statistics.totalBytesUploaded,
            totalBytesDownloaded: statistics.totalBytesDownloaded,
            currentThroughput: 0, // TODO: Calculate from recent byte counts
            historicalConnections: statistics.historicalConnections,
            sessionStartTime: statistics.sessionStartTime
        )

        statisticsContinuation?.yield(statistics)
    }
}
