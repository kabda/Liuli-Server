# Feature Specification: Main UI Dashboard and Menu Bar Interface

**Feature Branch**: `002-main-ui-dashboard`
**Created**: 2025-11-22
**Status**: Draft
**Input**: User description: "现在这个App还没有界面展示功能,我希望添加一个UI界面,用于展示当前的网络状态,Charles的可用状态,以及已经连接的iOS设备列表(支持多iOS设备同时连接);同时,我需要在状态栏上展示一个icon,里面提供一些设置项(比如bridge功能开启/关闭等)。"

## Clarifications

### Session 2025-11-22

- Q: When bridge is disabled while devices are actively connected, how should existing connections be handled? → A: Keep existing connections active until they naturally disconnect, but reject new connection attempts (graceful degradation)
- Q: How should the system detect Charles proxy availability? → A: Send HTTP CONNECT probe request to verify proxy responds correctly (not just port listening)
- Q: What granularity should device traffic statistics display? → A: Show cumulative bytes sent/received totals (balances usefulness and UI complexity)
- Q: How should the system recover bridge state after crash or forced quit? → A: Disable bridge on restart after abnormal termination, require manual re-enable (prevents problem loops)
- Q: What should be the default window behavior on application launch? → A: Show only menu bar icon on launch, main window opened on-demand by user (standard macOS utility app pattern)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Connected iOS Devices (Priority: P1)

As a developer using Liuli-Server to debug iOS app traffic, I need to see which iOS devices are currently connected to the server so that I can confirm my test device is properly connected and ready for traffic capture.

**Why this priority**: This is the core monitoring capability. Without visibility into connected devices, users cannot verify their setup is working. This is the most critical piece of information for the primary use case.

**Independent Test**: Can be fully tested by launching the app, connecting an iOS device running Liuli-iOS, and verifying the device appears in the device list with relevant information (device name, connection time, connection status).

**Acceptance Scenarios**:

1. **Given** the app is running and no devices are connected, **When** I open the main window, **Then** I see an empty device list with a message indicating "No devices connected"
2. **Given** one iOS device has connected via Liuli-iOS, **When** I view the device list, **Then** I see the device name, connection timestamp, and active status indicator
3. **Given** three iOS devices are connected simultaneously, **When** I view the device list, **Then** I see all three devices listed with their individual connection information
4. **Given** a device was connected but has disconnected, **When** I view the device list, **Then** the device shows a disconnected status or is removed from the list
5. **Given** the main window is open, **When** a new device connects, **Then** the device list updates automatically without requiring manual refresh

---

### User Story 2 - Monitor Network and Charles Status (Priority: P1)

As a developer running Liuli-Server, I need to see the current network status and whether Charles proxy is available so that I can quickly diagnose connection problems and ensure my debugging environment is properly configured.

**Why this priority**: Status monitoring is essential for troubleshooting. Users need immediate feedback when something isn't working (Charles not running, network issues, etc.). This enables self-service problem resolution.

**Independent Test**: Can be fully tested by launching the app with Charles running/not running and verifying status indicators update correctly. Stopping Charles while app is running should trigger status change.

**Acceptance Scenarios**:

1. **Given** the app is running and Charles is not running, **When** I view the status panel, **Then** I see Charles status as "Unavailable" or "Not Detected" with a visual indicator (e.g., red/gray icon)
2. **Given** Charles proxy is running on localhost:8888, **When** I view the status panel, **Then** I see Charles status as "Available" or "Connected" with a positive visual indicator (e.g., green icon)
3. **Given** the server is listening for connections, **When** I view the network status, **Then** I see the listening status as "Active" with the port number displayed
4. **Given** the network status changes (e.g., Charles stops), **When** viewing the status panel, **Then** the status indicators update within 3 seconds without requiring manual refresh
5. **Given** Charles is available, **When** I hover over or click the status indicator, **Then** I see additional details (e.g., Charles proxy address, port number)

---

### User Story 3 - Control Bridge via Menu Bar (Priority: P2)

As a developer using Liuli-Server, I need quick access to enable/disable the bridge functionality from the menu bar so that I can control traffic forwarding without opening the main window.

