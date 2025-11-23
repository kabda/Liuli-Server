import Foundation

/// Represents a historical pairing relationship between mobile device and server
/// Used for persistent auto-reconnection and reliability tracking
public struct PairingRecord: Identifiable, Sendable, Equatable {
    /// Unique identifier for this pairing record
    public let id: UUID

    /// Server's unique identifier
    public let serverID: UUID

    /// Server's device name at time of pairing
    public let serverName: String

    /// Mobile device identifier (iOS IDFV or Android device UUID)
    public let deviceID: String

    /// Mobile device platform (iOS or Android)
    public let devicePlatform: DevicePlatform

    /// When this pairing was first established
    public let firstConnectedAt: Date

    /// When this pairing was last used successfully
    public let lastConnectedAt: Date

    /// Total number of successful connections
    public let successfulConnectionCount: Int

    /// Total number of failed connection attempts
    public let failedConnectionCount: Int

    /// User preference: auto-reconnect to this server
    public let autoReconnectEnabled: Bool

    /// Pinned certificate fingerprint (SHA-256 SPKI hash)
    public let pinnedCertificateHash: String

    public init(
        id: UUID = UUID(),
        serverID: UUID,
        serverName: String,
        deviceID: String,
        devicePlatform: DevicePlatform,
        firstConnectedAt: Date = .now,
        lastConnectedAt: Date = .now,
        successfulConnectionCount: Int = 0,
        failedConnectionCount: Int = 0,
        autoReconnectEnabled: Bool = true,
        pinnedCertificateHash: String
    ) {
        self.id = id
        self.serverID = serverID
        self.serverName = serverName
        self.deviceID = deviceID
        self.devicePlatform = devicePlatform
        self.firstConnectedAt = firstConnectedAt
        self.lastConnectedAt = lastConnectedAt
        self.successfulConnectionCount = successfulConnectionCount
        self.failedConnectionCount = failedConnectionCount
        self.autoReconnectEnabled = autoReconnectEnabled
        self.pinnedCertificateHash = pinnedCertificateHash
    }
}

public extension PairingRecord {
    enum DevicePlatform: String, Sendable, Codable {
        case iOS
        case android
    }

    /// Calculate connection reliability (success rate)
    var reliabilityScore: Double {
        let totalAttempts = successfulConnectionCount + failedConnectionCount
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulConnectionCount) / Double(totalAttempts)
    }

    /// Check if pairing record has expired (30 days since last connection)
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return lastConnectedAt < thirtyDaysAgo
    }

    /// Create updated record after successful connection
    func recordSuccessfulConnection() -> PairingRecord {
        PairingRecord(
            id: self.id,
            serverID: self.serverID,
            serverName: self.serverName,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            firstConnectedAt: self.firstConnectedAt,
            lastConnectedAt: .now,
            successfulConnectionCount: self.successfulConnectionCount + 1,
            failedConnectionCount: self.failedConnectionCount,
            autoReconnectEnabled: self.autoReconnectEnabled,
            pinnedCertificateHash: self.pinnedCertificateHash
        )
    }

    /// Create updated record after failed connection attempt
    func recordFailedConnection() -> PairingRecord {
        PairingRecord(
            id: self.id,
            serverID: self.serverID,
            serverName: self.serverName,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            firstConnectedAt: self.firstConnectedAt,
            lastConnectedAt: self.lastConnectedAt, // Don't update on failure
            successfulConnectionCount: self.successfulConnectionCount,
            failedConnectionCount: self.failedConnectionCount + 1,
            autoReconnectEnabled: self.autoReconnectEnabled,
            pinnedCertificateHash: self.pinnedCertificateHash
        )
    }

    /// Create updated record with new auto-reconnect preference
    func withAutoReconnect(_ enabled: Bool) -> PairingRecord {
        PairingRecord(
            id: self.id,
            serverID: self.serverID,
            serverName: self.serverName,
            deviceID: self.deviceID,
            devicePlatform: self.devicePlatform,
            firstConnectedAt: self.firstConnectedAt,
            lastConnectedAt: self.lastConnectedAt,
            successfulConnectionCount: self.successfulConnectionCount,
            failedConnectionCount: self.failedConnectionCount,
            autoReconnectEnabled: enabled,
            pinnedCertificateHash: self.pinnedCertificateHash
        )
    }
}

extension PairingRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, serverID, serverName, deviceID, devicePlatform
        case firstConnectedAt, lastConnectedAt
        case successfulConnectionCount, failedConnectionCount
        case autoReconnectEnabled, pinnedCertificateHash
    }
}
