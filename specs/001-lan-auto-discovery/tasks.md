# Tasks: LAN Auto-Discovery and Pairing

**Input**: Design documents from `/specs/001-lan-auto-discovery/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in the specification. This task list focuses on implementation only.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a **Mobile + API** project with three components:
- **macOS Server**: `Liuli-Server/` (repository root)
- **iOS Client**: `Liuli-iOS/` (separate repository - tasks reference conceptual paths)
- **Android Client**: `Liuli-Android/` (separate repository - tasks reference conceptual paths)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and cross-platform structure

### macOS Server Setup

- [ ] T001 Create Domain layer structure: `Domain/Entities/`, `Domain/Repositories/`, `Domain/UseCases/`
- [ ] T002 [P] Create Data layer structure: `Data/Repositories/`, `Data/Models/`
- [ ] T003 [P] Create Presentation layer structure: `Presentation/ViewModels/`, `Presentation/Views/`
- [ ] T004 [P] Update Info.plist with Bonjour service types (`_liuli-proxy._tcp`)
- [ ] T005 [P] Add Network.framework to project dependencies

### iOS Client Setup

- [ ] T006 Update Info.plist with `NSLocalNetworkUsageDescription` for local network access
- [ ] T007 [P] Add Network.framework capability to iOS target
- [ ] T008 [P] Create discovery module structure: `Domain/`, `Data/`, `Presentation/`

### Android Client Setup

- [ ] T009 Add JmDNS dependency to `app/build.gradle.kts` (version 3.5.9)
- [ ] T010 [P] Add required permissions to `AndroidManifest.xml` (INTERNET, CHANGE_WIFI_MULTICAST_STATE, ACCESS_WIFI_STATE, ACCESS_NETWORK_STATE)
- [ ] T011 [P] Create discovery module structure: `domain/`, `data/`, `presentation/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Domain Entities (Shared Across All Stories)

- [ ] T012 [P] Create `DiscoveredServer` entity in `Domain/Entities/DiscoveredServer.swift` with properties: id, name, address, port, bridgeStatus, protocolVersion, certificateHash, lastSeenAt, connectionStatus
- [ ] T013 [P] Create `ServiceBroadcast` entity in `Domain/Entities/ServiceBroadcast.swift` with TXT record generation method
- [ ] T014 [P] Create `PairingRecord` entity in `Domain/Entities/PairingRecord.swift` with success/failure tracking methods
- [ ] T015 [P] Create `ServerConnection` entity in `Domain/Entities/ServerConnection.swift` with heartbeat monitoring fields

### macOS Server - Certificate Infrastructure

- [ ] T016 Generate self-signed TLS certificate on first launch using Security framework in `Data/Services/CertificateGenerator.swift`
- [ ] T017 [P] Implement SPKI fingerprint calculation (SHA-256) in `Data/Services/CertificateGenerator.swift`
- [ ] T018 [P] Store certificate and private key in macOS Keychain via `Data/Services/KeychainService.swift`
- [ ] T019 [P] Display certificate fingerprint in Dashboard UI for user verification

### Repository Protocols

- [ ] T020 [P] Define `BonjourBroadcastRepositoryProtocol` in `Domain/Repositories/BonjourBroadcastRepositoryProtocol.swift`
- [ ] T021 [P] Define `ServerDiscoveryRepositoryProtocol` in `Domain/Repositories/ServerDiscoveryRepositoryProtocol.swift` (for clients)
- [ ] T022 [P] Define `HeartbeatRepositoryProtocol` in `Domain/Repositories/HeartbeatRepositoryProtocol.swift`
- [ ] T023 [P] Define `PairingRepositoryProtocol` in `Domain/Repositories/PairingRepositoryProtocol.swift`
- [ ] T024 [P] Define `LoggingServiceProtocol` in `Domain/Services/LoggingServiceProtocol.swift` for critical event tracking (connection, disconnection, auth failures, errors)
- [ ] T025 Implement `LoggingServiceImpl` actor in `Data/Services/LoggingServiceImpl.swift` using unified logging framework (os_log)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Automatic Server Discovery (Priority: P1) 🎯 MVP Part 1

**Goal**: Mobile devices automatically discover available Liuli-Server instances on the local network without manual IP entry

**Independent Test**: Launch Liuli-Server on Mac with bridge enabled, open Liuli mobile app on same LAN, verify server appears in list showing device name and "Available" status

### macOS Server - Bonjour Broadcasting

