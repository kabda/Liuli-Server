# Implementation Plan: iOS VPN Traffic Bridge to Charles

**Branch**: `001-ios-vpn-bridge` | **Date**: 2025-11-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ios-vpn-bridge/spec.md`

## Summary

Liuli-Server is a macOS menu bar application that bridges SOCKS5 traffic from iOS devices running Liuli VPN to Charles Proxy for packet capture and analysis. The application provides zero-configuration service discovery via Bonjour/mDNS, runs a SOCKS5 proxy server to accept iOS connections, and forwards all traffic to Charles Proxy (localhost:8888) with automatic reconnection on failures.

**Primary Requirement**: Enable QA engineers to capture iOS app network traffic in Charles Proxy without manual IP configuration or complex setup.

**Technical Approach**:
- SwiftNIO-based SOCKS5 server with RFC 1928 compliance
- Foundation NetService for Bonjour/mDNS advertisement
- SwiftUI + AppKit menu bar integration (LSUIElement app)
- Clean MVVM architecture with Swift 6.0 strict concurrency
- Actor-isolated network services with Sendable value types
- 100% constructor injection for dependency management

## Technical Context

**Language/Version**: Swift 6.0 (strict concurrency mode enabled: `-strict-concurrency=complete`)
**Primary Dependencies**:
- SwiftNIO 2.60+ (SOCKS5 server and bidirectional streaming)
- SwiftNIO-Extras 1.20+ (SOCKS protocol handlers)
- Foundation NetService (Bonjour/mDNS service discovery)
- SwiftUI + AppKit (menu bar UI)
- SwiftData (optional for connection history persistence)
- OSLog (structured logging)

**Storage**:
- UserDefaults for preferences (SOCKS5 port, Charles address, auto-start flags)
- In-memory only for connection statistics and history (session-scoped, privacy-first)
- No SwiftData models for this feature (all networking state is transient)

**Testing**:
- XCTest framework for unit and integration tests
- In-memory mock implementations for network dependencies
- Protocol-based mocking (no test frameworks required)
- Structured test hierarchy: Domain/UseCases, Data/Repositories, Presentation/ViewModels

**Target Platform**: macOS 14.0+ (Sonoma and later), Universal Binary (arm64 + x86_64)

**Project Type**: Single macOS application (menu bar app with no Dock icon)

**Performance Goals**:
- Service startup: < 3 seconds (SC-001)
- Bonjour advertisement: < 5 seconds (SC-002, SC-009)
- Traffic forwarding latency: < 5ms overhead (SC-014)
- Memory baseline: < 50MB with 10 connections (SC-008)
- UI responsiveness: < 100ms for menu interactions (SC-006)
- Concurrent connections: 100 without degradation (FR-012, SC-004)

**Constraints**:
- Swift 6.0 strict concurrency: ZERO data race warnings (mandatory)
- All Domain entities must be Sendable value types
- All repositories must be actor-isolated
- All ViewModels must be @MainActor @Observable
- No SwiftData @Model types exposed outside Data layer
- No completion handlers or DispatchQueue (async/await only)
- Local network only (RFC 1918 + link-local address validation)
- Menu bar-only app (LSUIElement = YES, no Dock icon)

**Scale/Scope**:
- 6 user stories (3 P1, 1 P2, 2 P3)
- 50 functional requirements across 7 categories
- 7 domain entities
- 15 measurable success criteria
- 100 max concurrent connections
- 50 historical connections in memory
- Single user per Mac (no multi-user support)

## Traffic Forwarding Strategy

**HTTP (port 80) vs HTTPS (port 443+) Handling**:

### HTTP Traffic (port 80)
- iOS client → SOCKS5 CONNECT to destination:80
- Mac Bridge → HTTP proxy request to Charles (proxy protocol)
- Charles sees plain HTTP, can inspect headers/body directly
- Implementation: Direct proxy forwarding without tunneling

### HTTPS Traffic (port 443+)
- iOS client → SOCKS5 CONNECT to destination:443
- Mac Bridge → HTTP CONNECT tunnel to Charles
- Charles sees encrypted TLS tunnel (CONNECT method)
- Decryption requires Charles SSL Proxying + iOS trust of Charles root cert

### Port Detection Logic
- **Port 80**: Plain HTTP proxy forwarding
- **Port 443**: HTTPS CONNECT tunneling (default)
- **Other ports**: Inspect destination or default to CONNECT tunneling

**Implementation**: CharlesForwardingHandler (T051) inspects destination port and uses appropriate forwarding mode (plain HTTP proxy vs CONNECT tunnel) per RFC 1928 and HTTP/1.1 proxy specs.

**Rationale**: Charles Proxy expects different protocols for HTTP vs HTTPS. Plain HTTP can be proxied directly, while HTTPS requires CONNECT tunneling to preserve end-to-end TLS encryption.

## Constitution Check

*Based on Clean MVVM Architecture Guidelines from CLAUDE.md*

### Gate 1: Dependency Direction (MUST PASS)

**Rule**: App → Presentation → Domain ← Data

**Check**:
- ✅ App layer creates dependency container
- ✅ Presentation depends only on Domain use cases
- ✅ Data implements Domain repository protocols
- ✅ Domain has zero dependencies on other layers
- ✅ No reverse dependencies (e.g., Data → Presentation)

**Status**: **PASS** - Architecture follows strict dependency flow

### Gate 2: Dependency Injection (MUST PASS)

**Rule**: 100% constructor injection, no singletons in ViewModels/Use Cases

**Check**:
- ✅ All ViewModels receive dependencies via init()
- ✅ All Use Cases receive repositories via init()
- ✅ No .shared, .default, or .global accessed from business logic
- ✅ AppDependencyContainer manages root object graph
- ✅ Default parameters allowed but still injected (e.g., = .shared in init signature)

**Status**: **PASS** - All dependencies constructor-injected

### Gate 3: Swift 6 Concurrency (MUST PASS)

**Rule**: Strict concurrency mode enabled, zero data races

**Check**:
- ✅ `-strict-concurrency=complete` compiler flag enabled
- ✅ All Domain entities conform to Sendable
- ✅ All repositories are actor-isolated
- ✅ All ViewModels are @MainActor
- ✅ All async boundaries use await (no sync calls across actors)
- ✅ No @unchecked Sendable without justification

**Status**: **PASS** - Full Swift 6 concurrency compliance

### Gate 4: Testing Requirements (MUST PASS)

**Rule**: Domain ≥100%, Data ≥90%, Presentation ≥90%, Views ≥70%

**Check**:
- ✅ XCTest framework configured
- ✅ Protocol-based mocking strategy defined
- ✅ Test structure mirrors source structure
- ✅ Coverage targets specified per layer

**Status**: **PASS** - Testing strategy complies with requirements

### Gate 5: Layer Isolation (MUST PASS)

**Rule**: No SwiftData @Model outside Data layer, no framework leaks

**Check**:
- ✅ No @Model types in Domain or Presentation
- ✅ Repositories map @Model ↔ Domain entities
- ✅ No Foundation/SwiftUI in Domain entities
- ✅ Domain uses only pure Swift types

**Status**: **PASS** - Layer boundaries strictly enforced

**OVERALL STATUS**: ✅ **ALL GATES PASSED**

## Project Structure

### Documentation (this feature)

```text
specs/001-ios-vpn-bridge/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Technology decisions and patterns
├── data-model.md        # Phase 1: Domain entities and relationships
├── quickstart.md        # Phase 1: Developer onboarding guide
├── contracts/           # Phase 1: API contracts and protocols
│   ├── domain-protocols.md       # Domain repository interfaces
│   ├── socks5-protocol.md        # SOCKS5 RFC 1928 wire format
│   └── bonjour-service.md        # mDNS service advertisement spec
└── checklists/
    └── requirements.md  # Specification validation checklist
