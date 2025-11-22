# Tasks: iOS VPN Traffic Bridge to Charles

**Input**: Design documents from `/specs/001-ios-vpn-bridge/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY per constitution.md (Domain ≥100%, Data ≥90%, Presentation ≥90%, Views ≥70%). See Phase 9 for complete test suite. Manual validation of acceptance scenarios from spec.md will be performed in addition to automated tests.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4, US5, US6)
- Include exact file paths in descriptions

## Path Conventions

This is a macOS Swift application following Clean MVVM architecture:
- **Domain**: `Liuli-Server/Domain/` (entities, use cases, protocols)
- **Data**: `Liuli-Server/Data/` (repositories, network services)
- **Presentation**: `Liuli-Server/Presentation/` (views, viewmodels)
- **App**: `Liuli-Server/App/` (entry point, dependency injection)
- **Shared**: `Liuli-Server/Shared/` (utilities, extensions)
- **Tests**: `Liuli-ServerTests/` (mirrors source structure)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Swift 6.0 strict concurrency configuration

- [ ] T001 Configure Xcode project with Swift 6.0 and strict concurrency flag (-strict-concurrency=complete) ⚠️ MANUAL
- [ ] T002 Add SwiftNIO 2.60+ and SwiftNIO-Extras 1.20+ dependencies to Package.swift ⚠️ MANUAL
- [X] T003 [P] Create Clean MVVM folder structure (App/, Domain/, Data/, Presentation/, Shared/)
- [X] T004 [P] Configure Info.plist with LSUIElement=YES (menu bar only app)
- [X] T005 [P] Create OSLog subsystem constants in Liuli-Server/Shared/Utilities/Logger.swift
- [X] T006 [P] Create localization string catalogs (en.lproj, zh-Hans.lproj) in Liuli-Server/Resources/Localizations/
- [X] T006.5 [P] Configure macOS entitlements for SMAppService (Login Items) in Liuli-Server.entitlements

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Domain entities and repository protocols that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Domain Layer Foundation

- [ ] T007 [P] Create ServiceState enum in Liuli-Server/Domain/ValueObjects/ServiceState.swift
- [ ] T008 [P] Create ConnectionState enum in Liuli-Server/Domain/ValueObjects/ConnectionState.swift
- [ ] T009 [P] Create SOCKS5ErrorCode enum in Liuli-Server/Domain/ValueObjects/SOCKS5Error.swift
- [ ] T010 [P] Create CharlesProxyStatus enum in Liuli-Server/Domain/ValueObjects/CharlesProxyStatus.swift
- [ ] T011 [P] Create BridgeService entity struct (Sendable) in Liuli-Server/Domain/Entities/BridgeService.swift
- [ ] T012 [P] Create SOCKS5Connection entity struct (Sendable) in Liuli-Server/Domain/Entities/SOCKS5Connection.swift
- [ ] T013 [P] Create ConnectedDevice entity struct (Sendable) in Liuli-Server/Domain/Entities/ConnectedDevice.swift
- [ ] T014 [P] Create ProxyConfiguration entity struct (Sendable, Codable) in Liuli-Server/Domain/Entities/ProxyConfiguration.swift
- [ ] T015 [P] Create ConnectionStatistics entity struct (Sendable) in Liuli-Server/Domain/Entities/ConnectionStatistics.swift
- [ ] T016 [P] Create BridgeServiceError enum (domain errors) in Liuli-Server/Domain/ValueObjects/BridgeServiceError.swift

### Repository Protocols

- [ ] T017 [P] Create SOCKS5ServerRepository protocol in Liuli-Server/Domain/Protocols/SOCKS5ServerRepository.swift
- [ ] T018 [P] Create BonjourServiceRepository protocol in Liuli-Server/Domain/Protocols/BonjourServiceRepository.swift
- [ ] T019 [P] Create CharlesProxyRepository protocol in Liuli-Server/Domain/Protocols/CharlesProxyRepository.swift
- [ ] T020 [P] Create ConnectionRepository protocol in Liuli-Server/Domain/Protocols/ConnectionRepository.swift
- [ ] T021 [P] Create ConfigurationRepository protocol in Liuli-Server/Domain/Protocols/ConfigurationRepository.swift

### Shared Utilities

- [ ] T022 [P] Implement IPAddress+Validation extension (RFC 1918 + link-local checks) in Liuli-Server/Shared/Extensions/IPAddress+Validation.swift
- [ ] T023 [P] Implement ExponentialBackoff utility (1s/2s/4s retry logic) in Liuli-Server/Shared/Utilities/ExponentialBackoff.swift
- [ ] T024 [P] Implement Data+HexString extension (for SOCKS5 debug logging) in Liuli-Server/Shared/Extensions/Data+HexString.swift
- [ ] T025 [P] Implement String+Localized extension in Liuli-Server/Shared/Extensions/String+Localized.swift

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - One-Click Service Start from Menu Bar (Priority: P1) 🎯 MVP

**Goal**: Enable QA engineers to start/stop the bridge service from menu bar with visual feedback

**Independent Test**: Click menu bar icon → select "Start Service" → icon changes to green within 3 seconds → service accepts connections on port 9000

### Implementation for User Story 1

#### Domain Layer (Use Cases)

- [ ] T026 [P] [US1] Create StartServiceUseCase struct in Liuli-Server/Domain/UseCases/StartServiceUseCase.swift
- [ ] T027 [P] [US1] Create StopServiceUseCase struct in Liuli-Server/Domain/UseCases/StopServiceUseCase.swift
- [ ] T028 [P] [US1] Create DetectCharlesUseCase struct in Liuli-Server/Domain/UseCases/DetectCharlesUseCase.swift

#### Data Layer (Repositories)

- [ ] T029 [US1] Implement NIOSwiftSOCKS5ServerRepository actor in Liuli-Server/Data/Repositories/NIOSwiftSOCKS5ServerRepository.swift (SwiftNIO bootstrap, channel pipeline)
- [ ] T030 [US1] Implement SOCKS5Handler (channel handler for RFC 1928 handshake) in Liuli-Server/Data/NetworkServices/SOCKS5Handler.swift
- [ ] T031 [US1] Implement IPAddressValidationHandler (reject non-RFC 1918 IPs) in Liuli-Server/Data/NetworkServices/IPAddressValidator.swift
- [ ] T032 [P] [US1] Implement NetServiceBonjourRepository actor in Liuli-Server/Data/Repositories/NetServiceBonjourRepository.swift
- [ ] T033 [P] [US1] Implement ProcessCharlesRepository actor (NSWorkspace + TCP detection) in Liuli-Server/Data/Repositories/ProcessCharlesRepository.swift
- [ ] T034 [P] [US1] Implement UserDefaultsConfigRepository actor in Liuli-Server/Data/Repositories/UserDefaultsConfigRepository.swift

#### Presentation Layer (Menu Bar UI)

- [ ] T035 [US1] Create MenuBarViewState struct (Sendable) in Liuli-Server/Presentation/State/MenuBarViewState.swift
- [ ] T036 [US1] Create MenuBarViewAction enum (Sendable) in Liuli-Server/Presentation/State/MenuBarViewAction.swift
- [ ] T037 [US1] Create MenuBarViewModel (@MainActor @Observable) in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift
- [ ] T038 [US1] Create MenuBarView (SwiftUI) in Liuli-Server/Presentation/Views/MenuBarView.swift
- [ ] T039 [US1] Create ServiceStatusIndicator component (color-coded icon) in Liuli-Server/Presentation/Views/Components/ServiceStatusIndicator.swift

#### App Layer (Entry Point & DI)

- [ ] T040 [US1] Create Liuli_ServerApp.swift (@main, SwiftUI App lifecycle) in Liuli-Server/App/Liuli_ServerApp.swift
- [ ] T041 [US1] Create AppDelegate (NSApplicationDelegate for menu bar setup) in Liuli-Server/App/AppDelegate.swift
- [ ] T042 [US1] Create MenuBarCoordinator (manages NSStatusItem) in Liuli-Server/App/MenuBarCoordinator.swift
- [ ] T043 [US1] Create AppDependencyContainer (DI container with factory methods) in Liuli-Server/App/AppDependencyContainer.swift

#### Resources

- [ ] T044 [P] [US1] Add menu bar icon assets (gray/blue/green/yellow/red states) to Liuli-Server/Resources/Assets.xcassets/MenuBarIcon.imageset/

**Checkpoint**: At this point, User Story 1 should be fully functional - can start/stop service from menu bar

---

## Phase 4: User Story 2 - Automatic Discovery by iOS Devices (Priority: P1)

**Goal**: Enable iOS devices to automatically discover Mac Bridge via Bonjour/mDNS without manual IP entry

**Independent Test**: Start Mac Bridge service → open Liuli iOS app → Mac appears in server list within 5 seconds

### Implementation for User Story 2

- [ ] T045 [US2] Enhance NetServiceBonjourRepository with TXT record support (version, port, device model) in Liuli-Server/Data/Repositories/NetServiceBonjourRepository.swift
- [ ] T046 [US2] Add network interface change observer in Liuli-Server/Data/DataSources/NetworkReachability.swift
- [ ] T047 [US2] Update StartServiceUseCase to advertise Bonjour service after SOCKS5 server starts in Liuli-Server/Domain/UseCases/StartServiceUseCase.swift
- [ ] T048 [US2] Update StopServiceUseCase to unpublish Bonjour service in Liuli-Server/Domain/UseCases/StopServiceUseCase.swift
- [ ] T049 [US2] Update MenuBarViewModel to show "Service Running" notification when Bonjour advertised in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - iOS devices can discover and see Mac in server list

---

## Phase 5: User Story 3 - Seamless Traffic Forwarding to Charles (Priority: P1)

**Goal**: Forward all iOS app traffic to Charles Proxy automatically once iOS connects to Mac Bridge

**Independent Test**: Connect iOS to Mac Bridge → browse Safari → all requests appear in Charles within 10 seconds

### Implementation for User Story 3

#### Domain Layer

- [ ] T050 [P] [US3] Create ForwardConnectionUseCase struct in Liuli-Server/Domain/UseCases/ForwardConnectionUseCase.swift

#### Data Layer (Traffic Forwarding)

- [ ] T051 [US3] Implement CharlesForwardingHandler (HTTP CONNECT tunneling) in Liuli-Server/Data/NetworkServices/CharlesForwardingHandler.swift
- [ ] T052 [US3] Implement ConnectionTracker (byte counting, idle timeout) in Liuli-Server/Data/NetworkServices/ConnectionTracker.swift
- [ ] T053 [US3] Implement InMemoryConnectionRepository actor in Liuli-Server/Data/Repositories/InMemoryConnectionRepository.swift
- [ ] T054 [US3] Add CharlesForwardingHandler to SOCKS5 server pipeline after handshake in Liuli-Server/Data/NetworkServices/SOCKS5Handler.swift
- [ ] T055 [US3] Implement DNS resolution for domain names (return 0x04 on failure) in SOCKS5Handler in Liuli-Server/Data/NetworkServices/SOCKS5Handler.swift
- [ ] T056 [US3] Add 60-second idle timeout using SwiftNIO IdleStateHandler in Liuli-Server/Data/NetworkServices/ConnectionTracker.swift

#### Integration

- [ ] T057 [US3] Update StartServiceUseCase to initialize Charles detection and connection tracking in Liuli-Server/Domain/UseCases/StartServiceUseCase.swift
- [ ] T058 [US3] Implement exponential backoff retry (1s/2s/4s) when Charles unreachable in Liuli-Server/Data/Repositories/ProcessCharlesRepository.swift
- [ ] T059 [US3] Update MenuBarViewModel to show warning notification if Charles not detected at startup in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift
- [ ] T059.5 [US3] Implement fault isolation for connection failures (FR-049) - ensure single connection failure doesn't crash service in Liuli-Server/Data/NetworkServices/SOCKS5Handler.swift

**Checkpoint**: All three P1 user stories complete - full MVP functionality (start/discover/forward) working

---

## Phase 6: User Story 4 - Real-Time Connection Monitoring (Priority: P2)

**Goal**: Display active iOS connections and traffic statistics in real-time

**Independent Test**: Open Statistics window → see 2 connected iOS devices with byte counters updating every 1 second

### Implementation for User Story 4

#### Domain Layer

- [ ] T060 [P] [US4] Create TrackStatisticsUseCase struct in Liuli-Server/Domain/UseCases/TrackStatisticsUseCase.swift

#### Presentation Layer (Statistics Window)

- [ ] T061 [P] [US4] Create StatisticsViewState struct (Sendable) in Liuli-Server/Presentation/State/StatisticsViewState.swift
- [ ] T062 [P] [US4] Create StatisticsViewModel (@MainActor @Observable) in Liuli-Server/Presentation/ViewModels/StatisticsViewModel.swift
- [ ] T063 [US4] Create StatisticsView (SwiftUI window) in Liuli-Server/Presentation/Views/StatisticsView.swift
- [ ] T064 [P] [US4] Create ConnectionRow component (single connection display) in Liuli-Server/Presentation/Views/Components/ConnectionRow.swift

#### Integration

- [ ] T065 [US4] Add "View Statistics" menu item to MenuBarView in Liuli-Server/Presentation/Views/MenuBarView.swift
- [ ] T066 [US4] Update ConnectionTracker to publish byte count updates via AsyncStream in Liuli-Server/Data/NetworkServices/ConnectionTracker.swift
- [ ] T067 [US4] Update StatisticsViewModel to subscribe to connection updates (1-second refresh) in Liuli-Server/Presentation/ViewModels/StatisticsViewModel.swift
- [ ] T068 [US4] Update InMemoryConnectionRepository to maintain last 50 historical connections in Liuli-Server/Data/Repositories/InMemoryConnectionRepository.swift

**Checkpoint**: User Story 4 complete - Statistics window shows real-time connection monitoring

---

## Phase 7: User Story 5 - Persistent Configuration (Priority: P3)

**Goal**: Remember user preferences (SOCKS5 port, Charles address, auto-start) across app launches

**Independent Test**: Change port to 9001 → quit app → relaunch → verify port still 9001

### Implementation for User Story 5

#### Domain Layer

- [ ] T069 [P] [US5] Create ManageConfigurationUseCase struct in Liuli-Server/Domain/UseCases/ManageConfigurationUseCase.swift

#### Presentation Layer (Preferences Window)

- [ ] T070 [P] [US5] Create PreferencesViewState struct (Sendable) in Liuli-Server/Presentation/State/PreferencesViewState.swift
- [ ] T071 [P] [US5] Create PreferencesViewModel (@MainActor @Observable) in Liuli-Server/Presentation/ViewModels/PreferencesViewModel.swift
- [ ] T072 [US5] Create PreferencesView (SwiftUI Settings scene) in Liuli-Server/Presentation/Views/PreferencesView.swift

#### Integration

- [ ] T073 [US5] Update UserDefaultsConfigRepository to validate port range (1024-65535) and IP addresses in Liuli-Server/Data/Repositories/UserDefaultsConfigRepository.swift
- [ ] T074 [US5] Update MenuBarViewModel to load saved configuration on startup in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift
- [ ] T075 [US5] Implement SMAppService API for "Auto-start on login" in Liuli-Server/App/AppDelegate.swift
- [ ] T076 [US5] Add "Auto-launch Charles" logic to StartServiceUseCase in Liuli-Server/Domain/UseCases/StartServiceUseCase.swift

**Checkpoint**: User Story 5 complete - Preferences persist across app restarts

---

## Phase 8: User Story 6 - Quick Access to Charles Proxy (Priority: P3)

**Goal**: Launch or bring Charles Proxy to foreground from Mac Bridge menu

**Independent Test**: Click "Open Charles Proxy" → Charles launches if not running, or comes to foreground if already open

### Implementation for User Story 6

- [ ] T077 [US6] Add launchCharles() method to ProcessCharlesRepository using NSWorkspace in Liuli-Server/Data/Repositories/ProcessCharlesRepository.swift
- [ ] T078 [US6] Add activate() method to ProcessCharlesRepository to bring Charles to foreground in Liuli-Server/Data/Repositories/ProcessCharlesRepository.swift
- [ ] T079 [US6] Add getInstallationPath() method to detect if Charles is installed in Liuli-Server/Data/Repositories/ProcessCharlesRepository.swift
- [ ] T080 [US6] Add "Open Charles Proxy" menu item to MenuBarView in Liuli-Server/Presentation/Views/MenuBarView.swift
- [ ] T081 [US6] Update MenuBarViewModel to handle "openCharles" action in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift
- [ ] T082 [US6] Show error notification if Charles not found (with download link) in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift

**Checkpoint**: All 6 user stories complete - Full feature set implemented

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T083 [P] Add Chinese localizations for all user-facing strings in Liuli-Server/Resources/Localizations/zh-Hans.lproj/Localizable.xcstrings
- [ ] T084 [P] Implement error handling for edge cases (rapid start/stop, memory limits, corrupted UserDefaults) across all Use Cases
- [ ] T084.5 [P] Create ErrorAlertView component with contextual action buttons (FR-047) in Liuli-Server/Presentation/Views/Components/ErrorAlertView.swift
- [ ] T084.6 Update MenuBarViewModel to use ErrorAlertView for FR-046/FR-047 error scenarios in Liuli-Server/Presentation/ViewModels/MenuBarViewModel.swift
- [ ] T085 [P] Add OSLog structured logging for all connection events in ConnectionTracker in Liuli-Server/Data/NetworkServices/ConnectionTracker.swift
- [ ] T086 [P] Implement network interface change handling (Wi-Fi ↔ Ethernet) in NetServiceBonjourRepository in Liuli-Server/Data/Repositories/NetServiceBonjourRepository.swift
- [ ] T087 [P] Add connection limit enforcement (max 100 concurrent) in SOCKS5Handler in Liuli-Server/Data/NetworkServices/SOCKS5Handler.swift
- [ ] T088 Verify Swift 6.0 strict concurrency compliance (zero warnings) across all files
- [ ] T089 Verify all architecture gates pass (dependency direction, no SwiftData leaks, constructor injection)
- [ ] T090 Run manual validation using acceptance scenarios from spec.md for all 6 user stories
- [ ] T091 [P] Performance profiling: verify < 5ms forwarding latency and < 50MB memory with 10 connections
- [ ] T092 [P] Create README.md with quickstart guide and build instructions

---

## Phase 10: Testing (Constitution Compliance)

**Purpose**: Achieve constitution-mandated test coverage targets

**⚠️ CONSTITUTION REQUIREMENT**: This phase is MANDATORY per constitution.md test coverage gates

### Domain Layer Tests (Target: 100% branch coverage)

- [ ] T093 [P] [Testing] Create StartServiceUseCaseTests in Liuli-ServerTests/Domain/UseCases/StartServiceUseCaseTests.swift
- [ ] T094 [P] [Testing] Create StopServiceUseCaseTests in Liuli-ServerTests/Domain/UseCases/StopServiceUseCaseTests.swift
- [ ] T095 [P] [Testing] Create ForwardConnectionUseCaseTests in Liuli-ServerTests/Domain/UseCases/ForwardConnectionUseCaseTests.swift
- [ ] T096 [P] [Testing] Create DetectCharlesUseCaseTests in Liuli-ServerTests/Domain/UseCases/DetectCharlesUseCaseTests.swift
- [ ] T097 [P] [Testing] Create TrackStatisticsUseCaseTests in Liuli-ServerTests/Domain/UseCases/TrackStatisticsUseCaseTests.swift
- [ ] T098 [P] [Testing] Create ManageConfigurationUseCaseTests in Liuli-ServerTests/Domain/UseCases/ManageConfigurationUseCaseTests.swift

### Data Layer Tests (Target: 90% path coverage)

- [ ] T099 [P] [Testing] Create NIOSwiftSOCKS5ServerRepositoryTests in Liuli-ServerTests/Data/Repositories/NIOSwiftSOCKS5ServerRepositoryTests.swift
- [ ] T100 [P] [Testing] Create NetServiceBonjourRepositoryTests in Liuli-ServerTests/Data/Repositories/NetServiceBonjourRepositoryTests.swift
- [ ] T101 [P] [Testing] Create ProcessCharlesRepositoryTests in Liuli-ServerTests/Data/Repositories/ProcessCharlesRepositoryTests.swift
- [ ] T102 [P] [Testing] Create InMemoryConnectionRepositoryTests in Liuli-ServerTests/Data/Repositories/InMemoryConnectionRepositoryTests.swift
- [ ] T103 [P] [Testing] Create UserDefaultsConfigRepositoryTests in Liuli-ServerTests/Data/Repositories/UserDefaultsConfigRepositoryTests.swift
- [ ] T104 [P] [Testing] Create SOCKS5HandlerTests (SwiftNIO channel handler tests) in Liuli-ServerTests/Data/NetworkServices/SOCKS5HandlerTests.swift
- [ ] T105 [P] [Testing] Create CharlesForwardingHandlerTests in Liuli-ServerTests/Data/NetworkServices/CharlesForwardingHandlerTests.swift
- [ ] T106 [P] [Testing] Create IPAddressValidatorTests (RFC 1918 validation) in Liuli-ServerTests/Data/NetworkServices/IPAddressValidatorTests.swift

### Presentation Layer Tests (Target: 90% statement coverage)

- [ ] T107 [P] [Testing] Create MenuBarViewModelTests in Liuli-ServerTests/Presentation/ViewModels/MenuBarViewModelTests.swift
- [ ] T108 [P] [Testing] Create StatisticsViewModelTests in Liuli-ServerTests/Presentation/ViewModels/StatisticsViewModelTests.swift
- [ ] T109 [P] [Testing] Create PreferencesViewModelTests in Liuli-ServerTests/Presentation/ViewModels/PreferencesViewModelTests.swift

### View Layer Tests (Target: 70% coverage)

- [ ] T110 [P] [Testing] Create MenuBarViewTests (SwiftUI snapshot/interaction tests) in Liuli-ServerTests/Presentation/Views/MenuBarViewTests.swift
- [ ] T111 [P] [Testing] Create StatisticsViewTests in Liuli-ServerTests/Presentation/Views/StatisticsViewTests.swift
- [ ] T112 [P] [Testing] Create PreferencesViewTests in Liuli-ServerTests/Presentation/Views/PreferencesViewTests.swift

### Mock Infrastructure

- [ ] T113 [P] [Testing] Create MockSOCKS5ServerRepository in Liuli-ServerTests/Mocks/MockSOCKS5ServerRepository.swift
- [ ] T114 [P] [Testing] Create MockBonjourServiceRepository in Liuli-ServerTests/Mocks/MockBonjourServiceRepository.swift
- [ ] T115 [P] [Testing] Create MockCharlesProxyRepository in Liuli-ServerTests/Mocks/MockCharlesProxyRepository.swift
- [ ] T116 [P] [Testing] Create MockConnectionRepository in Liuli-ServerTests/Mocks/MockConnectionRepository.swift
- [ ] T117 [P] [Testing] Create MockConfigurationRepository in Liuli-ServerTests/Mocks/MockConfigurationRepository.swift

### Coverage Verification

- [ ] T118 [Testing] Run xcodebuild test with coverage enabled and generate coverage report
- [ ] T119 [Testing] Verify Domain coverage ≥100% using Xcode coverage report
- [ ] T120 [Testing] Verify Data coverage ≥90% using Xcode coverage report
- [ ] T121 [Testing] Verify Presentation coverage ≥90% using Xcode coverage report
- [ ] T122 [Testing] Verify Views coverage ≥70% using Xcode coverage report

**Checkpoint**: All constitution test coverage gates met - ready for production

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) - MVP FIRST
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) - Can start after US1 or in parallel
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) and US1 (SOCKS5 server) - Extends US1
- **User Story 4 (Phase 6)**: Depends on US3 (connection tracking) - Builds on forwarding
- **User Story 5 (Phase 7)**: Depends on US1 (configuration loading) - Independent of US2/US3/US4
- **User Story 6 (Phase 8)**: Depends on US1 (menu bar) - Independent of US2/US3/US4/US5
- **Polish (Phase 9)**: Depends on all desired user stories being complete
- **Testing (Phase 10)**: Can run in parallel with implementation or after Polish - MANDATORY before production

### User Story Dependencies

```
Setup (Phase 1) → Foundational (Phase 2) → User Stories
                                             ↓
                                          US1 (P1) - Core service start/stop
                                          /  |  \
                                         /   |   \
                                      US2   US3  US5  (US2/US5 can be parallel)
                                      (P1)  (P1) (P3)
                                        \    |
                                         \   ↓
                                          US4 (P2) - Depends on US3 (traffic tracking)

                                      US6 (P3) - Independent, only needs US1 menu bar
