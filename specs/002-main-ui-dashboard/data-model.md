# Data Model Design

**Feature**: Main UI Dashboard and Menu Bar Interface
**Date**: 2025-11-22
**Layer**: Domain (entities) + Presentation (view state)

## Overview

This document defines all entities, value objects, and state structures for the UI dashboard feature, following Clean MVVM architecture principles.

---

## Domain Layer Entities

### 1. DeviceConnection

**Location**: `Domain/Entities/DeviceConnection.swift`

**Purpose**: Represents a connected iOS device with traffic statistics

**Definition**:
```swift
import Foundation

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

    public init(
        id: UUID = UUID(),
        deviceName: String,
        connectedAt: Date = Date(),
        status: ConnectionStatus = .active,
        bytesSent: Int64 = 0,
        bytesReceived: Int64 = 0
    ) {
        self.id = id
        self.deviceName = deviceName
        self.connectedAt = connectedAt
        self.status = status
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }
}

public enum ConnectionStatus: String, Sendable, Codable {
    case active = "active"
    case disconnected = "disconnected"
}
```

**Validation Rules** (from FR-002, FR-003, FR-016):
- `deviceName` MUST NOT be empty (validated at creation)
- `bytesSent` and `bytesReceived` MUST be ≥ 0
- `status == .disconnected` → device removed from UI (FR-016)
- System MUST support ≥ 10 concurrent active connections (FR-003)

**State Transitions**:
```
[New Connection] → active
active → disconnected (on client disconnect or bridge shutdown)
disconnected → [Removed from memory] (FR-016)
```

---

### 2. NetworkStatus

**Location**: `Domain/Entities/NetworkStatus.swift`

**Purpose**: Represents network bridge listening state

**Definition**:
```swift
import Foundation

public struct NetworkStatus: Sendable, Equatable, Codable {
    /// Whether bridge is currently accepting connections
    public let isListening: Bool

    /// Port number bridge is listening on (if listening)
    public let listeningPort: UInt16?

    /// Number of currently active connections
    public let activeConnectionCount: Int

    /// Timestamp of last status update
    public let lastUpdated: Date

    public init(
        isListening: Bool,
        listeningPort: UInt16? = nil,
        activeConnectionCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.isListening = isListening
        self.listeningPort = listeningPort
        self.activeConnectionCount = activeConnectionCount
        self.lastUpdated = lastUpdated
    }
}
```

**Validation Rules** (from FR-006, FR-011):
- `isListening == false` AND `activeConnectionCount > 0` → valid state (bridge disabled with existing connections, FR-011)
- `listeningPort` MUST be in range 1024-65535 when listening

**State Transitions**:
```
inactive (isListening: false, port: nil)
  ↓ [Start bridge]
listening (isListening: true, port: 12345)
  ↓ [Disable bridge]
gracefully_stopping (isListening: false, activeConnectionCount > 0)
  ↓ [All connections closed]
inactive
```

---

### 3. CharlesStatus

**Location**: `Domain/Entities/CharlesStatus.swift`

**Purpose**: Represents Charles proxy availability state

**Definition**:
```swift
import Foundation

public struct CharlesStatus: Sendable, Equatable, Codable {
    /// Current availability state
    public let availability: Availability

    /// Configured proxy host (e.g., "localhost")
    public let proxyHost: String

    /// Configured proxy port (e.g., 8888)
    public let proxyPort: UInt16

    /// Timestamp of last availability check
    public let lastChecked: Date

    /// Optional error message if unavailable
    public let errorMessage: String?

    public init(
        availability: Availability,
        proxyHost: String,
        proxyPort: UInt16,
        lastChecked: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.availability = availability
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.lastChecked = lastChecked
        self.errorMessage = errorMessage
    }
}

public enum Availability: String, Sendable, Codable {
    case unknown = "unknown"        // Initial state, not yet checked
    case available = "available"    // CONNECT probe succeeded
    case unavailable = "unavailable" // CONNECT probe failed or timeout
}
```

**Validation Rules** (from FR-005, FR-017):
- `proxyPort` MUST be in range 1-65535
- `proxyHost` MUST NOT be empty
- Default: `proxyHost = "localhost"`, `proxyPort = 8888` (FR-017)
- Availability checked via HTTP CONNECT probe (FR-005)

**State Transitions**:
```
unknown (initial)
  ↓ [Probe request sent]
available (200 OK response) OR unavailable (timeout/error)
  ↓ [5-10s polling interval]
[Repeat probe]
```

