# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Liuli-Server is a macOS application that works in conjunction with Liuli-iOS (an iOS VPN app). Its primary function is to receive traffic from Liuli-iOS and forward it to Charles proxy tool for mobile traffic capture and analysis.

**Platform**: macOS 14.0+
**Language**: Swift 6.0+
**UI Framework**: SwiftUI
**Data Layer**: SwiftData
**Architecture**: Clean MVVM
**Concurrency**: Swift 6 strict concurrency enabled (`-strict-concurrency=complete`)

## Architecture Authority

**PRIMARY SOURCE**: This project follows architecture rules defined in `.specify/memory/constitution.md`

When conflicts arise, constitution.md takes precedence. Key principles:
- Clean MVVM with strict layer separation (App → Presentation → Domain ← Data)
- 100% constructor injection (no singletons in ViewModels/Use Cases)
- Swift 6.0 strict concurrency (zero data races)
- Test coverage targets (Domain 100%, Data 90%, Presentation 90%, Views 70%)
- Zero compiler warnings

Refer to constitution.md for complete rules and enforcement details.

## Development Environment

### Build & Run
```bash
# Open in Xcode
open Liuli-Server.xcodeproj

# Build from command line
xcodebuild -project Liuli-Server.xcodeproj -scheme Liuli-Server -configuration Debug build

# Run tests
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -destination 'platform=macOS'
```

### Project Structure
```
Liuli-Server/
├── App/                    # Application entry point and dependency injection
├── Domain/                 # Business entities, use cases, repository protocols
├── Data/                   # Repository implementations, data sources, SwiftData models
├── Presentation/           # SwiftUI views and ViewModels
├── Resources/              # Assets and localizations
└── Shared/                 # Shared UI components and utilities
```

## Networking Architecture

### LAN Auto-Discovery and Connection Flow (Feature 001)

```
Mobile Client (iOS/Android)
    ↓ [mDNS/Bonjour Discovery]
Liuli-Server (macOS) - Broadcast Service
    ↓ [TOFU Certificate Validation]
Mobile Client - TLS Handshake
    ↓ [VPN Tunnel Establishment]
Liuli-Server - SOCKS5 Bridge
    ↓ [Traffic Forwarding]
Charles Proxy Tool
    ↓ [Heartbeat Monitoring: 30s active / 60s background]
Mobile Client ←→ Liuli-Server (Health Check)
```

### Key Responsibilities
1. **Service Discovery**: Broadcast server availability via mDNS/Bonjour (`_liuli-proxy._tcp.local.`)
2. **Certificate Management**: Generate self-signed TLS certificates with TOFU (Trust-On-First-Use) pattern
3. **Connection Tracking**: Record and monitor active VPN connections with heartbeat protocol
4. **Pairing Persistence**: Store connection history for auto-reconnection
5. **Traffic Reception**: Accept incoming connections from Liuli-iOS/Android
6. **Protocol Handling**: Parse and process VPN protocol packets
7. **Proxy Forwarding**: Forward traffic to Charles proxy (typically localhost:8888)
8. **Error Handling**: Handle network failures, disconnections, and protocol errors

### Bonjour Broadcasting Pattern (macOS Server)

```swift
// Domain Entity
public struct ServiceBroadcast: Sendable, Equatable {
    public let serviceType: String = "_liuli-proxy._tcp."
    public let domain: String = "local."
    public let deviceName: String
    public let deviceID: UUID
    public let port: Int
    public let bridgeStatus: BridgeStatus
    public let certificateHash: String  // SHA-256 SPKI fingerprint

    public func generateTXTRecord() -> [String: String] {
        [
            "port": "\(port)",
            "version": "1.0.0",
            "device_id": deviceID.uuidString,
            "bridge_status": bridgeStatus.rawValue,
            "cert_hash": certificateHash
        ]
    }
}

// Repository Implementation
actor BonjourBroadcastRepositoryImpl: BonjourBroadcastRepositoryProtocol {
    private var netService: NetService?
    private nonisolated let delegate: NetServiceDelegateAdapter

    func startBroadcasting(config: ServiceBroadcast) async throws {
        let service = NetService(
            domain: config.domain,
            type: config.serviceType,
            name: config.deviceName,
            port: Int32(config.port)
        )
        service.setTXTRecord(config.generateTXTRecordData())
        service.publish()

        // Initial rapid broadcasts (3 times, 1s apart) for faster discovery
        for _ in 1...3 {
            try await Task.sleep(for: .seconds(1))
        }
    }
}
```

### Heartbeat Protocol Pattern

