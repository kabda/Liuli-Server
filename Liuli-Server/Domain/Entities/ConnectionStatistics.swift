import Foundation

/// Real-time and historical traffic metrics (FR-031, FR-035, session-scoped)
public struct ConnectionStatistics: Sendable, Equatable {
    /// Total number of connections in this session
    public let totalConnectionCount: Int

    /// Currently active connections
    public let activeConnectionCount: Int

    /// Total bytes uploaded across all connections
    public let totalBytesUploaded: UInt64

    /// Total bytes downloaded across all connections
    public let totalBytesDownloaded: UInt64

    /// Current throughput in bytes per second
    public let currentThroughput: UInt64

    /// Historical connection log (last 50 connections, FR-035)
    public let historicalConnections: [SOCKS5Connection]

    /// Session start time (reset on app launch)
    public let sessionStartTime: Date

    public init(
        totalConnectionCount: Int = 0,
        activeConnectionCount: Int = 0,
        totalBytesUploaded: UInt64 = 0,
        totalBytesDownloaded: UInt64 = 0,
        currentThroughput: UInt64 = 0,
        historicalConnections: [SOCKS5Connection] = [],
        sessionStartTime: Date = Date()
    ) {
        self.totalConnectionCount = totalConnectionCount
        self.activeConnectionCount = activeConnectionCount
        self.totalBytesUploaded = totalBytesUploaded
        self.totalBytesDownloaded = totalBytesDownloaded
        self.currentThroughput = currentThroughput
        self.historicalConnections = Array(historicalConnections.suffix(50)) // FR-035: last 50 only
        self.sessionStartTime = sessionStartTime
    }

    /// Total bytes transferred (uploaded + downloaded)
    public var totalBytesTransferred: UInt64 {
        totalBytesUploaded + totalBytesDownloaded
    }

    /// Session duration
    public var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    /// Add a new connection to statistics
    public func addingConnection(_ connection: SOCKS5Connection) -> ConnectionStatistics {
        var updatedHistory = historicalConnections
        if connection.state == .closed {
            updatedHistory.append(connection)
        }

        return ConnectionStatistics(
            totalConnectionCount: totalConnectionCount + 1,
            activeConnectionCount: connection.state == .active ? activeConnectionCount + 1 : activeConnectionCount,
            totalBytesUploaded: totalBytesUploaded + connection.bytesUploaded,
            totalBytesDownloaded: totalBytesDownloaded + connection.bytesDownloaded,
            currentThroughput: currentThroughput,
            historicalConnections: updatedHistory,
            sessionStartTime: sessionStartTime
        )
    }
}