```

### Source Code (repository root)

```text
Liuli-Server/
├── App/
│   ├── Liuli_ServerApp.swift          # @main entry point, SwiftUI scene
│   ├── AppDependencyContainer.swift   # Root DI container
│   └── MenuBarCoordinator.swift       # Menu bar lifecycle management
│
├── Domain/
│   ├── Entities/
│   │   ├── BridgeService.swift        # Service state (idle/starting/running/error)
│   │   ├── SOCKS5Connection.swift     # Connection metadata (source IP, dest, bytes)
│   │   ├── ConnectedDevice.swift      # iOS device info (IP, name, duration)
│   │   ├── ProxyConfiguration.swift   # User preferences (port, Charles addr)
│   │   └── ConnectionStatistics.swift # Session metrics (counts, bytes, throughput)
│   │
│   ├── ValueObjects/
│   │   ├── ServiceState.swift         # Enum: idle/starting/running/stopping/error
│   │   ├── SOCKS5Error.swift          # Enum: error codes (0x01-0x05)
│   │   └── CharlesProxyStatus.swift   # Enum: reachable/unreachable
│   │
│   ├── UseCases/
│   │   ├── StartServiceUseCase.swift          # Start SOCKS5 + Bonjour
│   │   ├── StopServiceUseCase.swift           # Stop all services
│   │   ├── ForwardConnectionUseCase.swift     # SOCKS5 → Charles forwarding
│   │   ├── DetectCharlesUseCase.swift         # Check Charles availability
│   │   ├── ManageConfigurationUseCase.swift   # Load/save preferences
│   │   └── TrackStatisticsUseCase.swift       # Monitor connections
│   │
│   └── Protocols/
│       ├── SOCKS5ServerRepository.swift       # Start/stop SOCKS5 server
│       ├── BonjourServiceRepository.swift     # Advertise/unpublish mDNS
│       ├── CharlesProxyRepository.swift       # Detect/launch Charles
│       ├── ConnectionRepository.swift         # Track active connections
│       └── ConfigurationRepository.swift      # Load/save UserDefaults
│
├── Data/
│   ├── Repositories/
│   │   ├── NIOSwiftSOCKS5ServerRepository.swift   # SwiftNIO SOCKS5 server
│   │   ├── NetServiceBonjourRepository.swift      # Foundation NetService wrapper
│   │   ├── ProcessCharlesRepository.swift         # Process + TCP detection
│   │   ├── InMemoryConnectionRepository.swift     # Actor-isolated connection tracking
│   │   └── UserDefaultsConfigRepository.swift     # Codable UserDefaults persistence
│   │
│   ├── NetworkServices/
│   │   ├── SOCKS5Handler.swift                # SwiftNIO channel handler
│   │   ├── CharlesForwardingHandler.swift     # HTTP CONNECT tunneling
│   │   ├── ConnectionTracker.swift            # Byte counting and idle timeout
│   │   └── IPAddressValidator.swift           # RFC 1918 + link-local validation
│   │
│   └── DataSources/
│       ├── NetworkReachability.swift          # Network interface change observer
│       └── SystemProcessMonitor.swift         # pgrep for Charles detection
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── MenuBarViewModel.swift             # Main menu state and actions
│   │   ├── StatisticsViewModel.swift          # Connection stats window
│   │   └── PreferencesViewModel.swift         # Settings window
│   │
│   ├── Views/
│   │   ├── MenuBarView.swift                  # NSPopover content (menu dropdown)
│   │   ├── StatisticsView.swift               # Connection list and metrics
│   │   ├── PreferencesView.swift              # Configuration form
│   │   └── Components/
│   │       ├── ServiceStatusIndicator.swift   # Color-coded icon (gray/green/yellow/red)
│   │       └── ConnectionRow.swift            # Single connection item
│   │
│   └── State/
│       ├── MenuBarViewState.swift             # Struct: service status, device count
│       ├── StatisticsViewState.swift          # Struct: connections, bytes, throughput
│       └── PreferencesViewState.swift         # Struct: port, address, flags
│
├── Resources/
│   ├── Assets.xcassets/
│   │   └── MenuBarIcon.imageset/              # Status bar icons (gray/green/yellow/red)
│   ├── Localizations/
│   │   ├── en.lproj/                          # English strings
│   │   └── zh-Hans.lproj/                     # Simplified Chinese strings
│   └── Info.plist                             # LSUIElement=YES, entitlements
│
├── Shared/
│   ├── Extensions/
│   │   ├── Data+HexString.swift               # Hex encoding for SOCKS5 debug
│   │   ├── IPAddress+Validation.swift         # RFC 1918 range checks
│   │   └── String+Localized.swift             # Localization helpers
│   │
│   └── Utilities/
│       ├── Logger.swift                       # OSLog wrapper
│       └── ExponentialBackoff.swift           # Retry logic (1s/2s/4s)
│
└── Liuli-ServerTests/
    ├── Domain/
    │   └── UseCases/
    │       ├── StartServiceUseCaseTests.swift
    │       ├── ForwardConnectionUseCaseTests.swift
    │       └── DetectCharlesUseCaseTests.swift
    │
    ├── Data/
    │   └── Repositories/
    │       ├── NIOSOCKS5ServerRepositoryTests.swift
    │       ├── NetServiceBonjourRepositoryTests.swift
    │       └── InMemoryConnectionRepositoryTests.swift
    │
    ├── Presentation/
    │   └── ViewModels/
    │       ├── MenuBarViewModelTests.swift
    │       ├── StatisticsViewModelTests.swift
    │       └── PreferencesViewModelTests.swift
    │
    └── Mocks/
        ├── MockSOCKS5ServerRepository.swift
        ├── MockBonjourServiceRepository.swift
        ├── MockCharlesProxyRepository.swift
        └── MockConfigurationRepository.swift
```

**Structure Decision**: Single macOS application following Clean MVVM architecture. The four-layer structure (App/Domain/Data/Presentation) is enforced with strict dependency flow. SwiftNIO networking code is encapsulated in Data/NetworkServices, while Domain contains pure Swift business logic. All cross-cutting concerns (logging, utilities) live in Shared/.

## Complexity Tracking

> **All Constitution Check gates passed - no violations to justify**

No complexity waivers required. The architecture strictly follows Clean MVVM with:
- Clear layer boundaries (no leaks)
- Pure domain logic (no framework dependencies)
- Actor-isolated data layer (Swift 6 compliant)
- MainActor ViewModels (UI safety guaranteed)
- Constructor injection (testable by design)
