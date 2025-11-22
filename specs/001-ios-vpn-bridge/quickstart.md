# Developer Quickstart Guide

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Audience**: Developers onboarding to Liuli-Server codebase

## Prerequisites

### System Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+ (Swift 6.0 support)
- Command Line Tools for Xcode
- Charles Proxy 4.6+ (for testing)
- Physical iOS device running Liuli VPN app (Simulator won't work for Bonjour)

### Knowledge Requirements

- Swift 6.0 (strict concurrency, actor isolation, Sendable)
- SwiftUI + AppKit basics
- Networking fundamentals (TCP, SOCKS5, HTTP CONNECT)
- Clean MVVM architecture pattern
- Async/await and structured concurrency

---

## Getting Started

### 1. Clone Repository

```bash
git clone https://github.com/your-org/Liuli-Server.git
cd Liuli-Server
```

### 2. Open Project

```bash
open Liuli-Server.xcodeproj
```

**Important**: This is a pure Swift Package Manager project with no CocoaPods or Carthage dependencies.

### 3. Configure Swift 6 Strict Concurrency

Project Build Settings (already configured):
- Swift Language Version: **Swift 6**
- Strict Concurrency Checking: **Complete** (`-strict-concurrency=complete`)

**Expected**: Zero data race warnings. If you see any, fix them immediately.

### 4. Run Tests

```bash
# Command line
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -destination 'platform=macOS'

# Or use Xcode: Cmd+U
```

**Expected**: All tests pass. Coverage targets:
- Domain Use Cases: ≥100%
- Data Repositories: ≥90%
- Presentation ViewModels: ≥90%

### 5. Run Application

```bash
# Command line
xcodebuild -project Liuli-Server.xcodeproj -scheme Liuli-Server -configuration Debug build
open build/Debug/Liuli-Server.app

# Or use Xcode: Cmd+R
```

**Expected**: Menu bar icon appears in top-right (no Dock icon, LSUIElement=YES).

---

## Project Structure Walkthrough

### App Layer (`Liuli-Server/App/`)

**Entry Point**: `Liuli_ServerApp.swift`

```swift
@main
struct Liuli_ServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}
```

**Dependency Injection**: `AppDependencyContainer.swift`

- Creates all repository instances (actor-isolated)
- Provides factory methods for Use Cases
- Wires up ViewModels with dependencies

**Menu Bar Coordinator**: `MenuBarCoordinator.swift`

- Manages NSStatusItem lifecycle
- Handles menu bar icon color changes
- Presents NSPopover with SwiftUI content

---

### Domain Layer (`Liuli-Server/Domain/`)

**Pure Swift** - No framework dependencies (except Foundation's Date/UUID/String).

#### Entities (`Domain/Entities/`)

| File | Purpose | Type |
|------|---------|------|
| `BridgeService.swift` | Service lifecycle state | Struct (Sendable) |
| `SOCKS5Connection.swift` | Per-connection metadata | Struct (Sendable) |
| `ConnectedDevice.swift` | iOS device grouping | Struct (Sendable) |
| `ProxyConfiguration.swift` | User preferences | Struct (Codable) |
| `ConnectionStatistics.swift` | Session metrics | Struct (Sendable) |

#### Use Cases (`Domain/UseCases/`)

| File | Responsibility |
|------|----------------|
| `StartServiceUseCase.swift` | Start SOCKS5 + Bonjour |
| `StopServiceUseCase.swift` | Stop all services |
| `ForwardConnectionUseCase.swift` | SOCKS5 → Charles forwarding |
| `DetectCharlesUseCase.swift` | Check Charles availability |
| `ManageConfigurationUseCase.swift` | Load/save preferences |
| `TrackStatisticsUseCase.swift` | Monitor connections |

**Pattern**: All Use Cases are structs with constructor-injected repositories.

```swift
public struct StartServiceUseCase: Sendable {
    private let socks5Repository: SOCKS5ServerRepository
    private let bonjourRepository: BonjourServiceRepository

    public init(
        socks5Repository: SOCKS5ServerRepository,
        bonjourRepository: BonjourServiceRepository
    ) {
        self.socks5Repository = socks5Repository
        self.bonjourRepository = bonjourRepository
    }

    public func execute(configuration: ProxyConfiguration) async throws {
        try await socks5Repository.start(configuration: configuration)
        try await bonjourRepository.advertise(/* ... */)
    }
}
```

#### Protocols (`Domain/Protocols/`)

Repository interfaces (see `contracts/domain-protocols.md` for full API):

- `SOCKS5ServerRepository`
- `BonjourServiceRepository`
- `CharlesProxyRepository`
- `ConnectionRepository`
- `ConfigurationRepository`

---

### Data Layer (`Liuli-Server/Data/`)

**Implements** Domain repository protocols. **NEVER** expose SwiftNIO or NetService types to Domain.

#### Repositories (`Data/Repositories/`)

| File | Implements | Technology |
|------|-----------|------------|
| `NIOSwiftSOCKS5ServerRepository.swift` | `SOCKS5ServerRepository` | SwiftNIO 2.60+ |
| `NetServiceBonjourRepository.swift` | `BonjourServiceRepository` | Foundation NetService |
| `ProcessCharlesRepository.swift` | `CharlesProxyRepository` | NSWorkspace + TCP |
| `InMemoryConnectionRepository.swift` | `ConnectionRepository` | Actor-isolated dictionary |
| `UserDefaultsConfigRepository.swift` | `ConfigurationRepository` | UserDefaults + Codable |

**Pattern**: All repositories are `actor` for thread safety.

```swift
actor NIOSwiftSOCKS5ServerRepository: SOCKS5ServerRepository {
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var serverChannel: Channel?

    func start(configuration: ProxyConfiguration) async throws {
        // SwiftNIO bootstrap code
    }

    func stop() async {
        try? await serverChannel?.close()
    }
}
```

#### Network Services (`Data/NetworkServices/`)

SwiftNIO channel handlers (see `contracts/socks5-protocol.md` for wire format):

- `SOCKS5Handler.swift` - RFC 1928 protocol parsing
- `CharlesForwardingHandler.swift` - HTTP CONNECT tunneling
- `ConnectionTracker.swift` - Byte counting + idle timeout
- `IPAddressValidator.swift` - RFC 1918 range checks

---

### Presentation Layer (`Liuli-Server/Presentation/`)

**SwiftUI views** + **ViewModels** (@MainActor @Observable).

#### ViewModels (`Presentation/ViewModels/`)

| File | Manages |
|------|---------|
| `MenuBarViewModel.swift` | Service state, start/stop actions |
| `StatisticsViewModel.swift` | Connection list, byte counters |
| `PreferencesViewModel.swift` | Configuration form, validation |

**Pattern**: ViewModels are `@MainActor` classes with `@Observable` macro.

```swift
@MainActor
@Observable
final class MenuBarViewModel {
    private let startServiceUseCase: StartServiceUseCase
    private let stopServiceUseCase: StopServiceUseCase

    private(set) var state = MenuBarViewState()

    init(
        startServiceUseCase: StartServiceUseCase,
        stopServiceUseCase: StopServiceUseCase
    ) {
        self.startServiceUseCase = startServiceUseCase
        self.stopServiceUseCase = stopServiceUseCase
    }

    func send(_ action: MenuBarViewAction) {
        switch action {
        case .startService:
            Task {
                do {
                    try await startServiceUseCase.execute(configuration: state.configuration)
                    state.serviceState = .running
                } catch {
                    state.serviceState = .error
                    state.errorMessage = error.localizedDescription
                }
            }
        // ...
        }
    }
}
```

#### Views (`Presentation/Views/`)

Pure declarative SwiftUI (no business logic):

- `MenuBarView.swift` - Menu dropdown content
- `StatisticsView.swift` - Connection list window
- `PreferencesView.swift` - Settings form

---

## Common Development Tasks

### Adding a New Use Case

1. Define protocol in `Domain/Protocols/`
2. Implement repository in `Data/Repositories/`
3. Create Use Case struct in `Domain/UseCases/`
4. Inject into ViewModel via `AppDependencyContainer`
5. Call from ViewModel action handler
6. Write unit tests for Use Case + repository

**Example**: Adding "Export Statistics" feature

```swift
// 1. Domain/Protocols/StatisticsExporter.swift
protocol StatisticsExporter: Sendable {
    func export(statistics: ConnectionStatistics, format: ExportFormat) async throws -> Data
}

// 2. Data/Repositories/JSONStatisticsExporter.swift
actor JSONStatisticsExporter: StatisticsExporter {
    func export(statistics: ConnectionStatistics, format: ExportFormat) async throws -> Data {
        // JSONEncoder implementation
    }
}

// 3. Domain/UseCases/ExportStatisticsUseCase.swift
public struct ExportStatisticsUseCase: Sendable {
    private let exporter: StatisticsExporter
    private let connectionRepository: ConnectionRepository

    public func execute(format: ExportFormat) async throws -> Data {
        let stats = await connectionRepository.getStatistics()
        return try await exporter.export(statistics: stats, format: format)
    }
}

// 4. Presentation/ViewModels/StatisticsViewModel.swift
func exportAsJSON() async {
    do {
        let data = try await exportStatisticsUseCase.execute(format: .json)
        // Save to file
    } catch {
        // Show error
    }
}
```

### Running Integration Tests

**Requirement**: Physical iOS device + Liuli VPN app installed

1. Build and run Liuli-Server
2. Click "Start Service" in menu bar
3. On iOS device, open Liuli VPN
4. Select your Mac from server list
5. Connect VPN
6. Open Safari on iOS and browse any website
7. Verify traffic appears in Charles Proxy

**Expected**: All HTTP/HTTPS requests visible in Charles within 10 seconds.

### Debugging SOCKS5 Protocol

Enable verbose logging:

```swift
Logger.network.debug("SOCKS5 handshake: \(buffer.hexDump())")
```

Use `dns-sd` to verify Bonjour:

```bash
dns-sd -B _charles-bridge._tcp local.
```

Use `tcpdump` to capture SOCKS5 traffic:

```bash
sudo tcpdump -i any -n port 9000 -X
```

### Performance Profiling

**Memory Leaks**:

```bash
leaks --atExit -- /path/to/Liuli-Server.app/Contents/MacOS/Liuli-Server
```

**Instruments**:

- Time Profiler: Check for hot paths in forwarding loop
- Allocations: Verify < 50MB with 10 connections
- Network: Measure latency overhead (target < 5ms)

---

## Testing Strategy

### Unit Tests (XCTest)

**Location**: `Liuli-ServerTests/`

**Pattern**: Use protocol mocks in `Mocks/` directory

```swift
@MainActor
final class StartServiceUseCaseTests: XCTestCase {
    func testStartServiceSucceeds() async throws {
        let mockSOCKS5 = MockSOCKS5ServerRepository()
        let mockBonjour = MockBonjourServiceRepository()

        let useCase = StartServiceUseCase(
            socks5Repository: mockSOCKS5,
            bonjourRepository: mockBonjour
        )

        let config = ProxyConfiguration.default
        try await useCase.execute(configuration: config)

        XCTAssertEqual(mockSOCKS5.startCallCount, 1)
        XCTAssertEqual(mockBonjour.advertiseCallCount, 1)
    }

    func testStartServiceThrowsWhenPortInUse() async throws {
        let mockSOCKS5 = MockSOCKS5ServerRepository()
        mockSOCKS5.shouldThrowOnStart = true

        let useCase = StartServiceUseCase(socks5Repository: mockSOCKS5, bonjourRepository: MockBonjourServiceRepository())

        do {
            try await useCase.execute(configuration: .default)
            XCTFail("Expected error")
        } catch BridgeServiceError.portInUse {
            // Expected
        }
    }
}
```

### Integration Tests

Test concrete repository implementations with real SwiftNIO/NetService.

### Manual Test Checklist

See `checklists/requirements.md` for full validation checklist covering all 50 functional requirements.

---

## Troubleshooting

### Build Errors

**"Data race detected"**: Swift 6 strict concurrency violation

- Ensure all shared types conform to `Sendable`
- Mark ViewModels with `@MainActor`
- Use `actor` for repositories
- No synchronous calls across actor boundaries

**"Cannot find 'NIOCore' in scope"**: SwiftNIO not resolved

```bash
xcodebuild -resolvePackageDependencies
```

### Runtime Issues

**Service won't start**: Check Console.app for OSLog errors

```bash
log stream --predicate 'subsystem == "com.liuli.server"'
```

**iOS can't discover Mac**: Verify Bonjour advertisement

```bash
dns-sd -B _charles-bridge._tcp local.
```

**Traffic not appearing in Charles**: Check forwarding handler

- Verify Charles is listening on localhost:8888
- Check SOCKS5 CONNECT requests in logs
- Ensure HTTP CONNECT method is used for HTTPS

---

## Code Review Checklist

Before submitting PR:

- [ ] All layer dependencies follow correct direction (no reverse deps)
- [ ] No SwiftData @Model outside Data layer
- [ ] All ViewModels use constructor injection (no singletons)
- [ ] Swift 6 strict concurrency passes (zero warnings)
- [ ] All concurrent types conform to Sendable
- [ ] All ViewModels marked @MainActor
- [ ] All repositories implemented as actor
- [ ] Tests pass and coverage meets targets (Domain ≥100%, Data ≥90%, Presentation ≥90%)
- [ ] No compiler warnings
- [ ] Architecture guidelines followed (see CLAUDE.md)

---

## Resources

### Documentation

- [CLAUDE.md](../../../CLAUDE.md) - Project architecture guidelines
- [spec.md](./spec.md) - Feature specification
- [plan.md](./plan.md) - Implementation plan
- [research.md](./research.md) - Technology decisions
- [data-model.md](./data-model.md) - Domain entities
- [contracts/](./contracts/) - API contracts and protocols

### External References

- [Swift 6 Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [SwiftNIO Documentation](https://swiftpackageindex.com/apple/swift-nio)
- [RFC 1928: SOCKS5 Protocol](https://datatracker.ietf.org/doc/html/rfc1928)
- [RFC 6763: DNS-SD (Bonjour)](https://datatracker.ietf.org/doc/html/rfc6763)
- [Charles Proxy Documentation](https://www.charlesproxy.com/documentation/)

### Community

- GitHub Issues: Report bugs and feature requests
- Pull Requests: Follow PR template and checklist

---

## Next Steps

1. Read `spec.md` to understand user requirements
2. Review `CLAUDE.md` for architecture rules
3. Explore `Domain/` layer to understand business logic
4. Run tests to verify setup (`Cmd+U`)
5. Start implementing tasks from `tasks.md` (Phase 2, not yet created)

**Happy coding! 🚀**