```swift
// SOCKS5 Heartbeat Extension (Custom Protocol)
// Request:  [0x05, 0xFF, 0x00]  (version, heartbeat cmd, reserved)
// Response: [0x05, 0x00]         (version, success)

actor HeartbeatRepositoryImpl: HeartbeatRepositoryProtocol {
    // Intervals per FR-006
    private let activeInterval: Duration = .seconds(30)     // App active
    private let backgroundInterval: Duration = .seconds(60) // App background
    private let responseTimeout: Duration = .seconds(5)
    private let maxRetries = 3                              // FR-007: 90s total

    func startSendingHeartbeats(connection: ServerConnection) -> AsyncStream<HeartbeatResult> {
        AsyncStream { continuation in
            var consecutiveFailures = 0

            while !Task.isCancelled {
                let result = await sendHeartbeat(connection: connection)

                switch result {
                case .success:
                    consecutiveFailures = 0
                    continuation.yield(.success(connectionID: connection.id, latency: latency))

                case .failure, .timeout:
                    consecutiveFailures += 1
                    if consecutiveFailures >= maxRetries {
                        continuation.yield(.timeout(connectionID: connection.id))
                        continuation.finish()
                        return
                    }
                    try? await Task.sleep(for: .seconds(10))
                }

                try? await Task.sleep(for: activeInterval)
            }
        }
    }
}

// Use Case: Integrate heartbeat with connection lifecycle
public actor ConnectionLifecycleManager {
    func startConnection(_ connection: ServerConnection) async throws {
        // 1. Record connection in SwiftData
        try await recordConnectionUseCase.execute(connection: connection)

        // 2. Start heartbeat monitoring
        let heartbeatStream = startHeartbeatUseCase.execute(connection: connection)

        // 3. Handle heartbeat failures → auto-disconnect after 3 failures
        for await result in heartbeatStream {
            if case .timeout = result {
                await stopConnection(connectionID: connection.id)
            }
        }
    }
}
```

### Certificate TOFU Pattern

```swift
// Server-side: Generate self-signed certificate on first launch
actor CertificateGenerator {
    func generateSelfSignedCertificate() async throws -> (SecCertificate, String) {
        // Generate RSA 2048-bit keypair
        let privateKey = SecKeyCreateRandomKey(parameters)

        // Create X.509 certificate (CN=<device_name>, 10-year validity)
        let certificate = try createX509Certificate(publicKey, privateKey)

        // Store in Keychain
        try await keychainService.storeCertificate(certificate, privateKey: privateKey)

        // Calculate SPKI fingerprint (SHA-256)
        let fingerprint = try calculateSPKIFingerprint(certificate: certificate)

        return (certificate, fingerprint)
    }

    func calculateSPKIFingerprint(certificate: SecCertificate) throws -> String {
        let publicKey = SecCertificateCopyKey(certificate)!
        let spkiData = SecKeyCopyExternalRepresentation(publicKey)
        let hash = SHA256.hash(data: spkiData)
        return hash.compactMap { String(format: "%02X", $0) }.joined()
    }
}

// Client-side: TOFU validation (iOS/Android)
// 1. On first connection: Show fingerprint to user → pin certificate
// 2. On subsequent connections: Validate against pinned fingerprint
// 3. On mismatch: Alert user (possible MITM or cert regeneration)
```

### Connection Tracking Pattern

```swift
// SwiftData Model (Data Layer)
@Model
final class ConnectionRecordModel {
    var id: UUID
    var serverID: UUID
    var deviceID: String
    var devicePlatform: String
    var deviceName: String
    var establishedAt: Date
    var terminatedAt: Date?
    var bytesSent: Int64
    var bytesReceived: Int64
    var lastHeartbeatAt: Date?
    var consecutiveHeartbeatFailures: Int
    var isActive: Bool
}

// Repository (Actor)
actor ConnectionTrackingRepositoryImpl: ConnectionTrackingRepositoryProtocol {
    func recordConnection(_ connection: ServerConnection) async throws {
        let model = ConnectionRecordModel.fromDomain(connection)
        modelContext.insert(model)
        try modelContext.save()
    }

    func getActiveConnections() async throws -> [ServerConnection] {
        let descriptor = FetchDescriptor<ConnectionRecordModel>(
            predicate: #Predicate { $0.isActive == true }
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }
}
```

### Pairing Persistence Pattern