- [ ] T026 [US1] Implement `BonjourBroadcastRepositoryImpl` actor in `Data/Repositories/BonjourBroadcastRepositoryImpl.swift` using NetService
- [ ] T027 [US1] Implement `NetServiceDelegateAdapter` (marked @unchecked Sendable) to bridge NetService callbacks to async/await
- [ ] T028 [US1] Create `StartBroadcastingUseCase` in `Domain/UseCases/StartBroadcastingUseCase.swift` with constructor-injected repository
- [ ] T029 [US1] Create `StopBroadcastingUseCase` in `Domain/UseCases/StopBroadcastingUseCase.swift`
- [ ] T030 [US1] Integrate broadcasting start/stop with existing bridge lifecycle in `Data/Services/SOCKS5DeviceBridgeService.swift`
- [ ] T031 [US1] Add bridge status tracking and update TXT record when status changes

### iOS Client - Bonjour Discovery

- [ ] T032 [P] [US1] Implement `BonjourDiscoveryRepositoryImpl` actor in `Data/Repositories/BonjourDiscoveryRepositoryImpl.swift` using Network.framework NWBrowser
- [ ] T033 [P] [US1] Implement TXT record parsing to extract port, device_id, bridge_status, cert_hash from NWEndpoint.Service
- [ ] T034 [US1] Create `DiscoverServersUseCase` in `Domain/UseCases/DiscoverServersUseCase.swift` returning AsyncStream<DiscoveredServer>
- [ ] T035 [US1] Create `ServerDiscoveryViewModel` in `Presentation/ViewModels/ServerDiscoveryViewModel.swift` with @MainActor and @Observable
- [ ] T036 [US1] Create `ServerListView` SwiftUI view in `Presentation/Views/ServerListView.swift` displaying discovered servers
- [ ] T037 [US1] Add refresh button to trigger manual discovery restart
- [ ] T038 [US1] Handle "No servers found" state with manual configuration fallback UI

### Android Client - NSD Discovery

- [ ] T039 [P] [US1] Implement `NsdDiscoveryRepositoryImpl` in `data/repositories/NsdDiscoveryRepositoryImpl.kt` using JmDNS library
- [ ] T040 [P] [US1] Implement multicast lock acquisition and release in `NsdDiscoveryRepositoryImpl`
- [ ] T041 [P] [US1] Implement TXT record parsing using `ServiceInfo.getPropertyString()` for all required fields
- [ ] T042 [US1] Create `DiscoverServersUseCase` in `domain/usecases/DiscoverServersUseCase.kt` returning Flow<DiscoveredServer>
- [ ] T043 [US1] Create `ServerDiscoveryViewModel` in `presentation/viewmodels/ServerDiscoveryViewModel.kt` using StateFlow
- [ ] T044 [US1] Create `ServerListScreen` Composable in `presentation/ui/ServerListScreen.kt` displaying server list
- [ ] T045 [US1] Add refresh icon button and handle "No servers found" state

### Cross-Platform Integration

- [ ] T046 [US1] Verify server discovery completes within 5 seconds on both iOS and Android
- [ ] T047 [US1] Test multiple server discovery (2-3 Macs running Liuli-Server simultaneously)
- [ ] T048 [US1] Handle duplicate device names by appending UUID suffix for disambiguation

**Checkpoint**: At this point, both iOS and Android apps can discover macOS servers automatically

---

## Phase 4: User Story 2 - One-Tap Connection Pairing (Priority: P1) 🎯 MVP Part 2

**Goal**: Users can select a discovered server and establish VPN connection with single tap

**Independent Test**: Discover a server (from US1), tap on it, verify VPN connection establishes and device appears in server Dashboard

### macOS Server - Connection Tracking

- [ ] T057 [US2] Create SwiftData model `ConnectionRecordModel` in `Data/Models/ConnectionRecordModel.swift` for tracking active connections
- [ ] T058 [US2] Implement `ConnectionTrackingRepositoryImpl` actor in `Data/Repositories/ConnectionTrackingRepositoryImpl.swift`
- [ ] T059 [US2] Create `RecordConnectionUseCase` in `Domain/UseCases/RecordConnectionUseCase.swift`
- [ ] T060 [US2] Update Dashboard to display connected devices in real-time using existing DashboardViewModel

### iOS Client - TOFU Certificate Authentication

