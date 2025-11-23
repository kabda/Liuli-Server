import Foundation

/// Use case for recording new connection
/// Persists connection information to SwiftData
public struct RecordConnectionUseCase: Sendable {
    private let connectionTrackingRepository: ConnectionTrackingRepositoryProtocol
    private let loggingService: LoggingServiceProtocol

    public init(
        connectionTrackingRepository: ConnectionTrackingRepositoryProtocol,
        loggingService: LoggingServiceProtocol
    ) {
        self.connectionTrackingRepository = connectionTrackingRepository
        self.loggingService = loggingService
    }

    /// Execute connection recording
    /// - Parameter connection: Server connection to record
    /// - Throws: ConnectionTrackingError if recording fails
    public func execute(connection: ServerConnection) async throws {
        await loggingService.logInfo(
            component: "RecordConnection",
            message: "Recording new connection from \(connection.deviceName)"
        )

        try await connectionTrackingRepository.recordConnection(connection)

        await loggingService.logConnectionEstablished(
            serverID: connection.serverID,
            deviceID: connection.deviceID,
            devicePlatform: connection.devicePlatform == .iOS ? "iOS" : "Android"
        )
    }

    /// Update existing connection statistics
    /// - Parameter connection: Updated connection with new statistics
    /// - Throws: ConnectionTrackingError if update fails
    public func updateConnection(_ connection: ServerConnection) async throws {
        try await connectionTrackingRepository.updateConnection(connection)
    }

    /// Terminate connection
    /// - Parameter connectionID: Connection to terminate
    /// - Throws: ConnectionTrackingError if termination fails
    public func terminateConnection(connectionID: UUID) async throws {
        await loggingService.logInfo(
            component: "RecordConnection",
            message: "Terminating connection: \(connectionID.uuidString)"
        )

        try await connectionTrackingRepository.terminateConnection(id: connectionID)
    }

    /// Get all active connections
    /// - Returns: Array of active connections
    public func getActiveConnections() async throws -> [ServerConnection] {
        try await connectionTrackingRepository.getActiveConnections()
    }
}
