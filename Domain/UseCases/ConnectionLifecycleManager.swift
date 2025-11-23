import Foundation

/// Use case for managing connection lifecycle with heartbeat monitoring
/// Orchestrates connection tracking and heartbeat management
public actor ConnectionLifecycleManager {
    private let recordConnectionUseCase: RecordConnectionUseCase
    private let startHeartbeatUseCase: StartHeartbeatUseCase
    private let loggingService: LoggingServiceProtocol

    // Track active heartbeat monitoring tasks
    private var activeHeartbeats: [UUID: Task<Void, Never>] = [:]

    public init(
        recordConnectionUseCase: RecordConnectionUseCase,
        startHeartbeatUseCase: StartHeartbeatUseCase,
        loggingService: LoggingServiceProtocol
    ) {
        self.recordConnectionUseCase = recordConnectionUseCase
        self.startHeartbeatUseCase = startHeartbeatUseCase
        self.loggingService = loggingService
    }

    /// Start managing a new connection (record + start heartbeat)
    /// - Parameter connection: New connection to manage
    public func startConnection(_ connection: ServerConnection) async throws {
        await loggingService.logInfo(
            component: "ConnectionLifecycle",
            message: "Starting connection lifecycle for \(connection.deviceName)"
        )

        // Record connection in tracking
        try await recordConnectionUseCase.execute(connection: connection)

        // Start heartbeat monitoring
        let heartbeatStream = startHeartbeatUseCase.execute(connection: connection)

        // Monitor heartbeat results
        let task = Task { [weak self] in
            guard let self = self else { return }

            for await result in heartbeatStream {
                await self.loggingService.logInfo(
                    component: "ConnectionLifecycle",
                    message: "Heartbeat result: \(result)"
                )

                // Check for timeout (connection will be terminated by StartHeartbeatUseCase)
                if case .timeout = result {
                    await self.stopConnection(connectionID: connection.id)
                    break
                }
            }
        }

        activeHeartbeats[connection.id] = task

        await loggingService.logInfo(
            component: "ConnectionLifecycle",
            message: "Connection lifecycle started for \(connection.deviceName)"
        )
    }

    /// Stop managing a connection (stop heartbeat + terminate)
    /// - Parameter connectionID: Connection to stop managing
    public func stopConnection(connectionID: UUID) async {
        await loggingService.logInfo(
            component: "ConnectionLifecycle",
            message: "Stopping connection lifecycle for \(connectionID.uuidString)"
        )

        // Stop heartbeat monitoring
        await startHeartbeatUseCase.stop(connectionID: connectionID)

        // Cancel heartbeat task
        activeHeartbeats[connectionID]?.cancel()
        activeHeartbeats.removeValue(forKey: connectionID)

        // Terminate connection
        try? await recordConnectionUseCase.terminateConnection(connectionID: connectionID)

        await loggingService.logInfo(
            component: "ConnectionLifecycle",
            message: "Connection lifecycle stopped"
        )
    }

    /// Update connection statistics
    /// - Parameter connection: Updated connection
    public func updateConnection(_ connection: ServerConnection) async throws {
        try await recordConnectionUseCase.updateConnection(connection)
    }

    /// Get all active connections
    /// - Returns: Array of active connections
    public func getActiveConnections() async throws -> [ServerConnection] {
        try await recordConnectionUseCase.getActiveConnections()
    }
}