- [ ] T061 [P] [US2] Implement certificate validation in `Data/Services/CertificateValidator.swift` actor
- [ ] T062 [P] [US2] Implement `getSPKIFingerprint()` method using Security framework (SecCertificateCopyKey + SHA256)
- [ ] T063 [P] [US2] Implement Keychain storage for pinned certificates in `Data/Services/KeychainService.swift`
- [ ] T064 [US2] Create `TOFUPromptView` SwiftUI sheet in `Presentation/Views/TOFUPromptView.swift` showing fingerprint with Trust/Reject buttons
- [ ] T065 [US2] Create `ValidateCertificateUseCase` in `Domain/UseCases/ValidateCertificateUseCase.swift`
- [ ] T066 [US2] Integrate TOFU validation into existing VPN connection flow before tunnel establishment

### iOS Client - VPN Connection

- [ ] T067 [US2] Create `ConnectToServerUseCase` in `Domain/UseCases/ConnectToServerUseCase.swift` orchestrating certificate validation + VPN setup
- [ ] T068 [US2] Add connection state management to `ServerDiscoveryViewModel` (connecting, connected, failed)
- [ ] T069 [US2] Update `ServerListView` to handle tap gesture and display connection status
- [ ] T070 [US2] Implement connection error handling with retry option
- [ ] T071 [US2] Handle switching between servers (disconnect existing before connecting to new)

### Android Client - TOFU Certificate Authentication

- [ ] T072 [P] [US2] Implement certificate validation in `data/services/CertificateValidator.kt`
- [ ] T073 [P] [US2] Implement `getSPKIFingerprint()` method using X509TrustManager and MessageDigest
- [ ] T074 [P] [US2] Store pinned certificates in SharedPreferences with server UUID as key
- [ ] T075 [US2] Create `TOFUPromptDialog` Composable in `presentation/ui/TOFUPromptDialog.kt` with Trust/Reject actions
- [ ] T076 [US2] Create `ValidateCertificateUseCase` in `domain/usecases/ValidateCertificateUseCase.kt`
- [ ] T077 [US2] Create custom X509TrustManager implementing TOFU logic in `data/services/TofuTrustManager.kt`

### Android Client - VPN Connection

- [ ] T078 [US2] Create `ConnectToServerUseCase` in `domain/usecases/ConnectToServerUseCase.kt`
- [ ] T079 [US2] Update `ServerDiscoveryViewModel` to handle connection state changes
- [ ] T080 [US2] Update `ServerListScreen` to handle item clicks and show connection status
- [ ] T081 [US2] Implement error handling and retry logic for connection failures
- [ ] T082 [US2] Handle server switching (disconnect current before connecting to new)

### Cross-Platform Validation

- [ ] T083 [US2] Verify connection establishment completes in < 500ms after server selection
- [ ] T084 [US2] Test TOFU flow on first connection (fingerprint prompt appears)
- [ ] T085 [US2] Test subsequent connections (auto-connect without prompt)
- [ ] T086 [US2] Test certificate mismatch detection (server regenerates cert)

**Checkpoint**: At this point, User Stories 1 AND 2 form a complete MVP - users can discover and connect to servers with zero configuration

---

## Phase 5: User Story 3 - Automatic Disconnection on Server Shutdown (Priority: P2)

**Goal**: VPN connection automatically disconnects when server stops, preventing mobile device from losing internet access

**Independent Test**: Establish connection (from US2), stop bridge service or quit Liuli-Server, verify mobile device disconnects VPN within 10 seconds and shows notification

### macOS Server - Heartbeat Protocol

- [ ] T087 [US3] Implement `HeartbeatRepositoryImpl` actor in `Data/Repositories/HeartbeatRepositoryImpl.swift`
- [ ] T088 [US3] Implement heartbeat sending logic: send `[0x05, 0xFF, 0x00]` packet every 30 seconds over VPN tunnel
- [ ] T089 [US3] Implement heartbeat response validation: expect `[0x05, 0x00]` within 5 seconds
- [ ] T090 [US3] Create `StartHeartbeatUseCase` in `Domain/UseCases/StartHeartbeatUseCase.swift`
- [ ] T091 [US3] Integrate heartbeat lifecycle with connection tracking (start on connect, stop on disconnect)
- [ ] T092 [US3] Implement retry logic (max 3 retries with 10-second intervals)
- [ ] T093 [US3] Disconnect client after 3 consecutive heartbeat failures

### iOS Client - Heartbeat Monitoring

