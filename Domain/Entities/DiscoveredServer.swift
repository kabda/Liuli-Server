import Foundation

/// Represents a discovered Liuli-Server instance on the local network
public struct DiscoveredServer: Identifiable, Sendable, Equatable, Hashable {
    /// Unique identifier (matches server's device UUID)
    public let id: UUID

    /// User-facing device name (e.g., "John's MacBook Pro")
    public let name: String

    /// Server's local IP address
    public let address: String

    /// SOCKS5 proxy port
    public let port: Int

    /// Current bridge status
    public let bridgeStatus: BridgeStatus

    /// Protocol version (for compatibility checking)
    public let protocolVersion: String

    /// SHA-256 hash of server's certificate SPKI (for TOFU)
    public let certificateHash: String

    /// When this server was last seen (for timeout detection)
    public let lastSeenAt: Date

    /// Current connection status from client perspective
    public let connectionStatus: ConnectionStatus

    public init(
        id: UUID,
        name: String,
        address: String,
        port: Int,
        bridgeStatus: BridgeStatus,
        protocolVersion: String,
        certificateHash: String,
        lastSeenAt: Date = .now,
        connectionStatus: ConnectionStatus = .disconnected
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.bridgeStatus = bridgeStatus
        self.protocolVersion = protocolVersion
        self.certificateHash = certificateHash
        self.lastSeenAt = lastSeenAt
        self.connectionStatus = connectionStatus
    }
}

public extension DiscoveredServer {
    enum BridgeStatus: String, Sendable, Codable {
        case active
        case inactive
    }

    enum ConnectionStatus: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case failed(reason: String)
    }

    /// Check if server has timed out (no broadcast for 15+ seconds)
    var isTimedOut: Bool {
        Date.now.timeIntervalSince(lastSeenAt) > 15.0
    }

    /// Check if server is connectable
    var isConnectable: Bool {
        bridgeStatus == .active && !isTimedOut
    }
}

extension DiscoveredServer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, address, port, bridgeStatus, protocolVersion, certificateHash, lastSeenAt, connectionStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        port = try container.decode(Int.self, forKey: .port)
        bridgeStatus = try container.decode(BridgeStatus.self, forKey: .bridgeStatus)
        protocolVersion = try container.decode(String.self, forKey: .protocolVersion)
        certificateHash = try container.decode(String.self, forKey: .certificateHash)
        lastSeenAt = try container.decode(Date.self, forKey: .lastSeenAt)

        // Decode connectionStatus as disconnected by default (transient state)
        connectionStatus = .disconnected
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(port, forKey: .port)
        try container.encode(bridgeStatus, forKey: .bridgeStatus)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(certificateHash, forKey: .certificateHash)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
        // connectionStatus is transient, not persisted
    }
}
