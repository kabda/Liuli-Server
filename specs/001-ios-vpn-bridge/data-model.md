# Data Model: Domain Entities & Relationships

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Phase**: 1 (Design & Contracts)

## Purpose

This document defines all Domain layer entities, value objects, and their relationships for the Liuli-Server application. All types are pure Swift with no framework dependencies, conform to `Sendable` for Swift 6 concurrency, and use value semantics where possible.

## Entity Diagram

```
┌─────────────────────────┐
│   ProxyConfiguration    │◄──┐
│  (User Preferences)     │   │
└─────────────────────────┘   │
                              │ Loaded by
┌─────────────────────────┐   │
│     BridgeService       │───┘
│   (Service Lifecycle)   │
└───────────┬─────────────┘
            │
            │ Coordinates
            │
    ┌───────┴───────┬────────────┬─────────────┐
    │               │            │             │
    ▼               ▼            ▼             ▼
┌─────────┐   ┌─────────┐  ┌──────────┐  ┌──────────────┐
│Bonjour  │   │SOCKS5   │  │Charles   │  │Connection    │
│Service  │   │Server   │  │Proxy     │  │Statistics    │
│         │   │         │  │Status    │  │              │
└─────────┘   └────┬────┘  └──────────┘  └──────┬───────┘
                   │                             │
                   │ Manages                     │ Aggregates
                   │                             │
                   ▼                             ▼
            ┌──────────────┐            ┌──────────────┐
            │SOCKS5        │            │ Connected    │
            │Connection    │◄───────────│ Device       │
            │(Per-client)  │ Groups by  │ (Per-iOS)    │
            └──────────────┘    IP      └──────────────┘
```

---

## Domain Entities

### 1. BridgeService

**Purpose**: Represents the overall service lifecycle and coordinates all subsystems (Bonjour, SOCKS5, Charles detection).

**Type**: Struct (value type)

**Fields**:

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | `UUID` | Unique identifier for this service instance | Auto-generated |
| `state` | `ServiceState` | Current lifecycle state | Enum (idle/starting/running/stopping/error) |
| `configuration` | `ProxyConfiguration` | Active user configuration | Must be valid (FR-044) |
| `connectedDeviceCount` | `Int` | Number of unique iOS devices connected | ≥ 0 |
| `startedAt` | `Date?` | Timestamp when service last started | Nil when stopped |
| `errorMessage` | `String?` | Human-readable error if state == .error | Nil when state != .error |

**Relationships**:
- Contains one `ProxyConfiguration` (composition)
- Publishes `ServiceState` changes to ViewModels via AsyncStream

**State Transitions**:
```
idle ──[start()]──> starting ──[success]──> running ──[stop()]──> stopping ──> idle
  │                    │                       │                      │
  └────────────────────┴───[error]────────────┴──────────────────────┴────> error ──[reset()]──> idle
```

**Swift Code**:
```swift
public struct BridgeService: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var state: ServiceState
    public var configuration: ProxyConfiguration
    public var connectedDeviceCount: Int
    public var startedAt: Date?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        state: ServiceState = .idle,
        configuration: ProxyConfiguration,
        connectedDeviceCount: Int = 0,
        startedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.state = state
        self.configuration = configuration
        self.connectedDeviceCount = connectedDeviceCount
        self.startedAt = startedAt
        self.errorMessage = errorMessage
    }
}
```

---

### 2. SOCKS5Connection

**Purpose**: Represents an individual TCP connection from an iOS client through the SOCKS5 server.

**Type**: Struct (value type)

**Fields**:

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | `UUID` | Unique connection identifier | Auto-generated |
| `sourceIP` | `String` | iOS client IP address (e.g., "192.168.1.100") | Must match RFC 1918 or link-local (FR-011) |
| `sourcePort` | `UInt16` | iOS client source port | 1024-65535 |
| `destinationHost` | `String` | Target host (domain or IP) | Non-empty string |
| `destinationPort` | `UInt16` | Target port (e.g., 443 for HTTPS) | 1-65535 |
| `state` | `ConnectionState` | Current connection state | Enum (handshaking/connected/forwarding/closed) |
| `startTime` | `Date` | When connection was established | Cannot be future date |
| `bytesUploaded` | `UInt64` | Bytes sent from iOS → Charles | ≥ 0 |
| `bytesDownloaded` | `UInt64` | Bytes sent from Charles → iOS | ≥ 0 |
| `lastActivityTime` | `Date` | Last read/write timestamp (for idle timeout) | ≤ Date() |