---

### 4. ApplicationSettings

**Location**: `Domain/Entities/ApplicationSettings.swift`

**Purpose**: User preferences and configuration

**Definition**:
```swift
import Foundation

public struct ApplicationSettings: Sendable, Equatable, Codable {
    /// Whether bridge auto-starts on application launch
    public var autoStartBridge: Bool

    /// Charles proxy configuration
    public var charlesProxyHost: String
    public var charlesProxyPort: UInt16

    /// Menu bar icon display preference
    public var showMenuBarIcon: Bool

    /// Main window display preference
    public var showMainWindowOnLaunch: Bool

    public init(
        autoStartBridge: Bool = false,
        charlesProxyHost: String = "localhost",
        charlesProxyPort: UInt16 = 8888,
        showMenuBarIcon: Bool = true,
        showMainWindowOnLaunch: Bool = false  // FR-018: menu bar only
    ) {
        self.autoStartBridge = autoStartBridge
        self.charlesProxyHost = charlesProxyHost
        self.charlesProxyPort = charlesProxyPort
        self.showMenuBarIcon = showMenuBarIcon
        self.showMainWindowOnLaunch = showMainWindowOnLaunch
    }
}
```

**Validation Rules** (from FR-017, FR-018):
- `charlesProxyPort` in range 1-65535
- `charlesProxyHost` NOT empty
- `showMainWindowOnLaunch = false` by default (FR-018)
- Persisted in UserDefaults (non-sensitive data)

**Persistence Strategy**:
- Stored in UserDefaults (actor-based repository)
- No encryption needed (non-sensitive config)
- Bridge state stored separately (crash detection logic)

---

## Presentation Layer State

### 5. DashboardState

**Location**: `Presentation/ViewModels/DashboardViewModel.swift` (nested struct)

**Purpose**: Aggregate state for main dashboard window

**Definition**:
```swift
public struct DashboardState: Sendable, Equatable {
    /// List of connected devices (from MonitorDeviceConnectionsUseCase)
    public var devices: [DeviceConnection]

    /// Network bridge status (from MonitorNetworkStatusUseCase)
    public var networkStatus: NetworkStatus

    /// Charles proxy status (from CheckCharlesAvailabilityUseCase)
    public var charlesStatus: CharlesStatus

    /// Loading indicator (during initial data fetch)
    public var isLoading: Bool

    /// Selected device ID (for detail view, future feature)
    public var selectedDeviceId: UUID?

    public init(
        devices: [DeviceConnection] = [],
        networkStatus: NetworkStatus = NetworkStatus(isListening: false),
        charlesStatus: CharlesStatus = CharlesStatus(
            availability: .unknown,
            proxyHost: "localhost",
            proxyPort: 8888
        ),
        isLoading: Bool = false,
        selectedDeviceId: UUID? = nil
    ) {
        self.devices = devices
        self.networkStatus = networkStatus
        self.charlesStatus = charlesStatus
        self.isLoading = isLoading
        self.selectedDeviceId = selectedDeviceId
    }
}
```

**Derived Properties** (computed in ViewModel):
- `sortedDevices`: Devices sorted by `connectedAt` (newest first)
- `totalBytesSent`: Sum of all `device.bytesSent`
- `totalBytesReceived`: Sum of all `device.bytesReceived`

---

### 6. MenuBarState

**Location**: `Presentation/ViewModels/MenuBarViewModel.swift` (nested struct)

**Purpose**: State for menu bar menu content

**Definition**:
```swift
public struct MenuBarState: Sendable, Equatable {
    /// Current bridge enabled/disabled state
    public var isBridgeEnabled: Bool

    /// Number of active connections (for quick status)
    public var activeConnectionCount: Int

    /// Charles availability (for icon/status display)
    public var isCharlesAvailable: Bool

    public init(
        isBridgeEnabled: Bool = false,
        activeConnectionCount: Int = 0,
        isCharlesAvailable: Bool = false
    ) {
        self.isBridgeEnabled = isBridgeEnabled
        self.activeConnectionCount = activeConnectionCount
        self.isCharlesAvailable = isCharlesAvailable
    }
}
```

**State Sources**:
- `isBridgeEnabled` from ToggleBridgeUseCase
- `activeConnectionCount` from MonitorNetworkStatusUseCase
- `isCharlesAvailable` from CheckCharlesAvailabilityUseCase

---

### 7. SettingsState

**Location**: `Presentation/ViewModels/SettingsViewModel.swift` (nested struct)

