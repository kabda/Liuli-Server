import Foundation

/// Represents a Bonjour service broadcast configuration
/// Used by macOS server to announce its presence on the local network
public struct ServiceBroadcast: Sendable, Equatable {
    /// mDNS service type (always "_liuli-proxy._tcp.")
    public let serviceType: String = "_liuli-proxy._tcp."

    /// mDNS domain (always "local.")
    public let domain: String = "local."

    /// User-facing device name (e.g., "John's MacBook Pro")
    public let deviceName: String

    /// Unique server identifier (matches server's device UUID)
    public let deviceID: UUID

    /// SOCKS5 proxy port
    public let port: Int

    /// Current bridge status (active/inactive)
    public let bridgeStatus: BridgeStatus

    /// Protocol version for compatibility checking
    public let protocolVersion: String = "1.0.0"

    /// SHA-256 hash of server's certificate SPKI (for TOFU)
    public let certificateHash: String

    public init(
        deviceName: String,
        deviceID: UUID,
        port: Int,
        bridgeStatus: BridgeStatus,
        certificateHash: String
    ) {
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.port = port
        self.bridgeStatus = bridgeStatus
        self.certificateHash = certificateHash
    }
}

public extension ServiceBroadcast {
    enum BridgeStatus: String, Sendable, Codable {
        case active
        case inactive
    }

    /// Generate TXT record for Bonjour broadcast
    /// Returns dictionary with keys: port, version, device_id, bridge_status, cert_hash
    func generateTXTRecord() -> [String: String] {
        [
            "port": "\(port)",
            "version": protocolVersion,
            "device_id": deviceID.uuidString,
            "bridge_status": bridgeStatus.rawValue,
            "cert_hash": certificateHash
        ]
    }

    /// Generate TXT record as Data (for NetService API)
    func generateTXTRecordData() -> Data {
        let txtRecord = generateTXTRecord()
        let dataDict = txtRecord.mapValues { $0.data(using: .utf8)! }
        return NetService.data(fromTXTRecord: dataDict)
    }
}