- [ ] T094 [P] [US3] Implement `HeartbeatMonitorRepositoryImpl` actor in `Data/Repositories/HeartbeatMonitorRepositoryImpl.swift`
- [ ] T095 [P] [US3] Implement heartbeat request detection: check for `[0x05, 0xFF, 0x00]` in incoming VPN packets
- [ ] T096 [P] [US3] Implement heartbeat response sending: reply with `[0x05, 0x00]`
- [ ] T097 [US3] Implement timeout detection: trigger disconnect if no heartbeat received for 90 seconds
- [ ] T098 [US3] Create `MonitorServerHealthUseCase` in `Domain/UseCases/MonitorServerHealthUseCase.swift`
- [ ] T099 [US3] Implement automatic VPN disconnect on timeout using existing VPN manager
- [ ] T100 [US3] Display local notification when VPN auto-disconnects due to server shutdown

### Android Client - Heartbeat Monitoring

- [ ] T101 [P] [US3] Implement `HeartbeatMonitorRepository` in `data/repositories/HeartbeatMonitorRepositoryImpl.kt`
- [ ] T102 [P] [US3] Implement heartbeat packet detection and response logic
- [ ] T103 [P] [US3] Implement 90-second timeout detection using coroutines
- [ ] T104 [US3] Create `MonitorServerHealthUseCase` in `domain/usecases/MonitorServerHealthUseCase.kt`
- [ ] T105 [US3] Implement automatic VPN disconnect on timeout
- [ ] T106 [US3] Show notification explaining why VPN was disconnected

### Edge Case Handling

- [ ] T107 [US3] Implement graceful shutdown in macOS server: send goodbye packet before stopping
- [ ] T108 [US3] Handle network transitions (WiFi to cellular): pause heartbeats, don't trigger disconnect
- [ ] T109 [US3] Distinguish server shutdown from network loss: retry 3 times before notifying user

**Checkpoint**: All P1 and P2 stories complete - automatic disconnection prevents internet loss

---

## Phase 6: User Story 4 - Persistent Pairing for Quick Reconnection (Priority: P3)

**Goal**: Mobile app remembers previously paired servers and auto-reconnects to last used server when available

**Independent Test**: Connect to server, close mobile app, reopen app while server still running, verify automatic reconnection without user interaction

### macOS Server - Pairing Record Storage

- [ ] T110 [US4] Create `PairingRecordModel` SwiftData model in `Data/Models/PairingRecordModel.swift`
- [ ] T111 [US4] Implement `PairingRepositoryImpl` actor in `Data/Repositories/PairingRepositoryImpl.swift`
- [ ] T112 [US4] Implement pairing record creation on first successful connection
- [ ] T113 [US4] Implement 30-day auto-purge logic for old pairing records
- [ ] T114 [US4] Display pairing history in Dashboard settings panel

### iOS Client - Persistent Pairing

- [ ] T115 [P] [US4] Implement `PairingRepositoryImpl` in `Data/Repositories/PairingRepositoryImpl.swift` using UserDefaults
- [ ] T116 [P] [US4] Implement pairing record save on successful connection with success/failure counters
- [ ] T117 [US4] Create `GetLastConnectedServerUseCase` in `Domain/UseCases/GetLastConnectedServerUseCase.swift`
- [ ] T118 [US4] Create `AutoReconnectUseCase` in `Domain/UseCases/AutoReconnectUseCase.swift`
- [ ] T119 [US4] Integrate auto-reconnect into app launch sequence in `ServerDiscoveryViewModel`
- [ ] T120 [US4] Skip auto-reconnect if last server not discoverable within 10 seconds
- [ ] T121 [US4] Update last connected server when user manually switches servers
- [ ] T122 [US4] Implement "Forget Server" action to delete pairing record

### Android Client - Persistent Pairing

- [ ] T123 [P] [US4] Implement `PairingRepositoryImpl` in `data/repositories/PairingRepositoryImpl.kt` using SharedPreferences
- [ ] T124 [P] [US4] Implement pairing record persistence with success/failure tracking
- [ ] T125 [US4] Create `GetLastConnectedServerUseCase` in `domain/usecases/GetLastConnectedServerUseCase.kt`
- [ ] T126 [US4] Create `AutoReconnectUseCase` in `domain/usecases/AutoReconnectUseCase.kt`
- [ ] T127 [US4] Integrate auto-reconnect into MainActivity onCreate
- [ ] T128 [US4] Handle cases where last server is unavailable (show server list instead)
- [ ] T129 [US4] Update preferred server on manual selection
- [ ] T130 [US4] Implement "Forget Server" menu action

