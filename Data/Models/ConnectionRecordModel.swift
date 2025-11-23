import Foundation
import SwiftData

/// SwiftData model for persisting connection records
/// Tracks active and historical VPN connections to the server
@Model
final class ConnectionRecordModel {
    /// Unique identifier for this connection session
    @Attribute(.unique) var id: UUID

    /// Server's unique identifier
    var serverID: UUID

    /// Mobile device identifier
    var deviceID: String

    /// Mobile device platform (iOS or Android)
    var devicePlatform: String

    /// Device name (e.g., "John's iPhone")
    var deviceName: String

    /// When this connection was established
    var establishedAt: Date

    /// When this connection was terminated (nil if still active)
    var terminatedAt: Date?

    /// Total bytes sent from server to device
    var bytesSent: Int64

    /// Total bytes received from device by server
    var bytesReceived: Int64

    /// Last heartbeat status
    var lastHeartbeatAt: Date?

    /// Number of consecutive heartbeat failures
    var consecutiveHeartbeatFailures: Int

    /// Whether this connection is currently active
    var isActive: Bool

    init(
        id: UUID,
        serverID: UUID,
        deviceID: String,
        devicePlatform: String,
        deviceName: String,
        establishedAt: Date,
        terminatedAt: Date? = nil,
        bytesSent: Int64 = 0,
        bytesReceived: Int64 = 0,
        lastHeartbeatAt: Date? = nil,
        consecutiveHeartbeatFailures: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.serverID = serverID
        self.deviceID = deviceID
        self.devicePlatform = devicePlatform
        self.deviceName = deviceName
        self.establishedAt = establishedAt
        self.terminatedAt = terminatedAt
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.lastHeartbeatAt = lastHeartbeatAt
        self.consecutiveHeartbeatFailures = consecutiveHeartbeatFailures
        self.isActive = isActive
    }
}

// MARK: - Domain Mapping

extension ConnectionRecordModel {
    /// Convert SwiftData model to Domain entity
    func toDomain() -> ServerConnection {
        ServerConnection(
            id: id,
            serverID: serverID,
            deviceID: deviceID,
            devicePlatform: devicePlatform == "iOS" ? .iOS : .android,
            deviceName: deviceName,
            establishedAt: establishedAt,
            lastHeartbeatSentAt: lastHeartbeatAt ?? establishedAt,
            lastHeartbeatReceivedAt: lastHeartbeatAt ?? establishedAt,
            consecutiveHeartbeatFailures: consecutiveHeartbeatFailures,
            bytesSent: UInt64(bytesSent),
            bytesReceived: UInt64(bytesReceived),
            quality: determineQuality()
        )
    }

    /// Convert Domain entity to SwiftData model
    static func fromDomain(_ connection: ServerConnection) -> ConnectionRecordModel {
        ConnectionRecordModel(
            id: connection.id,
            serverID: connection.serverID,
            deviceID: connection.deviceID,
            devicePlatform: connection.devicePlatform == .iOS ? "iOS" : "android",
            deviceName: connection.deviceName,
            establishedAt: connection.establishedAt,
            terminatedAt: nil,
            bytesSent: Int64(connection.bytesSent),
            bytesReceived: Int64(connection.bytesReceived),
            lastHeartbeatAt: connection.lastHeartbeatReceivedAt,
            consecutiveHeartbeatFailures: connection.consecutiveHeartbeatFailures,
            isActive: true
        )
    }

    private func determineQuality() -> ServerConnection.ConnectionQuality {
        if consecutiveHeartbeatFailures >= 2 {
            return .degraded
        }
        // Default to good - actual latency measurement would require heartbeat timing
        return .good
    }
}
