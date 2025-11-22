import Foundation

/// Use case for monitoring device connections in real-time
public struct MonitorDeviceConnectionsUseCase: Sendable {
    private let repository: DeviceMonitorRepository

    public init(repository: DeviceMonitorRepository) {
        self.repository = repository
    }

    /// Execute use case to observe device connections
    public func execute() -> AsyncStream<[DeviceConnection]> {
        repository.observeConnections()
    }
}
