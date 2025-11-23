import Foundation
import SwiftData

/// SwiftData model for persisting pairing records
/// Tracks historical connections between mobile devices and server
@Model
final class PairingRecordModel {
    /// Unique identifier for this pairing record
    @Attribute(.unique) var id: UUID

    /// Server's unique identifier
    var serverID: UUID

    /// Server's device name at time of pairing
    var serverName: String

    /// Mobile device identifier (iOS IDFV or Android device UUID)
    var deviceID: String

    /// Mobile device platform ("iOS" or "Android")
    var devicePlatform: String

    /// When this pairing was first established
    var firstConnectedAt: Date

    /// When this pairing was last used successfully
    var lastConnectedAt: Date

    /// Total number of successful connections
    var successfulConnectionCount: Int

    /// Total number of failed connection attempts
    var failedConnectionCount: Int

    /// User preference: auto-reconnect to this server
    var autoReconnectEnabled: Bool

    /// Pinned certificate fingerprint (SHA-256 SPKI hash)
    var pinnedCertificateHash: String

    init(
        id: UUID,
        serverID: UUID,
        serverName: String,
        deviceID: String,
        devicePlatform: String,
        firstConnectedAt: Date,
        lastConnectedAt: Date,
        successfulConnectionCount: Int,
        failedConnectionCount: Int,
        autoReconnectEnabled: Bool,
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

// MARK: - Domain Mapping

extension PairingRecordModel {
    /// Convert SwiftData model to Domain entity
    func toDomain() -> PairingRecord {
        PairingRecord(
            id: id,
            serverID: serverID,
            serverName: serverName,
            deviceID: deviceID,
            devicePlatform: devicePlatform == "iOS" ? .iOS : .android,
            firstConnectedAt: firstConnectedAt,
            lastConnectedAt: lastConnectedAt,
            successfulConnectionCount: successfulConnectionCount,
            failedConnectionCount: failedConnectionCount,
            autoReconnectEnabled: autoReconnectEnabled,
            pinnedCertificateHash: pinnedCertificateHash
        )
    }

    /// Convert Domain entity to SwiftData model
    static func fromDomain(_ record: PairingRecord) -> PairingRecordModel {
        PairingRecordModel(
            id: record.id,
            serverID: record.serverID,
            serverName: record.serverName,
            deviceID: record.deviceID,
            devicePlatform: record.devicePlatform == .iOS ? "iOS" : "Android",
            firstConnectedAt: record.firstConnectedAt,
            lastConnectedAt: record.lastConnectedAt,
            successfulConnectionCount: record.successfulConnectionCount,
            failedConnectionCount: record.failedConnectionCount,
            autoReconnectEnabled: record.autoReconnectEnabled,
            pinnedCertificateHash: record.pinnedCertificateHash
        )
    }

    /// Check if record is expired (30 days since last connection)
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return lastConnectedAt < thirtyDaysAgo
    }
}