```swift
// Domain Entity
public struct PairingRecord: Identifiable, Sendable {
    public let serverID: UUID
    public let deviceID: String
    public let devicePlatform: DevicePlatform
    public let firstConnectedAt: Date
    public let lastConnectedAt: Date
    public let successfulConnectionCount: Int
    public let failedConnectionCount: Int
    public let pinnedCertificateHash: String  // TOFU pin

    // Auto-purge after 30 days
    public var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return lastConnectedAt < thirtyDaysAgo
    }

    // Reliability score (for sorting preferred servers)
    public var reliabilityScore: Double {
        let total = successfulConnectionCount + failedConnectionCount
        guard total > 0 else { return 0 }
        return Double(successfulConnectionCount) / Double(total)
    }
}

// Repository: Auto-purge expired records
actor PairingRepositoryImpl: PairingRepositoryProtocol {
    func purgeExpiredRecords() async throws -> Int {
        let allRecords = try await getAllPairingRecords()
        let expired = allRecords.filter { $0.isExpired }

        for record in expired {
            try await deletePairingRecord(serverID: record.serverID)
        }

        return expired.count
    }
}
```

## Common Patterns

### Network Request Pattern
```swift
// Data Layer
actor NetworkRepository: MyDataRepository {
    private let session: URLSession

    func fetchData() async throws -> DomainModel {
        let (data, response) = try await session.data(from: url)
        return try mapToDomain(data)
    }
}

// Use Case
public struct FetchDataUseCase: Sendable {
    private let repository: MyDataRepository

    public func execute() async throws -> DomainModel {
        try await repository.fetchData()
    }
}

// ViewModel
@MainActor
final class MyViewModel: ObservableObject {
    private let fetchDataUseCase: FetchDataUseCase

    func loadData() async {
        do {
            let data = try await fetchDataUseCase.execute()
            // Update state
        } catch {
            // Handle error
        }
    }
}
```

### SwiftData Pattern
```swift
// Data Layer: @Model (internal to Data layer)
@Model
final class RecordModel {
    var id: UUID
    var timestamp: Date
}

// Domain Layer: Pure Swift entity
public struct Record: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
}

// Repository: Mapping layer
actor RecordRepository: RecordRepositoryProtocol {
    func fetchAll() async throws -> [Record] {
        let models = try context.fetch(FetchDescriptor<RecordModel>())
        return models.map { Record(model: $0) }
    }
}
```

### State Management Pattern
```swift
// State (value type)
struct MyViewState: Sendable, Equatable {
    var data: [Item] = []
    var isLoading = false
    var errorMessage: String?
}

// Actions
enum MyViewAction: Sendable {
    case onAppear
    case refresh
    case select(UUID)
}

// ViewModel
@MainActor
@Observable
final class MyViewModel {
    private let useCase: MyUseCase
    private(set) var state = MyViewState()

    func send(_ action: MyViewAction) {
        // Handle action, update state
    }
}
```

## Communication Language

- Use **Chinese** for all user-facing documentation, comments, and communication
- Use **English** for code identifiers, technical specifications, and architectural documents
- This CLAUDE.md file uses English as it serves as technical documentation

## Security Considerations

- All network communication must use secure protocols where applicable
- Proxy credentials (if any) must be stored in Keychain
- User privacy: no traffic content should be logged or persisted
- Connection metadata (timestamps, byte counts) stored via SwiftData must be encrypted

## Performance Requirements

- Application launch time: < 2 seconds
- Connection establishment: < 500ms
- Traffic forwarding latency: < 50ms overhead
- Memory usage: < 100MB baseline

## Quick Reference: Pre-Commit Checklist

Before committing code, verify:
- [ ] All layer dependencies follow correct direction (no reverse dependencies)
- [ ] No direct SwiftData access from Presentation layer
- [ ] All ViewModels use constructor injection (no singletons or `new` instances)
- [ ] Swift 6.0 strict concurrency passes (ZERO data race warnings)
- [ ] All concurrent types conform to `Sendable`
- [ ] All actor isolation boundaries are correct
- [ ] No `@unchecked Sendable` without justification
- [ ] No DispatchQueue or completion handlers (use async/await)
- [ ] All ViewModels marked with `@MainActor`
- [ ] All repositories implemented as `actor`
- [ ] Tests pass and coverage meets targets
- [ ] No compiler warnings
- [ ] Architecture guidelines followed

**Full checklist and rationale**: See `.specify/memory/constitution.md`

## Active Technologies
- Swift 6.0+ (strict concurrency enabled) + SwiftUI, SwiftData (for persistence), Foundation (URLSession for Charles detection), AppKit (NSStatusBar for menu bar) (002-main-ui-dashboard)
- SwiftData for settings persistence, UserDefaults for bridge state, connection tracking in-memory (002-main-ui-dashboard)

## Recent Changes
- 002-main-ui-dashboard: Added Swift 6.0+ (strict concurrency enabled) + SwiftUI, SwiftData (for persistence), Foundation (URLSession for Charles detection), AppKit (NSStatusBar for menu bar)
