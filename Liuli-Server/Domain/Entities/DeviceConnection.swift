import Foundation

/// Represents a connected iOS device with traffic statistics
public struct DeviceConnection: Identifiable, Sendable, Equatable, Codable {
    /// Unique identifier for this connection session
    public let id: UUID

    /// Device name provided by iOS client (e.g., "iPhone 15 Pro")
    public let deviceName: String

    /// Timestamp when connection was established
    public let connectedAt: Date

    /// Current connection status
    public var status: ConnectionStatus

    /// Cumulative bytes sent from device to Charles (upstream)
    public var bytesSent: Int64

    /// Cumulative bytes received by device from Charles (downstream)
    public var bytesReceived: Int64

    public nonisolated init(
        id: UUID = UUID(),
        deviceName: String,
        connectedAt: Date? = nil,
        status: ConnectionStatus = .active,
        bytesSent: Int64 = 0,
        bytesReceived: Int64 = 0
    ) {
        self.id = id
        self.deviceName = deviceName
        self.connectedAt = connectedAt ?? Date()
        self.status = status
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }
}

public enum ConnectionStatus: String, Sendable, Codable {
    case active = "active"
    case disconnected = "disconnected"
}
