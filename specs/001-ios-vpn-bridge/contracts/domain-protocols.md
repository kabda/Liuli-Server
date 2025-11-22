# Domain Repository Protocols

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Purpose**: Define abstract interfaces for Data layer repositories consumed by Domain Use Cases

## Overview

All repository protocols are defined in the Domain layer (`Domain/Protocols/`) and implemented in the Data layer (`Data/Repositories/`). This enforces dependency inversion: Domain depends on abstractions, Data depends on Domain.

### Key Principles

1. **Protocol-first design**: Use Cases depend on protocols, not concrete implementations
2. **async/await only**: No completion handlers (Swift 6 concurrency requirement)
3. **Sendable conformance**: All protocols must be `Sendable` for actor isolation
4. **Error propagation**: Throw domain-specific errors, not implementation errors
5. **No side effects in protocols**: Pure interfaces (no logging, analytics, etc.)

---

## 1. SOCKS5ServerRepository

**Purpose**: Manage lifecycle of SOCKS5 proxy server (start/stop/status)

**Location**: `Domain/Protocols/SOCKS5ServerRepository.swift`

```swift
import Foundation

/// Manages SOCKS5 proxy server lifecycle (RFC 1928)
public protocol SOCKS5ServerRepository: Sendable {
    /// Start SOCKS5 server on specified port
    /// - Parameter configuration: Proxy configuration including port
    /// - Throws: `BridgeServiceError.portInUse` if port already bound
    /// - Throws: `BridgeServiceError.invalidConfiguration` if config invalid
    func start(configuration: ProxyConfiguration) async throws

    /// Stop SOCKS5 server gracefully
    /// - Note: Closes all active connections with proper SOCKS5 teardown
    /// - Throws: Never (best-effort stop)
    func stop() async

    /// Get current server status
    /// - Returns: True if server is listening and accepting connections
    func isRunning() async -> Bool

    /// Observe connection events (new connections, bytes transferred)
    /// - Returns: AsyncStream of connection updates
    /// - Note: Stream completes when server stops
    func connectionStream() -> AsyncStream<SOCKS5Connection>
}
```

**Implementation**: `NIOSwiftSOCKS5ServerRepository` (SwiftNIO-based)

**Usage Example**:
```swift
// In StartServiceUseCase
let repository: SOCKS5ServerRepository = // injected
try await repository.start(configuration: config)
```

---

## 2. BonjourServiceRepository

**Purpose**: Advertise and unpublish mDNS/Bonjour service for iOS discovery

**Location**: `Domain/Protocols/BonjourServiceRepository.swift`

```swift
import Foundation

/// Manages Bonjour/mDNS service advertisement for iOS discovery
public protocol BonjourServiceRepository: Sendable {
    /// Advertise Bonjour service with specified parameters
    /// - Parameters:
    ///   - serviceName: Human-readable name (e.g., "MacBook-Pro")
    ///   - serviceType: mDNS service type (always "_charles-bridge._tcp.")
    ///   - domain: mDNS domain (always "local.")
    ///   - port: SOCKS5 server port number
    ///   - txtRecord: Additional metadata (version, device model)
    /// - Throws: `BridgeServiceError.bonjourRegistrationFailed` if registration fails
    func advertise(
        serviceName: String,
        serviceType: String,
        domain: String,
        port: Int,
        txtRecord: [String: String]
    ) async throws

    /// Stop advertising Bonjour service
    /// - Note: Service disappears from iOS Liuli VPN server list within 5 seconds
    func unpublish() async

    /// Get current advertisement status
    /// - Returns: True if service is currently advertised
    func isAdvertising() async -> Bool

    /// Observe network interface changes (Wi-Fi ↔ Ethernet)
    /// - Returns: AsyncStream of network change events
    /// - Note: Triggers re-advertisement automatically
    func networkChangeStream() -> AsyncStream<NetworkInterfaceChange>
}

/// Network interface change event
public struct NetworkInterfaceChange: Sendable, Equatable {
    public let oldInterface: String?  // e.g., "en0"
    public let newInterface: String   // e.g., "en1"
    public let timestamp: Date
}
```

**Implementation**: `NetServiceBonjourRepository` (Foundation NetService wrapper)

**Usage Example**:
```swift
// In StartServiceUseCase
try await bonjourRepository.advertise(
    serviceName: Host.current().localizedName ?? "Mac Bridge",
    serviceType: "_charles-bridge._tcp.",
    domain: "local.",
    port: 9000,
    txtRecord: ["version": "1.0.0", "device": "MacBookPro18,1"]
)
```

---

## 3. CharlesProxyRepository

**Purpose**: Detect Charles Proxy availability and launch application

**Location**: `Domain/Protocols/CharlesProxyRepository.swift`

