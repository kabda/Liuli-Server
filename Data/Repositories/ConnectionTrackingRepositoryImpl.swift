import Foundation
import SwiftData

/// Protocol for connection tracking repository
public protocol ConnectionTrackingRepositoryProtocol: Sendable {
    /// Record new connection
    func recordConnection(_ connection: ServerConnection) async throws

    /// Update connection statistics
    func updateConnection(_ connection: ServerConnection) async throws

    /// Get all active connections
    func getActiveConnections() async throws -> [ServerConnection]

    /// Get connection by ID
    func getConnection(id: UUID) async throws -> ServerConnection?

    /// Terminate connection
    func terminateConnection(id: UUID) async throws

    /// Get connection history (last N connections)
    func getConnectionHistory(limit: Int) async throws -> [ServerConnection]
}

/// Actor implementation for connection tracking using SwiftData
actor ConnectionTrackingRepositoryImpl: ConnectionTrackingRepositoryProtocol {
    private let modelContext: ModelContext
    private let loggingService: LoggingServiceProtocol

    init(modelContext: ModelContext, loggingService: LoggingServiceProtocol) {
        self.modelContext = modelContext
        self.loggingService = loggingService
    }

    func recordConnection(_ connection: ServerConnection) async throws {
        await loggingService.logConnectionEstablished(
            serverID: connection.serverID,
            deviceID: connection.deviceID,
            devicePlatform: connection.devicePlatform == .iOS ? "iOS" : "Android"
        )

        let model = ConnectionRecordModel.fromDomain(connection)
        modelContext.insert(model)

        try modelContext.save()

        await loggingService.logInfo(
            component: "ConnectionTracking",
            message: "Recorded new connection: \(connection.deviceName)"
        )
    }

    func updateConnection(_ connection: ServerConnection) async throws {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            predicate: #Predicate { $0.id == connection.id }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            throw ConnectionTrackingError.connectionNotFound
        }

        // Update fields
        model.bytesSent = Int64(connection.bytesSent)
        model.bytesReceived = Int64(connection.bytesReceived)
        model.lastHeartbeatAt = connection.lastHeartbeatReceivedAt
        model.consecutiveHeartbeatFailures = connection.consecutiveHeartbeatFailures

        try modelContext.save()

        await loggingService.logInfo(
            component: "ConnectionTracking",
            message: "Updated connection: \(connection.deviceName)"
        )
    }

    func getActiveConnections() async throws -> [ServerConnection] {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\. establishedAt, order: .reverse)]
        )

        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func getConnection(id: UUID) async throws -> ServerConnection? {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            predicate: #Predicate { $0.id == id }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return model.toDomain()
    }

    func terminateConnection(id: UUID) async throws {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            predicate: #Predicate { $0.id == id }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            throw ConnectionTrackingError.connectionNotFound
        }

        await loggingService.logConnectionDisconnected(
            serverID: model.serverID,
            deviceID: model.deviceID,
            reason: "Connection terminated"
        )

        model.isActive = false
        model.terminatedAt = .now

        try modelContext.save()

        await loggingService.logInfo(
            component: "ConnectionTracking",
            message: "Terminated connection: \(model.deviceName)"
        )
    }

    func getConnectionHistory(limit: Int) async throws -> [ServerConnection] {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            sortBy: [SortDescriptor(\.establishedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }
}

// MARK: - Errors

public enum ConnectionTrackingError: Error, LocalizedError {
    case connectionNotFound
    case saveFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .connectionNotFound:
            return "Connection not found"
        case .saveFailed(let error):
            return "Failed to save connection: \(error.localizedDescription)"
        }
    }
}
