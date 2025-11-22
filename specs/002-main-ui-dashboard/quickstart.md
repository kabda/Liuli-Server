# Quickstart Guide: UI Dashboard Implementation

**Feature**: Main UI Dashboard and Menu Bar Interface
**Target Audience**: Developers implementing this feature
**Prerequisites**: Xcode 15+, macOS 14+ SDK, familiarity with SwiftUI and Clean MVVM

---

## Implementation Order

Follow this sequence to build the feature incrementally with working milestones:

### Phase 1: Domain Foundation (P1 - Core Entities)
**Goal**: Define all domain entities and repository protocols

1. **Create Domain Entities** (`Domain/Entities/`)
   - `DeviceConnection.swift`
   - `NetworkStatus.swift`
   - `CharlesStatus.swift`
   - `ApplicationSettings.swift`

2. **Create Repository Protocols** (`Domain/Protocols/`)
   - `DeviceMonitorRepository.swift`
   - `NetworkStatusRepository.swift`
   - `CharlesProxyRepository.swift`
   - `SettingsRepository.swift`

3. **Verify**:
   ```bash
   xcodebuild -project Liuli-Server.xcodeproj \
              -scheme Liuli-Server \
              -sdk macosx \
              build
   ```
   - Zero compiler warnings
   - All entities conform to `Sendable`

---

### Phase 2: Data Layer (P1 - Repository Implementations)
**Goal**: Implement repositories with in-memory or persistence backends

1. **Implement Repositories** (`Data/Repositories/`)
   - `DeviceMonitorRepositoryImpl.swift` (in-memory AsyncStream)
   - `NetworkStatusRepositoryImpl.swift` (bridge integration)
   - `CharlesProxyRepositoryImpl.swift` (HTTP CONNECT probe)
   - `SettingsRepositoryImpl.swift` (UserDefaults + crash detection)

2. **Write Unit Tests** (`Tests/Data/Repositories/`)
   - Test AsyncStream emission
   - Test crash detection logic (clean vs abnormal shutdown)
   - Test Charles probe (mock URLSession)

3. **Verify**:
   ```bash
   xcodebuild test \
              -project Liuli-Server.xcodeproj \
              -scheme Liuli-Server \
              -destination 'platform=macOS'
   ```
   - All repository tests pass
   - Coverage ≥ 90% for Data layer

---

### Phase 3: Domain Use Cases (P1 - Business Logic)
**Goal**: Wire domain logic connecting repositories to presentation

1. **Create Use Cases** (`Domain/UseCases/`)
   - `MonitorDeviceConnectionsUseCase.swift`
   - `MonitorNetworkStatusUseCase.swift`
   - `CheckCharlesAvailabilityUseCase.swift`
   - `ToggleBridgeUseCase.swift`
   - `ManageSettingsUseCase.swift`

2. **Write Unit Tests** (`Tests/Domain/UseCases/`)
   - Mock repositories via protocols
   - Test use case logic (e.g., bridge toggle with active connections)

3. **Verify**:
   - Coverage ≥ 100% for Domain use cases
   - Zero data race warnings

---

### Phase 4: Presentation - Dashboard (P1 Story 1)
**Goal**: Build main window UI with device list

1. **Create ViewModels** (`Presentation/ViewModels/`)
   - `DashboardViewModel.swift` (with `DashboardState`, `DashboardAction`)
   - `DeviceListViewModel.swift` (if needed for sub-components)
   - `StatusPanelViewModel.swift`

2. **Create Views** (`Presentation/Views/`)
   - `DashboardView.swift` (main window container)
   - `DeviceListView.swift` (Table with columns: Name, Connected At, Status, Traffic)
   - `StatusPanelView.swift` (Network + Charles status indicators)
   - `Components/StatusIndicatorView.swift` (reusable status badge)
   - `Components/DeviceRowView.swift` (table row)

3. **Update App Entry** (`App/Liuli_ServerApp.swift`)
   - Add DashboardView as primary window
   - Integrate with `.menuBarExtra()` for menu bar icon

4. **Update DI Container** (`App/DependencyContainer.swift`)
   - Register all repositories
   - Register all use cases
   - Provide ViewModels with injected dependencies

5. **Test Manually**:
   - Launch app → menu bar icon appears
   - Click icon → menu opens (basic version)
   - Open main window → device list shows (empty state)
   - Verify auto-update (mock device connection)

6. **Write UI Tests** (`Tests/Presentation/Views/`)
   - Test empty state message
   - Test device list rendering with mock data
   - Test status indicator colors

**Acceptance**: User Story 1 (P1) complete ✅

---

### Phase 5: Presentation - Status Monitoring (P1 Story 2)
**Goal**: Display network and Charles status with real-time updates