```swift
import Foundation

/// Detects and manages Charles Proxy application
public protocol CharlesProxyRepository: Sendable {
    /// Check if Charles Proxy is running and reachable
    /// - Parameters:
    ///   - host: Charles proxy host (default "localhost")
    ///   - port: Charles proxy port (default 8888)
    ///   - timeout: Maximum time to wait for TCP connection
    /// - Returns: Status indicating reachability and error reason if unreachable
    func detect(host: String, port: Int, timeout: TimeInterval) async -> CharlesProxyStatus

    /// Attempt to launch Charles Proxy application
    /// - Throws: `BridgeServiceError.charlesNotInstalled` if app not found
    /// - Note: Opens Charles.app via NSWorkspace
    func launch() async throws

    /// Bring Charles Proxy to foreground (if already running)
    /// - Returns: True if successfully activated
    func activate() async -> Bool

    /// Get Charles Proxy installation path
    /// - Returns: Path to Charles.app bundle, or nil if not installed
    func getInstallationPath() async -> String?
}
```

**Implementation**: `ProcessCharlesRepository` (NSWorkspace + TCP socket)

**Usage Example**:
```swift
// In DetectCharlesUseCase
let status = await charlesRepository.detect(host: "localhost", port: 8888, timeout: 2.0)
if !status.isAvailable {
    // Show warning notification
}
```

---

## 4. ConnectionRepository

**Purpose**: Track active SOCKS5 connections and aggregate statistics

**Location**: `Domain/Protocols/ConnectionRepository.swift`

```swift
import Foundation

/// Tracks active SOCKS5 connections for monitoring and statistics
public protocol ConnectionRepository: Sendable {
    /// Add a new connection to tracking
    /// - Parameter connection: Connection metadata
    func add(_ connection: SOCKS5Connection) async

    /// Update connection bytes transferred
    /// - Parameters:
    ///   - id: Connection identifier
    ///   - bytesUploaded: New uploaded byte count
    ///   - bytesDownloaded: New downloaded byte count
    func updateBytes(id: UUID, bytesUploaded: UInt64, bytesDownloaded: UInt64) async

    /// Remove connection when closed
    /// - Parameter id: Connection identifier
    /// - Note: Moves connection to historical log (last 50)
    func remove(id: UUID) async

    /// Get all active connections
    /// - Returns: Array of currently open connections
    func getActiveConnections() async -> [SOCKS5Connection]

    /// Get connections grouped by device (iOS IP address)
    /// - Returns: Array of connected devices with their connections
    func getConnectedDevices() async -> [ConnectedDevice]

    /// Get aggregated statistics for current session
    /// - Returns: Connection statistics including counts and bytes
    func getStatistics() async -> ConnectionStatistics

    /// Clear all connections and reset statistics
    /// - Note: Called when app restarts or service stops
    func reset() async
}
```

**Implementation**: `InMemoryConnectionRepository` (actor-isolated in-memory storage)

**Usage Example**:
```swift
// In TrackStatisticsUseCase
let stats = await connectionRepository.getStatistics()
let devices = await connectionRepository.getConnectedDevices()
```

---

## 5. ConfigurationRepository

**Purpose**: Load and save user preferences (ProxyConfiguration)

**Location**: `Domain/Protocols/ConfigurationRepository.swift`

```swift
import Foundation

/// Persists user preferences using UserDefaults
public protocol ConfigurationRepository: Sendable {
    /// Load saved configuration
    /// - Returns: User configuration or default if not found
    /// - Throws: `BridgeServiceError.corruptedConfiguration` if data invalid
    func load() async throws -> ProxyConfiguration

    /// Save configuration to persistent storage
    /// - Parameter configuration: Configuration to persist
    /// - Throws: `BridgeServiceError.saveFailed` if write fails
    func save(_ configuration: ProxyConfiguration) async throws

    /// Observe configuration changes (e.g., from preferences window)
    /// - Returns: AsyncStream of configuration updates
    func configurationStream() -> AsyncStream<ProxyConfiguration>

    /// Validate configuration without saving
    /// - Parameter configuration: Configuration to validate
    /// - Returns: True if configuration is valid per FR-044
    func validate(_ configuration: ProxyConfiguration) async -> Bool
}
```

**Implementation**: `UserDefaultsConfigRepository` (Codable + JSONEncoder)

**Usage Example**:
```swift
// In ManageConfigurationUseCase
let config = try await configRepository.load()
if await configRepository.validate(modifiedConfig) {
    try await configRepository.save(modifiedConfig)
}
```

---

## Domain Error Types

All repositories throw domain-specific errors (never Data layer errors):