**Purpose**: State for settings window

**Definition**:
```swift
public struct SettingsState: Sendable, Equatable {
    /// Current settings (editable copy)
    public var settings: ApplicationSettings

    /// Whether settings have unsaved changes
    public var isDirty: Bool

    /// Save operation in progress
    public var isSaving: Bool

    public init(
        settings: ApplicationSettings = ApplicationSettings(),
        isDirty: Bool = false,
        isSaving: Bool = false
    ) {
        self.settings = settings
        self.isDirty = isDirty
        self.isSaving = isSaving
    }
}
```

---

## Domain Value Objects

### 8. TrafficStatistics (Optional Enhancement)

**Location**: `Domain/ValueObjects/TrafficStatistics.swift`

**Purpose**: Encapsulate traffic byte counts with formatting

**Definition**:
```swift
import Foundation

public struct TrafficStatistics: Sendable, Equatable, Codable {
    public let bytesSent: Int64
    public let bytesReceived: Int64

    public init(bytesSent: Int64, bytesReceived: Int64) {
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
    }

    /// Total traffic (sent + received)
    public var totalBytes: Int64 {
        bytesSent + bytesReceived
    }

    /// Human-readable formatted strings
    public var formattedSent: String {
        ByteCountFormatter.trafficFormatter.string(fromByteCount: bytesSent)
    }

    public var formattedReceived: String {
        ByteCountFormatter.trafficFormatter.string(fromByteCount: bytesReceived)
    }

    public var formattedTotal: String {
        ByteCountFormatter.trafficFormatter.string(fromByteCount: totalBytes)
    }
}
```

**Usage**: Can replace separate `bytesSent`/`bytesReceived` fields in `DeviceConnection` if preferred. Current design keeps fields flat for simplicity.

---

## Repository Protocols (Domain Layer)

### 9. DeviceMonitorRepository

**Location**: `Domain/Protocols/DeviceMonitorRepository.swift`

```swift
import Foundation

public protocol DeviceMonitorRepository: Sendable {
    /// Observe real-time device connection updates
    func observeConnections() -> AsyncStream<[DeviceConnection]>

    /// Add a new device connection
    func addConnection(_ device: DeviceConnection) async

    /// Remove a device by ID (on disconnect)
    func removeConnection(_ deviceId: UUID) async

    /// Update traffic statistics for a device
    func updateTrafficStatistics(_ deviceId: UUID, bytesSent: Int64, bytesReceived: Int64) async
}
```

---

### 10. NetworkStatusRepository

**Location**: `Domain/Protocols/NetworkStatusRepository.swift`

```swift
import Foundation

public protocol NetworkStatusRepository: Sendable {
    /// Observe real-time network status updates
    func observeStatus() -> AsyncStream<NetworkStatus>

    /// Enable bridge (start listening)
    func enableBridge() async throws

    /// Disable bridge (stop accepting new connections, keep existing)
    func disableBridge() async throws
}
```

---

### 11. CharlesProxyRepository

**Location**: `Domain/Protocols/CharlesProxyRepository.swift`

```swift
import Foundation

public protocol CharlesProxyRepository: Sendable {
    /// Poll Charles availability at regular intervals
    func observeAvailability(interval: TimeInterval) -> AsyncStream<CharlesStatus>

    /// Check availability once (for manual refresh)
    func checkAvailability(host: String, port: UInt16) async -> CharlesStatus
}
```

---

### 12. SettingsRepository

**Location**: `Domain/Protocols/SettingsRepository.swift`