1. **Enhance StatusPanelView**:
   - Network status section (listening/inactive, port number)
   - Charles status section (available/unavailable, configured address)
   - Real-time polling (5s interval for Charles)

2. **Add Status Icons** (`Resources/Assets.xcassets/`)
   - Green/gray/red dots for status indicators
   - Network icon (SF Symbol: network)
   - Charles icon (SF Symbol: arrow.left.arrow.right or custom)

3. **Test**:
   - Start/stop bridge → status updates within 1s
   - Start/stop Charles → status updates within 3s (per FR-013)
   - Hover over status → show tooltip with details

**Acceptance**: User Story 2 (P1) complete ✅

---

### Phase 6: Presentation - Menu Bar Control (P2 Story 3)
**Goal**: Add bridge toggle and quick actions to menu bar

1. **Create MenuBarViewModel** (`Presentation/ViewModels/MenuBarViewModel.swift`)
   - Bridge toggle state
   - Active connection count
   - Actions: toggle bridge, open window, quit

2. **Create MenuBarView** (`Presentation/Views/MenuBarView.swift`)
   - Toggle switch (ON/OFF)
   - Connection count label
   - "Show Main Window" button
   - "Settings..." button
   - Divider
   - "Quit" button

3. **Update App Entry**:
   ```swift
   @main
   struct Liuli_ServerApp: App {
       @State private var menuBarVM: MenuBarViewModel

       var body: some Scene {
           MenuBarExtra {
               MenuBarView(viewModel: menuBarVM)
           } label: {
               Image(systemName: menuBarVM.iconName)
           }

           Window("Dashboard", id: "dashboard") {
               DashboardView(viewModel: dashboardVM)
           }
           .defaultSize(width: 800, height: 600)
       }
   }
   ```

4. **Test**:
   - Toggle bridge from menu bar → state persists
   - Disable bridge with active connections → graceful degradation (FR-011)
   - Menu opens in <0.5s (SC-007)

**Acceptance**: User Story 3 (P2) complete ✅

---

### Phase 7: Presentation - Settings Window (P3 Story 4)
**Goal**: Configure Charles proxy and app preferences

1. **Create SettingsViewModel** (`Presentation/ViewModels/SettingsViewModel.swift`)
   - Load/save settings
   - Track dirty state (unsaved changes)

2. **Create SettingsView** (`Presentation/Views/SettingsView.swift`)
   ```swift
   struct SettingsView: View {
       @ObservedObject var viewModel: SettingsViewModel

       var body: some View {
           Form {
               Section("Charles Proxy") {
                   TextField("Host", text: $viewModel.state.settings.charlesProxyHost)
                   TextField("Port", value: $viewModel.state.settings.charlesProxyPort, format: .number)
               }

               Section("Behavior") {
                   Toggle("Auto-start bridge on launch", isOn: $viewModel.state.settings.autoStartBridge)
               }

               HStack {
                   Spacer()
                   Button("Cancel") { /* dismiss */ }
                   Button("Save") { viewModel.send(.save) }
                       .disabled(!viewModel.state.isDirty)
               }
           }
           .formStyle(.grouped)
           .frame(width: 500, height: 400)
       }
   }
   ```

3. **Add Settings Window** (App entry):
   ```swift
   Settings {
       SettingsView(viewModel: settingsVM)
   }
   ```

4. **Test**:
   - Change Charles port → save → restart app → setting persists
   - Invalid port (0, 100000) → validation error

**Acceptance**: User Story 4 (P3) complete ✅

---

## Development Workflow

### Daily Workflow
1. Pull latest from `main` branch
2. Checkout feature branch: `git checkout 002-main-ui-dashboard`
3. Run tests: `xcodebuild test ...`
4. Implement next phase from list above
5. Write unit tests for new code
6. Run tests again → ensure passing
7. Commit with descriptive message
8. Push to remote

### Testing Strategy
- **Unit Tests**: All ViewModels, Use Cases, Repositories
- **Integration Tests**: End-to-end flows (e.g., toggle bridge → verify state)
- **UI Tests**: Critical user interactions (open window, toggle bridge, save settings)
- **Manual Testing**: Visual verification, edge cases (10+ devices, crash recovery)

### Code Review Checklist
Before submitting PR, verify:
- [ ] All tests pass
- [ ] Coverage meets targets (Domain 100%, Data 90%, Presentation 90%, Views 70%)
- [ ] Zero Swift compiler warnings
- [ ] Zero concurrency warnings
- [ ] All ViewModels use constructor injection
- [ ] No `@unchecked Sendable` without justification
- [ ] All async code uses async/await (no DispatchQueue)
- [ ] User stories validated (manual test against acceptance scenarios)