```swift
public enum BridgeServiceError: Error, Sendable, Equatable {
    // Service lifecycle errors
    case portInUse(Int)
    case bonjourRegistrationFailed(String)
    case serviceAlreadyRunning

    // Charles Proxy errors
    case charlesUnreachable
    case charlesNotInstalled
    case charlesLaunchFailed(String)

    // Configuration errors
    case invalidConfiguration(String)
    case corruptedConfiguration
    case saveFailed(String)

    // Network errors
    case networkInterfaceUnavailable
    case connectionFailed(SOCKS5ErrorCode)
}
```

---

## Repository Implementation Checklist

For each repository implementation in Data layer:

- [ ] Conform to Domain protocol (no extra public methods)
- [ ] Use `actor` for thread safety (Swift 6 requirement)
- [ ] Map Data layer errors to Domain errors at boundary
- [ ] All methods are `async` (no completion handlers)
- [ ] No logging or analytics in protocol methods (delegate to Use Cases)
- [ ] 100% unit test coverage with protocol mocks
- [ ] No dependencies on other repositories (composition in Use Cases only)

---

## Testing Strategy

### Unit Tests (Domain Layer)

Use protocol mocks in `Liuli-ServerTests/Mocks/`:

```swift
actor MockSOCKS5ServerRepository: SOCKS5ServerRepository {
    var startCallCount = 0
    var stopCallCount = 0
    var shouldThrowOnStart = false

    func start(configuration: ProxyConfiguration) async throws {
        startCallCount += 1
        if shouldThrowOnStart {
            throw BridgeServiceError.portInUse(configuration.socks5Port)
        }
    }

    func stop() async {
        stopCallCount += 1
    }

    func isRunning() async -> Bool {
        startCallCount > stopCallCount
    }

    func connectionStream() -> AsyncStream<SOCKS5Connection> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

### Integration Tests (Data Layer)

Test concrete repository implementations:

```swift
@MainActor
final class NIOSwiftSOCKS5ServerRepositoryTests: XCTestCase {
    func testStartServerBindsPort() async throws {
        let repo = NIOSwiftSOCKS5ServerRepository()
        let config = ProxyConfiguration(socks5Port: 19000) // High port to avoid conflicts

        try await repo.start(configuration: config)
        let isRunning = await repo.isRunning()
        XCTAssertTrue(isRunning)

        await repo.stop()
    }

    func testStartThrowsWhenPortInUse() async throws {
        let repo1 = NIOSwiftSOCKS5ServerRepository()
        let repo2 = NIOSwiftSOCKS5ServerRepository()
        let config = ProxyConfiguration(socks5Port: 19001)

        try await repo1.start(configuration: config)

        do {
            try await repo2.start(configuration: config)
            XCTFail("Expected port in use error")
        } catch BridgeServiceError.portInUse(let port) {
            XCTAssertEqual(port, 19001)
        }

        await repo1.stop()
    }
}
```

---

## Dependency Injection Wiring

In `AppDependencyContainer`:

```swift
final class AppDependencyContainer {
    // Repositories (actor-isolated)
    private let socks5Repository: SOCKS5ServerRepository
    private let bonjourRepository: BonjourServiceRepository
    private let charlesRepository: CharlesProxyRepository
    private let connectionRepository: ConnectionRepository
    private let configRepository: ConfigurationRepository

    init() {
        // Instantiate concrete implementations
        self.socks5Repository = NIOSwiftSOCKS5ServerRepository()
        self.bonjourRepository = NetServiceBonjourRepository()
        self.charlesRepository = ProcessCharlesRepository()
        self.connectionRepository = InMemoryConnectionRepository()
        self.configRepository = UserDefaultsConfigRepository()
    }

    // Factory methods for Use Cases
    func makeStartServiceUseCase() -> StartServiceUseCase {
        StartServiceUseCase(
            socks5Repository: socks5Repository,
            bonjourRepository: bonjourRepository,
            charlesRepository: charlesRepository,
            configRepository: configRepository
        )
    }

    // ... other factory methods
}
```

---

## Protocol Evolution Guidelines

When adding new methods to protocols:

1. **Use default implementations** for backward compatibility (if possible)
2. **Version the protocol** with protocol inheritance if breaking changes required
3. **Update all implementations** simultaneously (compile-time enforcement)
4. **Update mocks** in test targets

Example:
```swift
// Version 2 adds observation capability
public protocol SOCKS5ServerRepositoryV2: SOCKS5ServerRepository {
    func observeServerEvents() -> AsyncStream<ServerEvent>
}

// Default implementation for existing code
extension SOCKS5ServerRepository {
    public func observeServerEvents() -> AsyncStream<ServerEvent> {
        AsyncStream { continuation in continuation.finish() }
    }
}
```