**Why this priority**: This provides convenient control for the core functionality. While monitoring (P1) tells users what's happening, control (P2) lets them act on it. Menu bar access is standard for macOS utility apps.

**Independent Test**: Can be fully tested by clicking the menu bar icon, toggling the bridge on/off switch, and verifying that the toggle affects connection behavior (new connections are accepted/rejected based on state).

**Acceptance Scenarios**:

1. **Given** the app is running, **When** I click the menu bar icon, **Then** I see a menu with a bridge toggle switch showing current state (on/off)
2. **Given** the bridge is currently enabled, **When** I click the toggle to disable it, **Then** the bridge stops accepting new connections and the menu shows updated state
3. **Given** the bridge is currently disabled, **When** I click the toggle to enable it, **Then** the bridge starts accepting connections and the menu shows updated state
4. **Given** the menu bar menu is open, **When** the bridge state changes, **Then** the toggle switch reflects the current state
5. **Given** I access bridge settings from the menu bar, **When** I make a change, **Then** the change takes effect immediately without requiring app restart

---

### User Story 4 - Access Settings and Preferences (Priority: P3)

As a developer using Liuli-Server, I need to access application settings and preferences from the menu bar so that I can configure the server behavior according to my workflow needs.

**Why this priority**: Settings and preferences enable customization but are not required for basic functionality. Users can start with defaults and adjust later as needed.

**Independent Test**: Can be fully tested by accessing the menu bar menu, opening settings/preferences, modifying a setting (e.g., auto-start behavior), and verifying the change persists across app restarts.

**Acceptance Scenarios**:

1. **Given** the menu bar menu is open, **When** I click "Settings" or "Preferences", **Then** a settings window opens showing available configuration options
2. **Given** the settings window is open, **When** I modify a setting and save, **Then** the change takes effect and persists across application restarts
3. **Given** I am viewing the menu bar menu, **When** I click "Quit", **Then** the application closes gracefully and stops all active connections
4. **Given** the menu bar menu is open, **When** I click "Show Main Window", **Then** the main dashboard window appears and comes to front

---

### Edge Cases

- What happens when more than 10 iOS devices attempt to connect simultaneously?
- How does the UI handle device names with special characters or very long names (e.g., 50+ characters)?
- What happens when Charles proxy stops responding mid-session while devices are connected?
- How does the menu bar icon behave when the system menu bar is in dark mode vs light mode?
- What happens when the user toggles bridge off while devices are actively transferring traffic? (Existing connections remain active, new connections rejected)
- How does the device list handle rapid connect/disconnect cycles (e.g., device network instability)?
- What happens when the app window is minimized or hidden and a new device connects?
- What happens when the application crashes or is force-quit while bridge is enabled? (Bridge disabled on restart for safety)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a main window showing current network status, Charles availability status, and list of connected iOS devices
- **FR-002**: System MUST show device information including device name, connection timestamp, connection status, and cumulative traffic statistics (bytes sent/received) for each connected iOS device
- **FR-003**: System MUST support displaying multiple iOS devices (minimum 10) simultaneously in the device list
- **FR-004**: System MUST automatically update the device list when devices connect or disconnect without requiring manual refresh
- **FR-005**: System MUST check Charles proxy availability by sending HTTP CONNECT probe requests and display current status (available/unavailable)
- **FR-006**: System MUST display network listening status showing whether the bridge is accepting connections
- **FR-007**: System MUST show a menu bar icon that persists while the application is running
- **FR-008**: Menu bar icon MUST provide access to a dropdown menu with bridge toggle and settings options
- **FR-009**: Menu bar menu MUST include a toggle switch to enable/disable bridge functionality
- **FR-010**: Menu bar menu MUST include options to show main window (accessible at any time), access settings, and quit application
- **FR-011**: Bridge enable/disable toggle MUST take effect immediately when changed (disabling bridge keeps existing connections active but rejects new connections)
- **FR-012**: System MUST persist bridge state (on/off) across normal application restarts, but MUST default to disabled state after abnormal termination (crash or force quit)
- **FR-013**: Status indicators MUST update within 3 seconds when underlying conditions change (e.g., Charles stops)
- **FR-014**: System MUST allow the main window to be closed while keeping the application running in menu bar
- **FR-015**: System MUST remove disconnected devices immediately from the device list
- **FR-016**: System MUST allow Charles proxy address and port to be configurable in settings with localhost:8888 as the default value
- **FR-017**: System MUST launch with only the menu bar icon visible, keeping the main window hidden until user explicitly opens it

