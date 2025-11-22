import Foundation

/// Use case for monitoring network status in real-time
public struct MonitorNetworkStatusUseCase: Sendable {
    private let repository: NetworkStatusRepository

    public init(repository: NetworkStatusRepository) {
        self.repository = repository
    }

    /// Execute use case to observe network status
    public func execute() -> AsyncStream<NetworkStatus> {
        repository.observeStatus()
    }
}
