# Implementation Plan: LAN Auto-Discovery and Pairing

**Branch**: `001-lan-auto-discovery` | **Date**: 2025-11-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-lan-auto-discovery/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement zero-configuration LAN auto-discovery and pairing between Liuli-Server (macOS) and mobile clients (iOS/Android). The server broadcasts its availability via mDNS/DNS-SD (Bonjour on macOS), which mobile devices discover using platform-native APIs (Bonjour on iOS, NSD on Android). Once discovered, users tap to connect, establishing a VPN tunnel with trust-on-first-use (TOFU) certificate authentication. The system automatically disconnects when the server stops, preventing mobile devices from losing internet connectivity.

## Technical Context

**Language/Version**:
- macOS Server: Swift 6.0+ (strict concurrency enabled)
- iOS Client: Swift 6.0+ (existing Liuli-iOS codebase)
- Android Client: Kotlin 1.9+ / Java 17+ (existing Liuli-Android codebase)

**Primary Dependencies**:
- macOS: Foundation (NetService/Bonjour), Network.framework (heartbeat), Security (TLS certificates)
- iOS: Network.framework (Bonjour), NetworkExtension (VPN management), Security (cert validation)
- Android: android.net.nsd.NsdManager (service discovery), VpnService (VPN management)

**Storage**:
- macOS Server: SwiftData for connection history/logs (existing)
- iOS: UserDefaults for pairing records, Keychain for pinned certificates
- Android: SharedPreferences for pairing records, KeyStore for pinned certificates

**Testing**:
- macOS: XCTest (unit + integration)
- iOS: XCTest (unit + UI tests)
- Android: JUnit 4 + Espresso (unit + instrumentation)
- Cross-platform: Manual integration testing on same LAN

**Target Platform**:
- macOS 14.0+ (Liuli-Server)
- iOS 14.0+ (local network permissions)
- Android 4.1+ (API 16+ for NSD support)

**Project Type**: Mobile + API (macOS server + iOS/Android clients)

**Performance Goals**:
- Server discovery: < 5 seconds from app launch
- Connection establishment: < 500ms after server selection
- Heartbeat latency: < 10ms (every 3 seconds)
- Server broadcast frequency: every 5 seconds
- Support 5-10 concurrent mobile connections without degradation

**Constraints**:
- Same subnet only (no cross-VLAN)
- mDNS/DNS-SD protocol mandatory
- TOFU certificate authentication (no PKI)
- Background discovery on both platforms
- Zero manual configuration for 95% of users
- Automatic VPN disconnection within 10 seconds of server shutdown

**Scale/Scope**:
- 1 macOS server component (BonjourBroadcastService)
- 2 mobile client discovery modules (iOS Bonjour + Android NSD)
- ~500 LOC server-side, ~800 LOC per mobile platform
- 3 user stories (P1: discovery+pairing, P2: auto-disconnect, P3: persistent pairing)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Clean MVVM Architecture
- ✅ **PASS**: Feature adds new Domain use cases (DiscoverServersUseCase, ConnectToServerUseCase) and Data repositories (BonjourDiscoveryRepository for macOS, BonjourClientRepository for iOS, NsdClientRepository for Android)
- ✅ **PASS**: No layer violations - Presentation depends on Domain, Domain defines protocols, Data implements them
- ✅ **PASS**: No SwiftData models exposed to Presentation (pairing records mapped to Domain entities)

### 100% Constructor Injection
- ✅ **PASS**: All ViewModels (ServerDiscoveryViewModel) inject use cases via init()
- ✅ **PASS**: All use cases inject repositories via init()
- ✅ **PASS**: No singletons in business logic (NetService instances managed by repositories)

### Swift 6.0 Strict Concurrency
- ✅ **PASS**: All Domain entities are Sendable (DiscoveredServer, ServerConnection, PairingRecord)
- ✅ **PASS**: ViewModels marked @MainActor
- ✅ **PASS**: Repositories implemented as actor (BonjourDiscoveryRepository)
- ⚠️ **ATTENTION**: NetService (Foundation) is not Sendable - must wrap in actor and use @preconcurrency where needed
- ✅ **PASS**: All async operations use async/await (no DispatchQueue, no completion handlers)

### Test Coverage
- ✅ **TARGET**: Domain use cases ≥ 100% (mock repositories)
- ✅ **TARGET**: Data repositories ≥ 90% (mock NetService responses)
- ✅ **TARGET**: Presentation ViewModels ≥ 90% (mock use cases)
- ✅ **TARGET**: Views ≥ 70% (SwiftUI preview + snapshot tests)

### Zero Compiler Warnings
- ✅ **COMMITMENT**: Swift 6 strict concurrency enabled, zero warnings enforced
- ⚠️ **RISK**: NetService API predates Sendable - may require @preconcurrency imports

### Specification-Driven Development
- ✅ **PASS**: spec.md has 4 prioritized user stories (P1/P2/P3)
- ✅ **PASS**: Each story has Given/When/Then scenarios
- ✅ **PASS**: All 19 functional requirements (FR-001 to FR-019) will map to tasks

### Security & Privacy
- ✅ **PASS**: TOFU certificates stored in Keychain (iOS) / KeyStore (Android)
- ✅ **PASS**: No traffic content logging (only connection metadata)
- ✅ **PASS**: Local network only (mDNS limited to subnet)
- ✅ **PASS**: Certificate fingerprint validation on first connection

### Performance Standards
- ✅ **TARGET**: Connection establishment < 500ms (meets < 500ms standard)
- ✅ **TARGET**: Heartbeat forwarding < 50ms (meets < 50ms overhead)
- ✅ **TARGET**: Memory < 100MB baseline (discovery service is lightweight)
- ✅ **TARGET**: Concurrent connections: 5-10 (meets 100+ scalability with margin)