### Reliability Metrics

- [ ] T131 [US4] Display connection reliability percentage in server list (success/total ratio)
- [ ] T132 [US4] Sort servers by reliability score (prefer stable connections)

**Checkpoint**: All user stories complete - full feature set delivered

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final validation

### Performance Optimization

- [ ] T133 [P] Verify server discovery completes < 5 seconds (FR-002 requirement)
- [ ] T134 [P] Verify connection establishment < 500ms (performance goal)
- [ ] T135 [P] Profile heartbeat battery impact on iOS (target < 0.3%/hour)
- [ ] T136 [P] Profile heartbeat battery impact on Android (target < 0.5%/hour)
- [ ] T137 [P] Test concurrent connections (5-10 devices) on server without degradation

### Error Handling & Logging

- [ ] T138 [P] Implement critical event logging on macOS server: connection establishment, disconnection, authentication failures
- [ ] T139 [P] Implement critical event logging on iOS client
- [ ] T140 [P] Implement critical event logging on Android client
- [ ] T141 [P] Add user-friendly error messages for common failures (firewall blocked, network unreachable, certificate mismatch)

### Edge Cases & Stability

- [ ] T142 Handle rapid server start/stop cycles with 2-second debounce
- [ ] T143 Handle network transitions (WiFi to cellular and back)
- [ ] T144 Handle duplicate device names with UUID suffix disambiguation
- [ ] T145 Handle firewall blocking connection (10-second timeout with clear error)
- [ ] T146 Handle different subnets (show manual config option)

### Documentation & Validation

- [ ] T147 [P] Run quickstart.md validation on all three platforms
- [ ] T148 [P] Update CLAUDE.md with new discovery and heartbeat patterns
- [ ] T149 [P] Document certificate regeneration procedure for server
- [ ] T150 [P] Document "Forget Server" user action for clients

### Final Integration Testing

- [ ] T151 End-to-end test: Discover → Connect → Use → Server Shutdown → Auto-disconnect (iOS)
- [ ] T152 End-to-end test: Discover → Connect → Use → Server Shutdown → Auto-disconnect (Android)
- [ ] T153 Multi-platform test: iOS and Android simultaneously connected to same server
- [ ] T154 Network resilience test: Disable WiFi during connection, verify graceful handling
- [ ] T155 Certificate security test: MITM attempt detection, fingerprint mismatch handling

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - **US1 + US2 (P1)**: Form MVP core, should complete first (can work in parallel after Phase 2)
  - **US3 (P2)**: Depends on US2 (needs active connections to monitor)
  - **US4 (P3)**: Depends on US2 (needs connections to persist), independent of US3
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1 - Discovery)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1 - Connection)**: Can start after Foundational - Depends on US1 for server list, but independently testable with mock data
- **User Story 3 (P2 - Auto-disconnect)**: Depends on US2 (needs established connections to monitor heartbeats)
- **User Story 4 (P3 - Persistent Pairing)**: Depends on US2 (needs connection history), independent of US3

### Within Each User Story

- **macOS tasks** can run in parallel with **iOS tasks** and **Android tasks** (different codebases)
- Models before services
- Services before integration
- Repository implementations before use cases
- Use cases before ViewModels
- ViewModels before Views

### Parallel Opportunities

**Within Phase 1 (Setup)**: All tasks marked [P] can run in parallel per platform

**Within Phase 2 (Foundational)**:
- T012-T015 (Domain entities) can all run in parallel
- T016-T019 (Certificate tasks) are sequential
- T020-T023 (Repository protocols) can all run in parallel

**Within User Story 1**:
- macOS broadcasting (T034-T035) parallel with iOS discovery (T034-T032) parallel with Android discovery (T033-T039)
- Within iOS: T034-T035 can run in parallel
- Within Android: T033-T035 can run in parallel

**Within User Story 2**:
- macOS tracking (T043-T046) parallel with iOS TOFU (T047-T060) parallel with Android TOFU (T066-T071)
- iOS tasks: T047-T057 parallel, then T058-T060
- Android tasks: T066-T068 parallel, then T069-T071

**Within User Story 3**:
- macOS heartbeat (T081-T087) parallel with iOS monitoring (T088-T094) parallel with Android monitoring (T095-T100)
- iOS: T088-T090 can run in parallel
- Android: T095-T097 can run in parallel