```

**Critical Path**: Setup → Foundational → US1 → US3 → US4

**Independent Paths**:
- US2 (Bonjour) can develop in parallel with US3 (forwarding)
- US5 (preferences) can develop in parallel with US2/US3
- US6 (launch Charles) can develop in parallel with any story after US1

### Within Each User Story

- Domain layer (Use Cases) before Data layer (Repositories)
- Data layer (Repositories) before Presentation layer (ViewModels)
- ViewModels before Views
- Core implementation before integration tasks
- Story complete before moving to next priority

### Parallel Opportunities

#### Setup Phase (6 tasks can run in parallel)
- T003, T004, T005, T006 all marked [P]

#### Foundational Phase (21 tasks can run in parallel)
- All Domain entities (T007-T015): 9 parallel tasks
- All protocols (T017-T021): 5 parallel tasks
- All utilities (T022-T025): 4 parallel tasks

#### User Story 1 (5 parallel opportunities)
- T026, T027, T028 (Use Cases) can run in parallel
- T032, T033, T034 (Repositories) can run in parallel
- T044 (Assets) can run in parallel with other tasks

#### Cross-Story Parallelism
If team has capacity:
- US2 and US5 can develop in parallel after US1
- US6 can develop in parallel with US4

---

## Parallel Example: User Story 1

```bash
# After Foundational phase completes, launch in parallel:

# Use Cases (no dependencies between them):
Task T026: "Create StartServiceUseCase struct"
Task T027: "Create StopServiceUseCase struct"
Task T028: "Create DetectCharlesUseCase struct"

# Independent Repositories (different files):
Task T032: "Implement NetServiceBonjourRepository actor"
Task T033: "Implement ProcessCharlesRepository actor"
Task T034: "Implement UserDefaultsConfigRepository actor"

# Assets (non-code):
Task T044: "Add menu bar icon assets"
```

---

## Implementation Strategy

### MVP First (User Stories 1-3 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Start/Stop service)
4. **STOP and VALIDATE**: Test US1 independently with acceptance scenarios
5. Complete Phase 4: User Story 2 (Bonjour discovery)
6. **STOP and VALIDATE**: Test US2 independently with iOS device
7. Complete Phase 5: User Story 3 (Traffic forwarding)
8. **STOP and VALIDATE**: Test US3 independently with Charles
9. Deploy/demo MVP (all P1 stories complete)

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (T001-T025)
2. Add User Story 1 → Test independently → MVP Checkpoint (T026-T044)
3. Add User Story 2 → Test independently → iOS Discovery working (T045-T049)
4. Add User Story 3 → Test independently → Full forwarding working (T050-T059)
5. Add User Story 4 → Test independently → Statistics available (T060-T068)
6. Add User Story 5 → Test independently → Preferences working (T069-T076)
7. Add User Story 6 → Test independently → Charles integration complete (T077-T082)
8. Polish → Final quality pass (T083-T092)

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T025)
2. Once Foundational done, split:
   - **Developer A**: User Story 1 (T026-T044) - PRIORITY
   - **Developer B**: Wait for US1, then US2 (T045-T049)
   - **Developer C**: Wait for US1, then US5 (T069-T076)
3. After US1 complete:
   - **Developer A**: User Story 3 (T050-T059) - Extends US1
   - **Developer B**: User Story 2 (T045-T049) - Parallel
   - **Developer C**: User Story 5 (T069-T076) - Parallel
4. After US3 complete:
   - **Developer A**: User Story 4 (T060-T068) - Depends on US3
   - **Developer B**: User Story 6 (T077-T082) - Independent
5. Polish together (T083-T092)

---

## Summary

- **Total Tasks**: 126 (updated from 92)
- **Setup Phase**: 7 tasks (added T006.5 entitlements)
- **Foundational Phase**: 19 tasks (BLOCKING)
- **User Story 1 (P1 MVP)**: 19 tasks
- **User Story 2 (P1)**: 5 tasks
- **User Story 3 (P1)**: 11 tasks (added T059.5 fault isolation)
- **User Story 4 (P2)**: 9 tasks
- **User Story 5 (P3)**: 8 tasks
- **User Story 6 (P3)**: 6 tasks
- **Polish Phase**: 12 tasks (added T084.5, T084.6 error dialogs)
- **Testing Phase (MANDATORY)**: 30 tasks (T093-T122)

**Parallel Opportunities**: 67 tasks marked [P] can run in parallel within their phases

**MVP Scope (Suggested)**: Phase 1-5 + Phase 10 Testing = 65 implementation + 30 testing = 95 tasks (all P1 stories with tests)

**Critical Path**: Setup (7) → Foundational (19) → US1 (19) → US3 (11) → Testing (30) = 86 tasks minimum for constitution-compliant MVP

---

## Notes

- [P] tasks = different files, no dependencies within phase
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently using acceptance scenarios from spec.md
- Swift 6.0 strict concurrency enforced - all tasks must maintain Sendable conformance and actor isolation
- Tests are MANDATORY per constitution.md - Phase 10 must achieve coverage targets before production
- Avoid: same file conflicts, cross-story dependencies that break independence