### Key Entities

- **Device Connection**: Represents an iOS device connection, including device identifier (UUID format), device name, connection timestamp, connection status (active/disconnected), and cumulative traffic statistics showing total bytes sent and received since connection established
- **Network Status**: Represents the current state of the network bridge, including listening status (active/inactive), listening port, number of active connections
- **Charles Status**: Represents the availability and connection state of Charles proxy, including availability status (available/unavailable), proxy address, proxy port, last check timestamp
- **Application Settings**: Represents user preferences and configuration, including bridge auto-start preference, Charles proxy configuration, menu bar icon behavior, window display preferences

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can identify connected iOS devices and their status within 1 second of opening the main window
- **SC-002**: Charles availability status updates and displays within 3 seconds of Charles proxy starting or stopping
- **SC-003**: Bridge can be toggled on/off from menu bar with state change taking effect within 1 second
- **SC-004**: Main UI displays up to 10 concurrent iOS device connections without performance degradation
- **SC-005**: 95% of users can successfully locate and use the bridge toggle without referring to documentation
- **SC-006**: Status information updates automatically without user intervention, reducing troubleshooting time by 60%
- **SC-007**: Menu bar icon remains responsive with menu opening in under 0.5 seconds

## Assumptions *(mandatory)*

- Charles proxy runs on localhost by default (configurable in settings)
- Default Charles proxy port is 8888 (industry standard, but user-configurable)
- Charles availability is verified using HTTP CONNECT probe requests (not just port checking)
- Disconnected devices are removed immediately from the device list to maintain UI clarity
- Device traffic statistics display cumulative bytes sent/received (not real-time rates)
- Application launches in background with menu bar icon only (main window opened on-demand)
- Abnormal termination (crash/force-quit) automatically disables bridge on restart for safety
- When bridge is disabled with active connections, existing connections continue until natural disconnect
- Device information (name, identifier) is provided by the iOS client during connection handshake
- macOS menu bar icon best practices will be followed (SF Symbols, system color adaptation)
- Main window can be closed while app continues running in menu bar (standard macOS utility app pattern)
- Connection status checks occur at reasonable intervals (e.g., every 5-10 seconds) to balance responsiveness and resource usage
- Device list will use standard macOS list/table UI patterns (similar to Activity Monitor or Network Utility)

## Out of Scope *(optional)*

- Traffic content inspection or packet analysis (handled by Charles)
- Traffic statistics graphs or historical charts (may be added in future iteration)
- Multi-server coordination (single server instance only)
- Custom theming or extensive UI customization options
- Device management features (e.g., blocking specific devices, priority queuing)
- Push notifications for device connections/disconnections
- Export of connection logs or device history
- Integration with other proxy tools besides Charles

## Dependencies *(optional)*

- Requires existing iOS VPN client (Liuli-iOS) to establish connections
- Requires Charles proxy to be installed and running for full functionality
- **Bridge Integration**: Network bridge implementation MUST expose connection events through one of these mechanisms:
  - **Preferred**: `AsyncStream<ConnectionEvent>` observable pattern (aligns with Swift 6 async/await model)
  - **Alternative**: Delegate protocol `BridgeConnectionDelegate` with `didConnect(device:)` / `didDisconnect(deviceId:)` callbacks
  - **Required Event Data**: Device identifier (UUID), device name (String), connection timestamp (Date)
  - **Implementation Assumption**: Bridge from feature 001-ios-vpn-bridge already implements event emission; DeviceMonitorRepositoryImpl will subscribe during Phase 7 integration (tasks T070-T071)
- Menu bar integration requires macOS system APIs (NSStatusBar)

## Security and Privacy Considerations *(optional)*

- Device information displayed should not include sensitive data beyond device name and connection metadata
- No traffic content should be logged or displayed in the UI to protect user privacy
- Bridge toggle state changes should require no additional authentication (user already has system access)
- Settings data persistence should use macOS standard secure storage (UserDefaults for non-sensitive, Keychain for sensitive data)