---

## Common Patterns

### Pattern 1: ViewModel with AsyncStream Subscription

```swift
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var state = DashboardState()

    private let monitorDevicesUseCase: MonitorDeviceConnectionsUseCase
    private var updateTask: Task<Void, Never>?

    init(monitorDevicesUseCase: MonitorDeviceConnectionsUseCase) {
        self.monitorDevicesUseCase = monitorDevicesUseCase
    }

    func send(_ action: DashboardAction) {
        switch action {
        case .onAppear:
            startMonitoring()
        case .onDisappear:
            stopMonitoring()
        case .refresh:
            // Trigger manual refresh
            break
        }
    }

    private func startMonitoring() {
        updateTask = Task {
            for await devices in monitorDevicesUseCase.execute() {
                state.devices = devices
            }
        }
    }

    private func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }
}
```

### Pattern 2: Repository with AsyncStream

```swift
actor DeviceMonitorRepositoryImpl: DeviceMonitorRepository {
    private var connections: [UUID: DeviceConnection] = [:]
    private var continuation: AsyncStream<[DeviceConnection]>.Continuation?

    func observeConnections() -> AsyncStream<[DeviceConnection]> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(Array(connections.values))
        }
    }

    func addConnection(_ device: DeviceConnection) async {
        connections[device.id] = device
        emitUpdate()
    }

    func removeConnection(_ deviceId: UUID) async {
        connections.removeValue(forKey: deviceId)
        emitUpdate()
    }

    private func emitUpdate() {
        continuation?.yield(Array(connections.values))
    }
}
```

### Pattern 3: Use Case (Pass-Through)

```swift
public struct MonitorDeviceConnectionsUseCase: Sendable {
    private let repository: DeviceMonitorRepository

    public init(repository: DeviceMonitorRepository) {
        self.repository = repository
    }

    public func execute() -> AsyncStream<[DeviceConnection]> {
        repository.observeConnections()
    }
}
```

### Pattern 4: DI Container Setup

```swift
// App/DependencyContainer.swift
@MainActor
final class DependencyContainer {
    // Repositories (singleton actors)
    private let deviceMonitorRepo = DeviceMonitorRepositoryImpl()
    private let networkStatusRepo = NetworkStatusRepositoryImpl()
    private let charlesProxyRepo = CharlesProxyRepositoryImpl()
    private let settingsRepo = SettingsRepositoryImpl()

    // Use Cases (stateless, created on-demand)
    func makeMonitorDevicesUseCase() -> MonitorDeviceConnectionsUseCase {
        MonitorDeviceConnectionsUseCase(repository: deviceMonitorRepo)
    }

    func makeToggleBridgeUseCase() -> ToggleBridgeUseCase {
        ToggleBridgeUseCase(repository: networkStatusRepo)
    }

    // ViewModels (created per view lifecycle)
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            monitorDevicesUseCase: makeMonitorDevicesUseCase(),
            monitorNetworkUseCase: makeMonitorNetworkStatusUseCase(),
            checkCharlesUseCase: makeCheckCharlesAvailabilityUseCase()
        )
    }
}
```

---

## Debugging Tips

### Issue: Status not updating
**Symptom**: UI shows stale data, no real-time updates

**Diagnosis**:
1. Check AsyncStream continuation is set: `print("Continuation: \(continuation != nil)")`
2. Verify Task is running: Add `print()` in `for await` loop
3. Check Task cancellation: Ensure `updateTask?.cancel()` not called prematurely

**Solution**: Ensure `startMonitoring()` called on `.onAppear` and Task lifecycle correct

---

### Issue: Data race warnings
**Symptom**: Swift concurrency warnings in console

**Diagnosis**:
1. Run with Thread Sanitizer enabled (Edit Scheme → Diagnostics → Thread Sanitizer)
2. Check entity `Sendable` conformance
3. Verify repository is `actor`
4. Verify ViewModel is `@MainActor`

**Solution**: Add `Sendable` conformance, use `actor` for shared mutable state, use `@MainActor` for UI updates

---

### Issue: Menu bar icon not appearing
**Symptom**: App launches but no menu bar icon

**Diagnosis**:
1. Check `.menuBarExtra()` is in `App` body
2. Verify icon name is valid SF Symbol: `Image(systemName: "network")`
3. Check macOS permissions (System Settings → Privacy & Security → Accessibility)

**Solution**: Use valid SF Symbol, ensure `.menuBarExtra()` at root Scene level

---

### Issue: Charles availability checking always unavailable
**Symptom**: Status shows "Unavailable" even when Charles running

