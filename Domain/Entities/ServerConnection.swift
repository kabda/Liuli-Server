import Foundation

/// Represents an active VPN connection between mobile device and server
/// Tracks connection state, heartbeat status, and data transfer statistics
public struct ServerConnection: Identifiable, Sendable, Equatable {
    /// Unique identifier for this connection session
    public let id: UUID

    /// Server's unique identifier
    public let serverID: UUID

    /// Mobile device identifier
    public let deviceID: String

    /// Mobile device platform
    public let devicePlatform: DevicePlatform

    /// Device name (e.g., "John's iPhone")
    public let deviceName: String

    /// When this connection was established
    public let establishedAt: Date

    /// When the last heartbeat was sent
    public let lastHeartbeatSentAt: Date

    /// When the last heartbeat response was received
    public let lastHeartbeatReceivedAt: Date

    /// Number of consecutive failed heartbeat attempts
    public let consecutiveHeartbeatFailures: Int

    /// Total bytes sent from server to device
    public let bytesSent: UInt64

    /// Total bytes received from device by server
    public let bytesReceived: UInt64

    /// Current connection quality state
    public let quality: ConnectionQuality

    public init(
        id: UUID = UUID(),
        serverID: UUID,
        deviceID: String,
        devicePlatform: DevicePlatform,
        deviceName: String,
        establishedAt: Date = .now,
        lastHeartbeatSentAt: Date = .now,
        lastHeartbeatReceivedAt: Date = .now,
        consecutiveHeartbeatFailures: Int = 0,
        bytesSent: UInt64 = 0,
        bytesReceived: UInt64 = 0,
        quality: ConnectionQuality = .good
    ) {
        self.id = id
        self.serverID = serverID
        self.deviceID = deviceID
        self.devicePlatform = devicePlatform
        self.deviceName = deviceName
        self.establishedAt = establishedAt
        self.lastHeartbeatSentAt = lastHeartbeatSentAt
        self.lastHeartbeatReceivedAt = lastHeartbeatReceivedAt
        self.consecutiveHeartbeatFailures = consecutiveHeartbeatFailures
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.quality = quality
    }
}

public extension ServerConnection {
    enum DevicePlatform: String, Sendable, Codable {
        case iOS
        case android
    }

    enum ConnectionQuality: Sendable, Equatable {
        case excellent  // < 50ms latency
        case good       // 50-200ms latency
        case fair       // 200-500ms latency
        case poor       // > 500ms latency
        case degraded   // Heartbeat failures detected
    }

    /// Duration since connection was established
    var connectionDuration: TimeInterval {
        Date.now.timeIntervalSince(establishedAt)
    }

    /// Check if heartbeat has timed out (no response for 90 seconds)
    var isHeartbeatTimedOut: Bool {
        Date.now.timeIntervalSince(lastHeartbeatReceivedAt) > 90.0
    }

    /// Check if connection should be terminated (3 consecutive heartbeat failures)
    var shouldTerminate: Bool {
        consecutiveHeartbeatFailures >= 3
    }

    /// Total data transferred (bidirectional)
    var totalBytesTransferred: UInt64 {
        bytesSent + bytesReceived
    }

    /// Average data rate since connection establishment (bytes per second)
    var averageDataRate: Double {
        let duration = connectionDuration
        guard duration > 0 else { return 0 }
        return Double(totalBytesTransferred) / duration
    }

    /// Create updated connection after successful heartbeat
    func withSuccessfulHeartbeat() -> ServerConnection {
        ServerConnection(
            id: self.id,
            serverID: self.serverID,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            deviceName: self.deviceName,
            establishedAt: self.establishedAt,
            lastHeartbeatSentAt: .now,
            lastHeartbeatReceivedAt: .now,
            consecutiveHeartbeatFailures: 0, // Reset on success
            bytesSent: self.bytesSent,
            bytesReceived: self.bytesReceived,
            quality: self.quality
        )
    }

    /// Create updated connection after failed heartbeat
    func withFailedHeartbeat() -> ServerConnection {
        let newQuality: ConnectionQuality = consecutiveHeartbeatFailures >= 2 ? .degraded : self.quality

        return ServerConnection(
            id: self.id,
            serverID: self.serverID,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            deviceName: self.deviceName,
            establishedAt: self.establishedAt,
            lastHeartbeatSentAt: .now,
            lastHeartbeatReceivedAt: self.lastHeartbeatReceivedAt,
            consecutiveHeartbeatFailures: self.consecutiveHeartbeatFailures + 1,
            bytesSent: self.bytesSent,
            bytesReceived: self.bytesReceived,
            quality: newQuality
        )
    }

    /// Create updated connection with new data transfer statistics
    func withDataTransfer(sent: UInt64, received: UInt64) -> ServerConnection {
        ServerConnection(
            id: self.id,
            serverID: self.serverID,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            deviceName: self.deviceName,
            establishedAt: self.establishedAt,
            lastHeartbeatSentAt: self.lastHeartbeatSentAt,
            lastHeartbeatReceivedAt: self.lastHeartbeatReceivedAt,
            consecutiveHeartbeatFailures: self.consecutiveHeartbeatFailures,
            bytesSent: self.bytesSent + sent,
            bytesReceived: self.bytesReceived + received,
            quality: self.quality
        )
    }

    /// Create updated connection with new quality assessment
    func withQuality(_ newQuality: ConnectionQuality) -> ServerConnection {
        ServerConnection(
            id: self.id,
            serverID: self.serverID,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            deviceName: self.deviceName,
            establishedAt: self.establishedAt,
            lastHeartbeatSentAt: self.lastHeartbeatSentAt,
            lastHeartbeatReceivedAt: self.lastHeartbeatReceivedAt,
            consecutiveHeartbeatFailures: self.consecutiveHeartbeatFailures,
            bytesSent: self.bytesSent,
            bytesReceived: self.bytesReceived,
            quality: newQuality
        )
    }
}

extension ServerConnection: Codable {
    enum CodingKeys: String, CodingKey {
        case id, serverID, deviceID, devicePlatform, deviceName
        case establishedAt, lastHeartbeatSentAt, lastHeartbeatReceivedAt
        case consecutiveHeartbeatFailures, bytesSent, bytesReceived, quality
    }
}