```swift
import Foundation

public protocol SettingsRepository: Sendable {
    /// Load settings from persistence
    func loadSettings() async -> ApplicationSettings

    /// Save settings to persistence
    func saveSettings(_ settings: ApplicationSettings) async throws

    /// Bridge state management (separate from settings for crash detection)
    func saveBridgeState(_ enabled: Bool) async
    func loadBridgeState() async -> Bool  // Returns false if crash detected

    /// Mark clean shutdown (for crash detection)
    func markCleanShutdown() async
}
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │ DashboardView    │  │ MenuBarView      │  │ SettingsView  │ │
│  │   ↕              │  │   ↕              │  │   ↕           │ │
│  │ DashboardVM      │  │ MenuBarVM        │  │ SettingsVM    │ │
│  │ (DashboardState) │  │ (MenuBarState)   │  │ (Settings     │ │
│  │                  │  │                  │  │  State)       │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
└────────┬─────────────────────┬─────────────────────┬────────────┘
         │                     │                     │
         │ Use Cases           │                     │
         ↓                     ↓                     ↓
┌─────────────────────────────────────────────────────────────────┐
│                          Domain Layer                            │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────┐│
│  │ MonitorDevices     │  │ MonitorNetwork     │  │ Toggle     ││
│  │ UseCase            │  │ StatusUseCase      │  │ Bridge     ││
│  │                    │  │                    │  │ UseCase    ││
│  │ CheckCharles       │  │ ManageSettings     │  │            ││
│  │ AvailabilityUseCase│  │ UseCase            │  │            ││
│  └────────────────────┘  └────────────────────┘  └────────────┘│
│         ↕                        ↕                     ↕         │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────┐│
│  │ Repository         │  │ Repository         │  │ Repository ││
│  │ Protocols          │  │ Protocols          │  │ Protocols  ││
│  └────────────────────┘  └────────────────────┘  └────────────┘│
└────────┬─────────────────────┬─────────────────────┬────────────┘
         │                     │                     │
         │ Implementations     │                     │
         ↓                     ↓                     ↓
┌─────────────────────────────────────────────────────────────────┐
│                           Data Layer                             │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────┐│
│  │ DeviceMonitor      │  │ NetworkStatus      │  │ Settings   ││
│  │ RepositoryImpl     │  │ RepositoryImpl     │  │ Repository ││
│  │ (actor)            │  │ (actor)            │  │ Impl       ││
│  │                    │  │                    │  │ (actor)    ││
│  │ CharlesProxy       │  │                    │  │            ││
│  │ RepositoryImpl     │  │                    │  │            ││
│  │ (actor)            │  │                    │  │            ││
│  └────────────────────┘  └────────────────────┘  └────────────┘│
│         ↕                        ↕                     ↕         │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────┐│
│  │ In-Memory          │  │ Bridge Integration │  │ UserDefaults│
│  │ AsyncStream        │  │ (existing bridge)  │  │ SwiftData  ││
│  └────────────────────┘  └────────────────────┘  └────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Concurrency Model

**Actor Boundaries**:
- All repositories are `actor` (thread-safe, serialized access)
- All ViewModels are `@MainActor` (UI updates on main thread)
- Entities are `Sendable` (safely cross actor boundaries)

**AsyncStream Lifecycles**:
- ViewModels subscribe to `AsyncStream` on `.onAppear`
- Streams emit updates when underlying data changes
- ViewModels cancel subscription via `Task.cancel()` on `.onDisappear`

**Example Flow** (Device Connection):
```
1. iOS device connects to bridge
2. Bridge calls DeviceMonitorRepositoryImpl.addConnection()
3. Repository updates internal dictionary, emits via AsyncStream continuation
4. DashboardViewModel receives update in `for await devices in stream`
5. ViewModel updates @Observable state.devices
6. SwiftUI automatically re-renders DashboardView
```

---

## Validation Summary

| Entity | Validation Rules | Enforcement Point |
|--------|------------------|-------------------|
| DeviceConnection | deviceName not empty, bytes ≥ 0 | `init()` + repository |
| NetworkStatus | port in valid range | Repository checks |
| CharlesStatus | host not empty, port valid | SettingsRepository |
| ApplicationSettings | port valid, host not empty | SettingsViewModel + repository |

---

## Test Data Examples

### Sample DeviceConnection
```swift
DeviceConnection(
    id: UUID(),
    deviceName: "iPhone 15 Pro",
    connectedAt: Date(),
    status: .active,
    bytesSent: 1_234_567,
    bytesReceived: 9_876_543
)
```

### Sample NetworkStatus
```swift
NetworkStatus(
    isListening: true,
    listeningPort: 12345,
    activeConnectionCount: 3,
    lastUpdated: Date()
)
```

### Sample CharlesStatus
```swift
CharlesStatus(
    availability: .available,
    proxyHost: "localhost",
    proxyPort: 8888,
    lastChecked: Date(),
    errorMessage: nil
)
```

---

## Conclusion

All entities, state structures, and repository protocols defined. Design satisfies:
- ✅ FR-001 to FR-018 (all functional requirements)
- ✅ Clean MVVM (Domain entities, Data repositories, Presentation state)
- ✅ Sendable conformance (Swift 6 concurrency)
- ✅ Testability (protocol-based, value types)
- ✅ Performance (in-memory streams, minimal allocations)

**Status**: ✅ **READY FOR QUICKSTART GUIDE**
