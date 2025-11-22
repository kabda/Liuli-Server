import Foundation

/// iOS device connected to Mac Bridge (FR-028)
public struct ConnectedDevice: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let ipAddress: String
    public let deviceName: String?
    public let activeConnections: [SOCKS5Connection]
    public let totalBytesTransferred: UInt64
    public let connectionStartTime: Date

    public init(
        id: UUID = UUID(),
        ipAddress: String,
        deviceName: String? = nil,
        activeConnections: [SOCKS5Connection] = [],
        totalBytesTransferred: UInt64 = 0,
        connectionStartTime: Date = Date()
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.deviceName = deviceName
        self.activeConnections = activeConnections
        self.totalBytesTransferred = totalBytesTransferred
        self.connectionStartTime = connectionStartTime
    }

    /// Display name: device name if available, otherwise IP address (FR-028)
    public var displayName: String {
        deviceName ?? ipAddress
    }

    /// Connection duration
    public var duration: TimeInterval {
        Date().timeIntervalSince(connectionStartTime)
    }

    /// Active connection count
    public var activeConnectionCount: Int {
        activeConnections.filter { $0.state == .active }.count
    }
}
