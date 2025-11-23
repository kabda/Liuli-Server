import Foundation

/// Use case for starting heartbeat monitoring for a connection
/// Manages heartbeat lifecycle and handles failures
public struct StartHeartbeatUseCase: Sendable {
    private let heartbeatRepository: HeartbeatRepositoryProtocol
    private let connectionTrackingRepository: ConnectionTrackingRepositoryProtocol
    private let loggingService: LoggingServiceProtocol

    public init(
        heartbeatRepository: HeartbeatRepositoryProtocol,
        connectionTrackingRepository: ConnectionTrackingRepositoryProtocol,
        loggingService: LoggingServiceProtocol
    ) {
        self.heartbeatRepository = heartbeatRepository
        self.connectionTrackingRepository = connectionTrackingRepository
        self.loggingService = loggingService
    }

    /// Start heartbeat monitoring for a connection
    /// - Parameter connection: Connection to monitor
    /// - Returns: AsyncStream of heartbeat events
    public func execute(connection: ServerConnection) -> AsyncStream<HeartbeatResult> {
        let stream = heartbeatRepository.startSendingHeartbeats(connection: connection)

        // Process heartbeat results and update connection tracking
        return AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self = self else { return }

                for await result in stream {
                    continuation.yield(result)

                    // Handle heartbeat result
                    await self.handleHeartbeatResult(result, connection: connection)
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Stop heartbeat monitoring for a connection
    /// - Parameter connectionID: Connection ID to stop monitoring
    public func stop(connectionID: UUID) async {
        await loggingService.logInfo(
            component: "StartHeartbeat",
            message: "Stopping heartbeat for connection: \(connectionID.uuidString)"
        )

        await heartbeatRepository.stopSendingHeartbeats(connectionID: connectionID)
    }

    // MARK: - Private Methods

    private func handleHeartbeatResult(
        _ result: HeartbeatResult,
        connection: ServerConnection
    ) async {
        switch result {
        case .success(let connectionID, let latency):
            await loggingService.logInfo(
                component: "StartHeartbeat",
                message: "Heartbeat success for \(connection.deviceName), latency: \(String(format: "%.2f", latency))ms"
            )

            // Update connection with successful heartbeat
            let updatedConnection = connection.withSuccessfulHeartbeat()
            try? await connectionTrackingRepository.updateConnection(updatedConnection)

        case .failure(let connectionID, let reason):
            await loggingService.logWarning(
                component: "StartHeartbeat",
                message: "Heartbeat failure for \(connection.deviceName): \(reason)"
            )

            // Update connection with failed heartbeat
            let updatedConnection = connection.withFailedHeartbeat()
            try? await connectionTrackingRepository.updateConnection(updatedConnection)

        case .timeout(let connectionID):
            await loggingService.logError(
                component: "StartHeartbeat",
                message: "Heartbeat timeout for \(connection.deviceName) - disconnecting",
                error: nil
            )

            // Terminate connection after max retries
            await disconnectClient(connectionID: connectionID, connection: connection)
        }
    }

    private func disconnectClient(connectionID: UUID, connection: ServerConnection) async {
        await loggingService.logConnectionDisconnected(
            serverID: connection.serverID,
            deviceID: connection.deviceID,
            reason: "Heartbeat timeout after \(3) consecutive failures"
        )

        // Terminate connection in tracking
        try? await connectionTrackingRepository.terminateConnection(id: connectionID)

        // Stop heartbeat monitoring
        await heartbeatRepository.stopSendingHeartbeats(connectionID: connectionID)
    }
}