**GATE STATUS**: ✅ **PASSED** - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/001-lan-auto-discovery/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── bonjour-broadcast.md    # mDNS/DNS-SD service record format
│   ├── heartbeat-protocol.md   # Heartbeat message format
│   └── tofu-handshake.md       # TOFU certificate exchange protocol
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# macOS Server (Liuli-Server/)
Liuli-Server/
├── Domain/
│   ├── Entities/
│   │   ├── DiscoveredServer.swift      # (exists - update with discovery status)
│   │   ├── ServerConnection.swift      # (exists - add heartbeat tracking)
│   │   └── PairingRecord.swift         # (NEW - pairing history)
│   ├── UseCases/
│   │   ├── BroadcastServerAvailabilityUseCase.swift  # (NEW)
│   │   ├── SendHeartbeatUseCase.swift               # (NEW)
│   │   └── ManagePairingRecordsUseCase.swift        # (NEW)
│   └── Protocols/
│       ├── BonjourBroadcastRepository.swift         # (NEW - protocol)
│       └── HeartbeatRepository.swift                # (NEW - protocol)
├── Data/
│   ├── Repositories/
│   │   ├── BonjourBroadcastRepositoryImpl.swift     # (NEW - NetService wrapper)
│   │   └── HeartbeatRepositoryImpl.swift            # (NEW - Network.framework)
│   └── Models/
│       └── PairingRecordModel.swift                 # (NEW - @Model for SwiftData)
├── Presentation/
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift                 # (exists - add connected devices display)
│   │   └── SettingsViewModel.swift                  # (exists - add broadcast controls)
│   └── Views/
│       └── DashboardView.swift                      # (exists - show discovery status)
└── App/
    └── AppDependencyContainer.swift                 # (exists - add new services)

# iOS Client (Liuli-iOS/ - separate repository)
Liuli-iOS/
├── Domain/
│   ├── Entities/
│   │   ├── DiscoveredServer.swift                   # (NEW - server info)
│   │   └── PairingRecord.swift                      # (NEW - saved servers)
│   ├── UseCases/
│   │   ├── DiscoverServersUseCase.swift             # (NEW)
│   │   ├── ConnectToServerUseCase.swift             # (NEW)
│   │   └── MonitorServerHealthUseCase.swift         # (NEW - heartbeat monitoring)
│   └── Protocols/
│       ├── ServerDiscoveryRepository.swift          # (NEW - protocol)
│       └── ServerConnectionRepository.swift         # (NEW - protocol)
├── Data/
│   ├── Repositories/
│   │   ├── BonjourDiscoveryRepositoryImpl.swift     # (NEW - NSNetServiceBrowser)
│   │   └── VPNConnectionRepositoryImpl.swift        # (exists - add programmatic disconnect)
│   └── Storage/
│       └── PairingRecordStore.swift                 # (NEW - UserDefaults + Keychain)
├── Presentation/
│   ├── ViewModels/
│   │   ├── ServerDiscoveryViewModel.swift           # (NEW)
│   │   └── ServerListViewModel.swift                # (NEW)
│   └── Views/
│       ├── ServerDiscoveryView.swift                # (NEW)
│       └── ServerListView.swift                     # (NEW)
└── App/
    ├── Info.plist                                   # (update - NSLocalNetworkUsageDescription)
    └── AppDependencyContainer.swift                 # (update - add discovery services)

# Android Client (Liuli-Android/ - separate repository)
Liuli-Android/
├── domain/
│   ├── entities/
│   │   ├── DiscoveredServer.kt                      # (NEW)
│   │   └── PairingRecord.kt                         # (NEW)
│   ├── usecases/
│   │   ├── DiscoverServersUseCase.kt                # (NEW)
│   │   ├── ConnectToServerUseCase.kt                # (NEW)
│   │   └── MonitorServerHealthUseCase.kt            # (NEW)
│   └── repositories/
│       ├── ServerDiscoveryRepository.kt             # (NEW - interface)
│       └── ServerConnectionRepository.kt            # (NEW - interface)
├── data/
│   ├── repositories/
│   │   ├── NsdDiscoveryRepositoryImpl.kt            # (NEW - NsdManager)
│   │   └── VpnConnectionRepositoryImpl.kt           # (exists - add disconnect)
│   └── storage/
│       └── PairingRecordStore.kt                    # (NEW - SharedPreferences + KeyStore)
├── presentation/
│   ├── viewmodels/
│   │   ├── ServerDiscoveryViewModel.kt              # (NEW)
│   │   └── ServerListViewModel.kt                   # (NEW)
│   └── ui/
│       ├── ServerDiscoveryActivity.kt               # (NEW)
│       └── ServerListFragment.kt                    # (NEW)
└── AndroidManifest.xml                              # (update - permissions)
```

**Structure Decision**: This is a **Mobile + API** project with three components:
1. **macOS Server** (Liuli-Server): Clean MVVM with Swift 6 strict concurrency
2. **iOS Client** (Liuli-iOS): Clean MVVM architecture matching server patterns
3. **Android Client** (Liuli-Android): Clean Architecture with MVVM (Kotlin/Java)

All three components follow the same dependency flow (App → Presentation → Domain ← Data) and use constructor injection throughout.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected** - all constitution gates passed.

**Noted complexity**:
- **NetService Sendability**: Foundation's NetService predates Swift 6 Sendable. Mitigation: Wrap in `actor` and use `@preconcurrency import Foundation` where needed. This is a framework limitation, not an architecture violation.
