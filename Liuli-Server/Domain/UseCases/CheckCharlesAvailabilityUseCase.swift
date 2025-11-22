import Foundation

/// Use case for checking Charles proxy availability
public struct CheckCharlesAvailabilityUseCase: Sendable {
    private let repository: CharlesProxyMonitorRepository
    private let pollingInterval: TimeInterval

    public init(
        repository: CharlesProxyMonitorRepository,
        pollingInterval: TimeInterval = 5.0
    ) {
        self.repository = repository
        self.pollingInterval = pollingInterval
    }

    /// Execute use case to observe Charles availability
    public func execute() -> AsyncStream<CharlesStatus> {
        repository.observeAvailability(interval: pollingInterval)
    }

    /// Check availability once (for manual refresh)
    public func checkOnce(host: String, port: UInt16) async -> CharlesStatus {
        await repository.checkAvailability(host: host, port: port)
    }
}
