import Foundation

/// Statistics view state (FR-027)
public struct StatisticsViewState: Sendable, Equatable {
    public var statistics: ConnectionStatistics
    public var connections: [SOCKS5Connection]

    public init(
        statistics: ConnectionStatistics = ConnectionStatistics(),
        connections: [SOCKS5Connection] = []
    ) {
        self.statistics = statistics
        self.connections = connections
    }
}

/// Statistics view action
public enum StatisticsViewAction: Sendable {
    case onAppear
    case close
}