**Relationships**:
- Belongs to one `ConnectedDevice` (grouped by `sourceIP`)
- Tracked by `ConnectionStatistics` for aggregation

**Lifecycle**:
```
created → handshaking → connected → forwarding → closed
            │              │            │
            └──[timeout]───┴──[error]───┴──> closed
```

**Swift Code**:
```swift
public struct SOCKS5Connection: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let sourceIP: String
    public let sourcePort: UInt16
    public let destinationHost: String
    public let destinationPort: UInt16
    public var state: ConnectionState
    public let startTime: Date
    public var bytesUploaded: UInt64
    public var bytesDownloaded: UInt64
    public var lastActivityTime: Date

    public init(
        id: UUID = UUID(),
        sourceIP: String,
        sourcePort: UInt16,
        destinationHost: String,
        destinationPort: UInt16,
        state: ConnectionState = .handshaking,
        startTime: Date = Date(),
        bytesUploaded: UInt64 = 0,
        bytesDownloaded: UInt64 = 0,
        lastActivityTime: Date = Date()
    ) {
        self.id = id
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationHost = destinationHost
        self.destinationPort = destinationPort
        self.state = state
        self.startTime = startTime
        self.bytesUploaded = bytesUploaded
        self.bytesDownloaded = bytesDownloaded
        self.lastActivityTime = lastActivityTime
    }

    public var totalBytes: UInt64 {
        bytesUploaded + bytesDownloaded
    }

    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}
```

---

### 3. ConnectedDevice

**Purpose**: Groups connections by iOS device IP address for statistics aggregation.

**Type**: Struct (value type)

**Fields**:

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | `UUID` | Unique device identifier (generated from IP) | Deterministic from `ipAddress` |
| `ipAddress` | `String` | iOS device IP address | Must match RFC 1918 or link-local |
| `deviceName` | `String?` | Human-readable name (from reverse DNS or Bonjour) | Optional, may be nil |
| `connections` | `[SOCKS5Connection]` | Active connections from this device | Filtered by `sourceIP` |
| `firstSeenAt` | `Date` | When first connection was established | Immutable after creation |
| `lastSeenAt` | `Date` | When most recent activity occurred | Updated on connection activity |

**Computed Properties**:
- `totalBytesUploaded`: Sum of all `connections[].bytesUploaded`
- `totalBytesDownloaded`: Sum of all `connections[].bytesDownloaded`
- `connectionDuration`: `lastSeenAt - firstSeenAt`
- `activeConnectionCount`: Count of `connections` where `state != .closed`

**Swift Code**:
```swift
public struct ConnectedDevice: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let ipAddress: String
    public var deviceName: String?
    public var connections: [SOCKS5Connection]
    public let firstSeenAt: Date
    public var lastSeenAt: Date

    public init(
        id: UUID,
        ipAddress: String,
        deviceName: String? = nil,
        connections: [SOCKS5Connection] = [],
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.deviceName = deviceName
        self.connections = connections
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }

    public var totalBytesUploaded: UInt64 {
        connections.reduce(0) { $0 + $1.bytesUploaded }
    }

    public var totalBytesDownloaded: UInt64 {
        connections.reduce(0) { $0 + $1.bytesDownloaded }
    }

    public var connectionDuration: TimeInterval {
        lastSeenAt.timeIntervalSince(firstSeenAt)
    }

    public var activeConnectionCount: Int {
        connections.filter { $0.state != .closed }.count
    }
}
```

---

### 4. ProxyConfiguration

**Purpose**: User preferences for SOCKS5 server and Charles proxy.

**Type**: Struct (value type, Codable for UserDefaults persistence)

**Fields**:

| Field | Type | Description | Validation | Default (FR-043) |
|-------|------|-------------|------------|------------------|
| `socks5Port` | `UInt16` | Port for SOCKS5 server | 1024-65535 (FR-044) | 9000 |
| `charlesHost` | `String` | Charles proxy address | Valid hostname or IP | "localhost" |
| `charlesPort` | `UInt16` | Charles proxy port | 1-65535 | 8888 |
| `autoStartOnLogin` | `Bool` | Launch at system boot | - | false |
| `autoLaunchCharles` | `Bool` | Launch Charles when starting service | - | false |
| `notificationsEnabled` | `Bool` | Show system notifications | - | true |