**Within User Story 4**:
- macOS storage (T102-T106) parallel with iOS pairing (T107-T114) parallel with Android pairing (T115-T122)
- iOS: T107-T108 can run in parallel
- Android: T115-T116 can run in parallel

**Within Phase 7 (Polish)**:
- All performance tasks (T125-T129) can run in parallel
- All logging tasks (T130-T133) can run in parallel
- All documentation tasks (T139-T142) can run in parallel

---

## Parallel Example: User Story 1 (Discovery)

```bash
# Launch all platform implementations in parallel (different codebases):

# macOS Server Team:
Task T034: "Implement BonjourBroadcastRepositoryImpl actor in Data/Repositories/BonjourBroadcastRepositoryImpl.swift"
Task T035: "Implement NetServiceDelegateAdapter"

# iOS Client Team:
Task T034: "Implement BonjourDiscoveryRepositoryImpl actor in Data/Repositories/BonjourDiscoveryRepositoryImpl.swift"
Task T035: "Implement TXT record parsing"

# Android Client Team:
Task T033: "Implement NsdDiscoveryRepositoryImpl in data/repositories/NsdDiscoveryRepositoryImpl.kt"
Task T034: "Implement multicast lock acquisition"
Task T035: "Implement TXT record parsing"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only - P1)

1. Complete Phase 1: Setup (all platforms)
2. Complete Phase 2: Foundational (CRITICAL - entities, protocols, certificate infrastructure)
3. Complete Phase 3: User Story 1 (automatic discovery)
4. Complete Phase 4: User Story 2 (one-tap connection with TOFU)
5. **STOP and VALIDATE**: Test discovery + connection flow on iOS and Android
6. Deploy/demo MVP

**MVP Scope**: Users can discover servers automatically and connect with single tap (zero manual configuration). This delivers the core value proposition stated in the user's initial request.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (T001-T023)
2. Add User Story 1 → Test discovery independently → Deploy/Demo
3. Add User Story 2 → Test connection independently → Deploy/Demo (MVP complete!)
4. Add User Story 3 (P2) → Test auto-disconnect independently → Deploy/Demo
5. Add User Story 4 (P3) → Test persistent pairing independently → Deploy/Demo
6. Polish Phase → Final validation → Production release

### Parallel Team Strategy

With multiple developers:

1. **Phase 2**: Team collaborates on foundational infrastructure
2. **Phase 3-6**: Once foundational is complete, split by platform:
   - **macOS Developer**: Server-side tasks (broadcasting, heartbeat, connection tracking)
   - **iOS Developer**: iOS client tasks (discovery, connection, TOFU, heartbeat monitoring)
   - **Android Developer**: Android client tasks (NSD, connection, TOFU, heartbeat monitoring)
3. Each platform can progress through user stories independently
4. Regular integration testing to verify cross-platform compatibility

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label (US1, US2, US3, US4) maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Tests are NOT included (not requested in specification)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Certificate fingerprint MUST be displayed on server for user verification during TOFU
- Heartbeat protocol uses SOCKS5 extension (command byte 0xFF)
- mDNS service type: `_liuli-proxy._tcp.local.`
- All actors must use constructor injection (no singletons)
- Swift 6 strict concurrency enabled - all concurrent types must be Sendable
- Follow constitution.md for architecture compliance

---

## Task Count Summary

- **Total Tasks**: 147
- **Phase 1 (Setup)**: 11 tasks (T001-T011)
- **Phase 2 (Foundational)**: 14 tasks (T012-T025)
- **Phase 3 (US1 - Discovery)**: 23 tasks (T034-T042)
- **Phase 4 (US2 - Connection)**: 30 tasks (T043-T080)
- **Phase 5 (US3 - Auto-disconnect)**: 23 tasks (T081-T103)
- **Phase 6 (US4 - Persistent Pairing)**: 23 tasks (T102-T124)
- **Phase 7 (Polish)**: 23 tasks (T125-T147)

**Parallel Opportunities Identified**: 67 tasks marked [P] (46% of total)

**MVP Scope**: Phases 1-4 (T001-T080) = 76 tasks = 52% of total work

**Independent Test Criteria**:
- US1: Server appears in app list within 5 seconds
- US2: Tap connects, device appears in Dashboard
- US3: Server stop triggers auto-disconnect in < 10s
- US4: App relaunch auto-connects to last server