**Diagnosis**:
1. Check Charles is listening on configured port: `lsof -i :8888`
2. Test CONNECT manually: `curl -X CONNECT http://localhost:8888`
3. Check timeout (2s may be too short if network slow)
4. Add debug logging in `CharlesProxyRepositoryImpl.checkAvailability()`

**Solution**: Increase timeout, verify Charles proxy settings (Proxy → Proxy Settings → Port)

---

## Performance Optimization

### Memory Management
- **AsyncStream cleanup**: Always cancel Tasks on view disappear
- **Device list**: Limit to 50 devices max (add pagination if needed)
- **Image caching**: Use `Image(systemName:)` (cached by system)

### UI Responsiveness
- **Debounce updates**: If status updates too frequently, add 100ms debounce
- **List virtualization**: SwiftUI List auto-virtualizes (use `id:` for stability)
- **Avoid heavy computations**: Move formatting to background (e.g., byte count formatting)

### Network Efficiency
- **Charles polling**: Use 5-10s interval (configurable in settings)
- **Timeout**: 2s for CONNECT probe (balance speed vs reliability)

---

## Testing Scenarios

### Manual Test Cases

**Test Case 1: Empty State**
1. Launch app (no devices connected)
2. Open main window from menu bar
3. Verify "No devices connected" message
4. Verify network status shows "Inactive"
5. Verify Charles status shows "Unknown" or "Unavailable"

**Test Case 2: Device Connection**
1. Connect iOS device via Liuli-iOS
2. Verify device appears in list within 1s
3. Verify device name, timestamp, status shown
4. Transfer some traffic
5. Verify byte counts update

**Test Case 3: Bridge Toggle**
1. Enable bridge from menu bar
2. Verify status changes to "Active"
3. Connect device → verify accepted
4. Disable bridge (with active connection)
5. Verify existing connection remains active
6. Try new connection → verify rejected

**Test Case 4: Crash Recovery**
1. Enable bridge
2. Force quit app (Cmd+Opt+Esc)
3. Relaunch app
4. Verify bridge is disabled (FR-012)

**Test Case 5: Settings Persistence**
1. Open Settings
2. Change Charles port to 9999
3. Save and quit app
4. Relaunch app
5. Verify Charles availability checking uses port 9999

---

## Troubleshooting

### Build Errors

**Error**: `Cannot find type 'DeviceConnection' in scope`
**Solution**: Ensure Domain entities are `public`, check file target membership

**Error**: `Actor-isolated property 'state' cannot be referenced from a non-isolated context`
**Solution**: Mark ViewModel with `@MainActor`, ensure called from main actor context

**Error**: `Type 'DeviceConnection' does not conform to protocol 'Sendable'`
**Solution**: Add `Sendable` conformance to all entities, ensure all fields are `Sendable`

### Runtime Errors

**Error**: App crashes on launch with EXC_BAD_ACCESS
**Solution**: Check for retain cycles, ensure weak/unowned references in closures

**Error**: Status indicators show wrong colors
**Solution**: Verify SF Symbol names, check `renderingMode(.template)` for dynamic colors

---

## Resources

### Apple Documentation
- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [@Observable](https://developer.apple.com/documentation/observation/observable())
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Project Documentation
- [spec.md](./spec.md) - Feature specification
- [research.md](./research.md) - Technical decisions
- [data-model.md](./data-model.md) - Entity definitions
- [constitution.md](../../.specify/memory/constitution.md) - Architecture rules

### Xcode Commands
```bash
# Build
xcodebuild -project Liuli-Server.xcodeproj -scheme Liuli-Server build

# Test
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -destination 'platform=macOS'

# Test with coverage
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -enableCodeCoverage YES

# Run app
open /path/to/Liuli-Server.app
```

---

## Acceptance Checklist

Before marking feature complete:

- [ ] All 4 user stories (P1, P2, P3) validated against acceptance scenarios
- [ ] All FR-001 to FR-017 implemented
- [ ] All SC-001 to SC-007 verified (performance targets)
- [ ] Test coverage: Domain ≥100%, Data ≥90%, Presentation ≥90%, Views ≥70%
- [ ] Zero compiler warnings
- [ ] Zero concurrency warnings
- [ ] Manual testing: 10+ devices, crash recovery, settings persistence
- [ ] Code review checklist passed
- [ ] Documentation updated (if needed)

---

## Next Steps

After completing this feature:
1. Create PR from `002-main-ui-dashboard` to `main`
2. Request code review
3. Address feedback
4. Merge to `main`
5. Tag release: `git tag -a v0.2.0 -m "Add UI dashboard and menu bar"`
6. Deploy to TestFlight (if applicable) or internal testing

---

**Status**: ✅ **READY FOR IMPLEMENTATION**