**Swift Code**:
```swift
public struct ProxyConfiguration: Sendable, Equatable, Codable {
    public var socks5Port: UInt16
    public var charlesHost: String
    public var charlesPort: UInt16
    public var autoStartOnLogin: Bool
    public var autoLaunchCharles: Bool
    public var notificationsEnabled: Bool

    public init(
        socks5Port: UInt16 = 9000,
        charlesHost: String = "localhost",
        charlesPort: UInt16 = 8888,
        autoStartOnLogin: Bool = false,
        autoLaunchCharles: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.socks5Port = socks5Port
        self.charlesHost = charlesHost
        self.charlesPort = charlesPort
        self.autoStartOnLogin = autoStartOnLogin
        self.autoLaunchCharles = autoLaunchCharles
        self.notificationsEnabled = notificationsEnabled
    }

    public static let `default` = ProxyConfiguration()

    public func isValid() -> Bool {
        socks5Port >= 1024 && !charlesHost.isEmpty && charlesPort > 0
    }
}
```

---

### 5. ConnectionStatistics

**Purpose**: Session-scoped metrics for monitoring and statistics display.

**Type**: Struct (value type)

**Fields**:

| Field | Type | Description | Lifecycle |
|-------|------|-------------|-----------|
| `totalConnectionCount` | `Int` | Total connections since app launch | Reset on app restart (FR-035, clarification Q2) |
| `activeConnectionCount` | `Int` | Currently open connections | Real-time count |
| `totalBytesUploaded` | `UInt64` | Cumulative bytes iOS → Charles | Session-scoped |
| `totalBytesDownloaded` | `UInt64` | Cumulative bytes Charles → iOS | Session-scoped |
| `currentThroughputBps` | `Double` | Bytes per second (last 1 second) | Real-time calculation |
| `connectionHistory` | `[SOCKS5Connection]` | Last 50 closed connections | Ring buffer (FR-035) |
| `sessionStartTime` | `Date` | When app launched | Immutable |

**Computed Properties**:
- `averageThroughput`: `(totalBytesUploaded + totalBytesDownloaded) / sessionDuration`
- `sessionDuration`: `Date() - sessionStartTime`

**Swift Code**:
```swift
public struct ConnectionStatistics: Sendable, Equatable {
    public var totalConnectionCount: Int
    public var activeConnectionCount: Int
    public var totalBytesUploaded: UInt64
    public var totalBytesDownloaded: UInt64
    public var currentThroughputBps: Double
    public var connectionHistory: [SOCKS5Connection]
    public let sessionStartTime: Date

    public init(
        totalConnectionCount: Int = 0,
        activeConnectionCount: Int = 0,
        totalBytesUploaded: UInt64 = 0,
        totalBytesDownloaded: UInt64 = 0,
        currentThroughputBps: Double = 0,
        connectionHistory: [SOCKS5Connection] = [],
        sessionStartTime: Date = Date()
    ) {
        self.totalConnectionCount = totalConnectionCount
        self.activeConnectionCount = activeConnectionCount
        self.totalBytesUploaded = totalBytesUploaded
        self.totalBytesDownloaded = totalBytesDownloaded
        self.currentThroughputBps = currentThroughputBps
        self.connectionHistory = connectionHistory
        self.sessionStartTime = sessionStartTime
    }

    public var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    public var averageThroughput: Double {
        guard sessionDuration > 0 else { return 0 }
        return Double(totalBytesUploaded + totalBytesDownloaded) / sessionDuration
    }
}
```

---

## Value Objects (Enums)

### ServiceState

**Purpose**: Lifecycle states for `BridgeService`

```swift
public enum ServiceState: String, Sendable, Codable, CaseIterable {
    case idle       // Service not running
    case starting   // Bonjour + SOCKS5 server launching
    case running    // Accepting connections
    case stopping   // Gracefully closing connections
    case error      // Startup or runtime failure

    public var isActive: Bool {
        self == .starting || self == .running || self == .stopping
    }
}
```

---

### ConnectionState

**Purpose**: SOCKS5 connection lifecycle states

```swift
public enum ConnectionState: String, Sendable, Codable {
    case handshaking  // SOCKS5 protocol negotiation (RFC 1928)
    case connected    // TCP connection established to destination
    case forwarding   // Actively proxying data to Charles
    case closed       // Connection terminated (gracefully or error)
}
```

---

### SOCKS5ErrorCode

**Purpose**: RFC 1928 error codes for SOCKS5 protocol failures

```swift
public enum SOCKS5ErrorCode: UInt8, Sendable, Error {
    case generalFailure = 0x01        // Server error (FR-016)
    case connectionNotAllowed = 0x02  // Firewall/policy rejection
    case networkUnreachable = 0x03    // Network layer failure
    case hostUnreachable = 0x04       // DNS failure or no route (FR-015, clarification Q4)
    case connectionRefused = 0x05     // TCP connection refused (FR-016, clarification Q4)
    case ttlExpired = 0x06            // Timeout
    case commandNotSupported = 0x07   // Unsupported SOCKS5 command
    case addressTypeNotSupported = 0x08  // Unsupported address type

    public var localizedDescription: String {
        switch self {
        case .generalFailure: return "SOCKS5 server error"
        case .connectionNotAllowed: return "Connection not allowed"
        case .networkUnreachable: return "Network unreachable"
        case .hostUnreachable: return "Host unreachable (DNS failure)"
        case .connectionRefused: return "Connection refused by destination"
        case .ttlExpired: return "Connection timed out"
        case .commandNotSupported: return "SOCKS5 command not supported"
        case .addressTypeNotSupported: return "Address type not supported"
        }
    }
}
```

---

### CharlesProxyStatus

**Purpose**: Charles proxy availability status

```swift
public enum CharlesProxyStatus: Sendable, Equatable {
    case reachable(lastCheck: Date)
    case unreachable(reason: String)

    public var isAvailable: Bool {
        if case .reachable = self { return true }
        return false
    }
}
```

---

## Data Validation Rules

| Entity | Field | Rule | Error Handling |
|--------|-------|------|----------------|
| BridgeService | `connectedDeviceCount` | ≥ 0 | Asserting (internal invariant) |
| SOCKS5Connection | `sourceIP` | RFC 1918 or link-local | Reject at socket level (FR-011) |
| SOCKS5Connection | `bytesUploaded/Downloaded` | ≥ 0 | Asserting (monotonic counter) |
| ProxyConfiguration | `socks5Port` | 1024-65535 | Return validation error (FR-044) |
| ProxyConfiguration | `charlesHost` | Non-empty | Return validation error (FR-044) |
| ConnectionStatistics | `connectionHistory` | Max 50 items | Ring buffer (drop oldest, FR-035) |

---

## Identity & Uniqueness

| Entity | Primary Identifier | Uniqueness Guarantee |
|--------|-------------------|----------------------|
| BridgeService | `id: UUID` | One instance per app lifetime |
| SOCKS5Connection | `id: UUID` | Per-connection unique |
| ConnectedDevice | `id: UUID(from: ipAddress)` | Deterministic from IP address |
| ProxyConfiguration | N/A (value type) | Singleton managed by repository |
| ConnectionStatistics | N/A (value type) | Singleton in-memory |

**Note**: `ConnectedDevice.id` is generated deterministically from `ipAddress` using `UUID(uuidString: ipAddress.replacingOccurrences(of: ".", with: "-"))` or similar hashing to ensure same IP always maps to same UUID.

---

## Relationships Summary

```
BridgeService (1) ──contains──> (1) ProxyConfiguration
BridgeService (1) ──publishes──> (many) ServiceState changes

SOCKS5Connection (many) ──grouped by IP──> (1) ConnectedDevice
SOCKS5Connection (many) ──aggregated by──> (1) ConnectionStatistics

ConnectionStatistics (1) ──tracks──> (many) SOCKS5Connection [historical]
```

---

## Persistence Strategy

| Entity | Storage | Lifecycle |
|--------|---------|-----------|
| ProxyConfiguration | UserDefaults (JSON) | Persistent across launches |
| BridgeService | In-memory only | Reset on app restart |
| SOCKS5Connection | In-memory only | Cleared when connection closes |
| ConnectedDevice | In-memory only | Cleared when all connections close |
| ConnectionStatistics | In-memory only | Reset on app restart (clarification Q2) |

**Rationale**: Privacy-first design (no traffic metadata persisted to disk, FR-035). Only user preferences are saved.

---

## Domain Entity Testing Checklist

- [ ] All entities are `Sendable` (Swift 6 concurrency)
- [ ] All entities use value semantics (struct preferred)
- [ ] No framework dependencies (Foundation types limited to Date/UUID/String)
- [ ] All fields have validation rules documented
- [ ] State transitions are explicitly defined
- [ ] Computed properties are pure functions (no side effects)
- [ ] Relationships are clearly documented
- [ ] Identity/uniqueness constraints are enforced
