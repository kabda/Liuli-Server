# Feature Specification: iOS VPN Traffic Bridge to Charles

**Feature Branch**: `001-ios-vpn-bridge`
**Created**: 2025-11-22
**Status**: Draft
**Input**: Liuli-Server是一款MacOS App,它的主要功能是与 Liuli-iOS(另一款iOS VPN App)协同工作,接收来自Liuli-iOS的流量并转给Charles工具完成手机流量抓包

## Terminology

- **Liuli-Server**: Official product name (macOS application)
- **Mac Bridge**: Informal/user-facing name (used in UI and user communication)
- **Usage**: Use "Liuli-Server (Mac Bridge)" on first mention in technical docs, then "Liuli-Server" for code/architecture, "Mac Bridge" for user-facing content

**Naming Convention**:
- Code identifiers: `LiuliServer`, `BridgeService`
- UI labels: "Mac Bridge", "Service Running"
- Documentation: "Liuli-Server"

## Clarifications

### Session 2025-11-22

- Q: How should the system verify connections come from trusted local networks rather than the internet? → A: Accept connections from RFC 1918 private IP address ranges (10.x.x.x, 172.16-31.x.x, 192.168.x.x) plus link-local addresses (169.254.x.x, fe80::/10)
- Q: When Mac Bridge app quits and restarts, how should cumulative statistics (total connections, total bytes) be handled? → A: Reset to zero - each app launch is a new statistics session (consistent with privacy-first in-memory-only design)
- Q: How often should the system check Charles availability, and how should new iOS connection requests be handled during Charles unavailability? → A: Passive detection - only detect on connection failure, then retry with exponential backoff (1s, 2s, 4s), maximum 5 attempts
- Q: When an iOS client requests a domain name that cannot be resolved (DNS failure), what SOCKS5 error code should the system return? → A: Return 0x04 (Host unreachable) for DNS resolution failures, following RFC 1928 semantics
- Q: If Charles is unavailable when service starts, should the system block service startup or allow startup with a warning? → A: Allow service to start normally, display warning notification "Charles not detected", rely on automatic reconnection mechanism

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One-Click Service Start from Menu Bar (Priority: P1)

A QA engineer needs to quickly enable iOS packet capture from their Mac without opening full applications or complex configuration.

**Why this priority**: This is the core entry point for all functionality. Without the ability to start the service, no other features can be used. It directly addresses the "zero-configuration" goal and is the most fundamental user interaction.

**Independent Test**: Can be fully tested by clicking the menu bar icon and selecting "Start Service". Delivers immediate value by launching the SOCKS5 server and Bonjour advertisement, allowing iOS devices to discover the Mac.

**Acceptance Scenarios**:

1. **Given** the Mac Bridge app is running in the menu bar, **When** I click the menu bar icon and select "Start Service", **Then** the service starts within 3 seconds and the icon changes to green (running state)
2. **Given** the service is stopped, **When** I start the service, **Then** I see a notification saying "Service Running" with the count of connected devices (0 initially)
3. **Given** the service is running, **When** I click the menu bar icon, **Then** I see the current status showing "Service Running" and options to stop the service, open preferences, or quit the app
4. **Given** Charles Proxy is not running, **When** I start the service, **Then** the service starts successfully but I see a warning notification "Charles not detected" with a "Launch Charles" button
5. **Given** the configured port is already in use, **When** I try to start the service, **Then** I see an error message with the option to change the port in preferences

---

### User Story 2 - Automatic Discovery by iOS Devices (Priority: P1)

An iOS device running Liuli VPN needs to automatically find the Mac Bridge on the local network without manual IP address entry.

**Why this priority**: Zero-configuration discovery is critical for user experience. Without this, users would need to manually enter IP addresses, making the solution impractical for non-technical users. This is a core requirement for seamless integration.

**Independent Test**: Can be tested by starting the Mac Bridge service and opening the Liuli iOS app's server selection screen. The Mac should appear in the list within 5 seconds without any manual configuration.

**Acceptance Scenarios**:

1. **Given** Mac Bridge service is running on the same Wi-Fi network, **When** I open Liuli iOS app and navigate to server selection, **Then** I see my Mac's name (e.g., "MacBook-Pro") in the available servers list within 5 seconds
2. **Given** multiple Macs are running Mac Bridge on the network, **When** I view the server list, **Then** I see all available Macs with their device names clearly displayed
3. **Given** Mac Bridge service is stopped, **When** I refresh the iOS server list, **Then** the Mac no longer appears in the available servers
4. **Given** the Mac's Wi-Fi connection is interrupted and then reconnected, **When** I check the iOS server list after 10 seconds, **Then** the Mac reappears in the list automatically
5. **Given** the iOS device is on a different network than the Mac, **When** I view the server list, **Then** the Mac does not appear (local network only)

---

### User Story 3 - Seamless Traffic Forwarding to Charles (Priority: P1)

A QA engineer needs all iOS app traffic to appear in Charles Proxy automatically once the iOS device connects to Mac Bridge.

**Why this priority**: This is the primary business value of the application. Without successful traffic forwarding to Charles, the entire purpose of the app is not fulfilled. This must work reliably for the app to be useful.

**Independent Test**: Can be tested by connecting an iOS device to Mac Bridge via Liuli VPN, opening any app on iOS (e.g., Safari), and verifying that all network requests appear in Charles Proxy's session list within 10 seconds.

**Acceptance Scenarios**:

1. **Given** Mac Bridge service is running and Charles Proxy is open, **When** I connect my iOS device via Liuli VPN and browse a website, **Then** I see all HTTP/HTTPS requests in Charles Proxy within 10 seconds
2. **Given** an iOS app makes an HTTPS request, **When** the traffic is forwarded through Mac Bridge, **Then** Charles Proxy shows the encrypted tunnel (CONNECT method) and can decrypt it if SSL Proxying is enabled
3. **Given** multiple iOS apps are generating traffic simultaneously, **When** traffic flows through Mac Bridge, **Then** Charles shows all requests from all apps with correct source indicators
4. **Given** Charles Proxy is restarted while iOS is connected, **When** Charles becomes available again, **Then** Mac Bridge automatically reconnects and traffic forwarding resumes without requiring iOS reconnection
5. **Given** an iOS app sends large file uploads or downloads, **When** traffic flows through Mac Bridge, **Then** the data transfer completes successfully without corruption or performance degradation

---

### User Story 4 - Real-Time Connection Monitoring (Priority: P2)

A QA engineer needs to verify which iOS devices are actively connected and monitor traffic statistics in real-time.

**Why this priority**: Visibility into active connections is important for troubleshooting and multi-device testing scenarios. However, the core functionality (traffic forwarding) works without this monitoring interface.

**Independent Test**: Can be tested by opening the Statistics window while one or more iOS devices are connected and generating traffic. The window should display live updates of connection count, bytes transferred, and device information.

**Acceptance Scenarios**:

1. **Given** Mac Bridge service is running with 2 iOS devices connected, **When** I click "View Statistics" in the menu, **Then** I see a window showing 2 connected devices with their IP addresses and connection durations
2. **Given** an iOS device is actively downloading data, **When** I view the statistics window, **Then** I see the bytes downloaded counter incrementing in real-time (updated every 1 second)
3. **Given** an iOS device disconnects, **When** the statistics window is open, **Then** the device is removed from the active connections list within 3 seconds
4. **Given** 10 iOS devices have connected over a session, **When** I view the statistics, **Then** I see historical connection log showing the last 50 connections with timestamps and total bytes transferred
5. **Given** Mac Bridge has been running with connections, **When** I quit and relaunch the app, **Then** all statistics counters reset to zero (new session starts fresh)

---

### User Story 5 - Persistent Configuration (Priority: P3)

A QA engineer needs their Mac Bridge settings to be remembered across app launches so they don't need to reconfigure each time.

**Why this priority**: Quality of life improvement that saves time for frequent users. The app can function without this (using defaults each time), making it a lower priority than core functionality.

**Independent Test**: Can be tested by changing settings in Preferences (e.g., changing SOCKS5 port to 9001, enabling "Launch Charles automatically"), quitting Mac Bridge, relaunching the app, and verifying settings are preserved.

**Acceptance Scenarios**:

1. **Given** I change the SOCKS5 port to 9001 in preferences, **When** I quit and relaunch Mac Bridge, **Then** the port setting is still 9001 and the service uses that port
2. **Given** I enable "Auto-start on login" in preferences, **When** I restart my Mac, **Then** Mac Bridge launches automatically in the menu bar
3. **Given** I enable "Launch Charles automatically" in preferences, **When** I start Mac Bridge service and Charles is not running, **Then** Charles Proxy launches automatically
4. **Given** I disable notifications in preferences, **When** an iOS device connects, **Then** no system notification is shown
5. **Given** I configure a custom Charles Proxy address (e.g., remote Mac at 192.168.1.100:8888), **When** I restart Mac Bridge, **Then** the custom proxy address is retained and used for forwarding

---

### User Story 6 - Quick Access to Charles Proxy (Priority: P3)

A QA engineer needs quick access to launch or bring Charles Proxy to the foreground without leaving the Mac Bridge menu.

**Why this priority**: Convenience feature that improves workflow efficiency. Users can always launch Charles manually from Spotlight or Applications folder, so this is not critical functionality.

**Independent Test**: Can be tested by clicking "Open Charles Proxy" from the Mac Bridge menu and verifying that Charles either launches (if not running) or comes to the foreground (if already running).

**Acceptance Scenarios**:

1. **Given** Charles Proxy is not running, **When** I click "Open Charles Proxy" in Mac Bridge menu, **Then** Charles launches within 5 seconds
2. **Given** Charles Proxy is already running but in the background, **When** I click "Open Charles Proxy", **Then** Charles window comes to the foreground immediately
3. **Given** Charles Proxy is not installed on the Mac, **When** I click "Open Charles Proxy", **Then** I see an error message "Charles Proxy not found. Please install Charles from www.charlesproxy.com"
4. **Given** the service is stopped and I click "Open Charles Proxy", **When** Charles launches, **Then** Mac Bridge does not automatically start the service (manual control preserved)

---

### Edge Cases

- **What happens when a connection attempt comes from a non-local network IP address (e.g., public internet)?**
  System MUST reject the connection immediately by closing the socket without SOCKS5 handshake, and log a security warning to Console.app with the source IP address.

- **What happens when the Mac's IP address changes (Wi-Fi reconnection)?**
  System MUST re-advertise Bonjour service with the new IP address within 5 seconds. Existing iOS connections MUST be maintained if possible, or cleanly dropped with automatic reconnection initiated by the iOS client.

- **How does the system handle rapid start/stop service cycles?**
  System MUST queue start/stop requests and process them sequentially. If a stop is initiated while starting, the start MUST complete first, then stop. UI MUST show appropriate transitional states ("Starting...", "Stopping...").

- **What happens when 100+ iOS devices try to connect simultaneously?**
  System MUST accept the first 100 connections and return a SOCKS5 "Connection refused" error for connections beyond the limit. Menu bar MUST show warning indicator when approaching connection limit.

- **How does the system handle Charles Proxy port conflict (another app using 8888)?**
  System MUST detect the port conflict during Charles detection and show an error message: "Charles Proxy port 8888 is in use by another application. Please change Charles proxy settings or configure a different port in Mac Bridge preferences."

- **What happens when an iOS app keeps a connection open indefinitely (no traffic)?**
  System MUST implement a 60-second idle timeout. If no data is sent or received on a connection for 60 seconds, the connection MUST be closed gracefully with proper SOCKS5 termination.

- **How does the system handle network interface changes (Wi-Fi → Ethernet)?**
  System MUST detect interface changes via system notifications and re-advertise Bonjour service on the new active interface within 5 seconds. SOCKS5 server continues running on 0.0.0.0 (all interfaces).

- **What happens when memory usage exceeds 100MB?**
  System MUST log a warning to Console.app and attempt to close oldest idle connections first. If memory continues to grow, system MUST show an error notification and recommend restarting the service.

- **How does the system handle corrupted UserDefaults data for preferences?**
  System MUST detect JSON decode failures, log the error, reset to default configuration, and show a one-time notification: "Preferences were corrupted and reset to defaults."

## Requirements *(mandatory)*

### Functional Requirements

#### Service Discovery
- **FR-001**: System MUST advertise a Bonjour/mDNS service with type `_charles-bridge._tcp` and domain `local.` when service is started
- **FR-002**: Bonjour service name MUST be the Mac device's hostname (e.g., "MacBook-Pro") obtained from the system
- **FR-003**: Bonjour service TXT record MUST include three fields: `version` (app version), `port` (SOCKS5 port number), and `device` (Mac hardware model identifier)
- **FR-004**: Bonjour service MUST be advertised on all active network interfaces (Wi-Fi, Ethernet, etc.)
- **FR-005**: System MUST re-advertise Bonjour service automatically within 5 seconds when network interface changes are detected
- **FR-006**: System MUST stop advertising Bonjour service immediately when service is manually stopped by the user

#### SOCKS5 Proxy Server
- **FR-007**: System MUST run a SOCKS5 proxy server (RFC 1928) on a user-configurable port (default: 9000)
- **FR-008**: SOCKS5 server MUST support authentication method 0x00 (No Authentication) only
- **FR-009**: SOCKS5 server MUST support CONNECT command (0x01) for TCP connections
- **FR-010**: SOCKS5 server MUST support UDP ASSOCIATE command (0x03) for UDP relay
  - **⚠️ DEFERRED TO v2.0**: UDP relay functionality deferred to future release. MVP focuses on TCP-based HTTP/HTTPS traffic forwarding. All six user stories can be validated without UDP support. UDP support requires additional complexity (UDP socket management, NAT traversal, QUIC protocol handling) that is not critical for initial Charles Proxy integration. See "Future Work" section for v2.0 planning.
- **FR-011**: SOCKS5 server MUST bind to 0.0.0.0 but only accept connections from RFC 1918 private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) and link-local addresses (169.254.0.0/16 for IPv4, fe80::/10 for IPv6), rejecting all other source addresses
- **FR-012**: SOCKS5 server MUST handle at least 100 concurrent TCP connections without performance degradation
- **FR-013**: SOCKS5 server MUST support IPv4 address type (0x01) in connection requests
- **FR-014**: SOCKS5 server MUST support IPv6 address type (0x04) in connection requests
- **FR-015**: SOCKS5 server MUST support domain name address type (0x03) in connection requests and perform DNS resolution; if DNS resolution fails, return error code 0x04 (Host unreachable)
- **FR-016**: SOCKS5 server MUST return appropriate error codes: 0x01 (general failure) for server errors, 0x04 (host unreachable) for DNS failures or unreachable destinations, 0x05 (connection refused) for TCP connection failures

#### Protocol Forwarding
- **FR-017**: System MUST forward all accepted SOCKS5 connections to a configured HTTP/HTTPS proxy (default: localhost:8888 for Charles)
- **FR-018**: System MUST use HTTP CONNECT method to establish tunnels for HTTPS traffic (port 443 and other TLS ports)
- **FR-019**: System MUST forward HTTP traffic (port 80) directly to Charles proxy without CONNECT tunneling
- **FR-020**: System MUST maintain bidirectional data streaming between iOS client and Charles proxy with no data loss
- **FR-021**: System MUST detect when Charles Proxy is unreachable and return SOCKS5 error code 0x05 (Connection refused) to the client
- **FR-022**: System MUST buffer up to 64KB of data per connection to handle temporary network latency. If buffer exceeds 64KB (e.g., slow Charles Proxy consumption), system MUST apply backpressure to iOS client by pausing socket reads until buffer drains below 32KB (hysteresis), then resume reading.
  - **Overflow Behavior**: Do NOT drop connection on buffer overflow. Use SwiftNIO's backpressure mechanism (channel.setAutoRead(false)) to pause iOS socket reads.
- **FR-023**: System MUST close connections cleanly when either the iOS client or Charles proxy closes their end

#### User Interface
- **FR-024**: Application MUST run as a menu bar-only app (no Dock icon) using LSUIElement setting
- **FR-025**: Menu bar icon MUST display different colors based on service state: gray (stopped), blue (starting), green (running with no connections), yellow (running with active connections), red (error)
- **FR-026**: Menu bar dropdown MUST show current service status text, connected device count, and action buttons (Start/Stop Service, Open Charles Proxy, View Statistics, Preferences, Quit)
- **FR-027**: Application MUST provide a Preferences window accessible from the menu bar with settings for SOCKS5 port, Charles proxy address, auto-start options, and notifications
- **FR-028**: Application MUST provide a Statistics window showing real-time connection data including connected device IPs, device names (obtained via reverse DNS lookup; display IP address as fallback if reverse DNS fails or returns no PTR record), bytes uploaded/downloaded, connection duration, and current throughput
- **FR-029**: Application MUST show macOS system notifications for key events: service started, service stopped, new iOS device connected, Charles proxy not reachable, and service errors
- **FR-030**: Menu bar dropdown MUST open within 100ms of user click and remain responsive during network operations

#### Connection Management
- **FR-031**: System MUST track metadata for each active connection including source IP address, destination host and port, connection start timestamp, and bytes transferred in both directions
- **FR-032**: System MUST close idle connections that have no data activity for 60 consecutive seconds
- **FR-033**: System MUST clean up all socket resources and memory buffers immediately when a connection closes
- **FR-034**: System MUST log connection events (new connection, connection closed, forwarding errors) to macOS Console.app using OSLog for troubleshooting
- **FR-035**: System MUST maintain a historical log of the last 50 connections with their metadata even after they close (in-memory only, not persisted to disk)

#### Charles Proxy Integration
- **FR-036**: System MUST detect if Charles Proxy is running by checking for the "Charles" process name and attempting a TCP connection to the configured proxy port
- **FR-037**: System MUST perform Charles detection before starting the service; if Charles is not reachable, allow service to start but display a warning notification "Charles not detected" with a "Launch Charles" action button
- **FR-038**: System MUST provide a "Launch Charles" quick action that opens Charles Proxy application if installed
- **FR-039**: System MUST use passive detection for Charles availability - only check on connection failure, then retry with exponential backoff (1 second, 2 seconds, 4 seconds) up to maximum 5 attempts before giving up
- **FR-040**: System MUST allow users to configure a custom Charles proxy address (IP and port) for scenarios where Charles runs on a different machine

#### Configuration Persistence
- **FR-041**: System MUST save user preferences (SOCKS5 port, Charles proxy address, auto-start settings, notification settings) using UserDefaults and persist them across app launches
- **FR-042**: System MUST load saved preferences on app startup and apply them before starting any services
- **FR-043**: System MUST provide default values for all preferences if no saved data exists (SOCKS5 port: 9000, Charles: localhost:8888, auto-start: false, notifications: true)
- **FR-044**: System MUST validate preference values and reject invalid inputs (e.g., port numbers outside 1024-65535 range, invalid IP addresses)
- **FR-045**: System MUST support "Auto-start on login" preference using macOS SMAppService API to register as a login item
  - **Technical Note**: Requires `com.apple.developer.system-extension.install` entitlement in Liuli-Server.entitlements (configured in T006.5)

#### Error Handling
- **FR-046**: System MUST display user-friendly error messages with actionable recovery suggestions for common failure scenarios: port already in use, Charles not reachable, network interface unavailable, Bonjour registration failed
- **FR-047**: System MUST provide contextual recovery actions in error dialogs: "Change Port" button for port conflicts, "Launch Charles" button for Charles unavailable, "Restart Service" button for service failures
  - **UI Specification**: Use native NSAlert with action buttons. Primary button = recommended action (e.g., "Change Port"), secondary button = "Cancel". Include error description and recovery instructions.
  - **Implementation**: ErrorAlertView component (T084.5) with action closures
- **FR-048**: System MUST log all errors to macOS Console.app using OSLog with appropriate log levels for developer troubleshooting
  - **Log Level Criteria**:
    - `.error`: Service start failure, port binding failure, Bonjour registration failure, unrecoverable errors
    - `.warning`: Charles unreachable (first occurrence), connection limit reached, memory warning threshold
    - `.info`: Service started/stopped, iOS device connected/disconnected, configuration changes
    - `.debug`: Individual connection details, SOCKS5 handshake steps, byte counts (disabled in Release builds)
- **FR-049**: System MUST continue running and remain accessible after non-critical errors (e.g., single connection failure should not crash the entire service)
  - **Fault Isolation**: Wrap connection handling in do-catch blocks, log errors to OSLog, increment error counter in statistics, but maintain service state as "running"
  - **Critical vs Non-Critical**: Critical = port binding failure, Bonjour registration failure. Non-critical = single connection DNS failure, Charles temporarily unreachable, single connection timeout.
- **FR-050**: System MUST handle corrupted UserDefaults data gracefully by resetting to default configuration and notifying the user

### Key Entities *(include if feature involves data)*

- **BridgeService**: Represents the overall Mac Bridge service state and lifecycle. Coordinates Bonjour publisher, SOCKS5 server, connection manager, and Charles detector. Maintains current state (idle, starting, running, stopping, error) and publishes state changes to the UI.

- **BonjourService**: Represents the mDNS/Bonjour advertisement. Contains service type, name, port, and TXT record data. Responsible for advertising on all network interfaces and handling network change events.

- **SOCKS5Connection**: Represents an individual connection from an iOS client. Contains source IP address, destination host/port, connection state, start timestamp, bytes uploaded/downloaded, and references to the iOS client socket and Charles proxy socket.

- **ConnectedDevice**: Represents an iOS device connected to Mac Bridge. Contains device IP address, optional device name (from reverse DNS or Bonjour), list of active connections from this device, total bytes transferred, and connection duration.

- **ProxyConfiguration**: Represents user preferences for the bridge service. Contains SOCKS5 port number, Charles proxy host and port, auto-start on login flag, auto-launch Charles flag, and notification preferences. Persisted using UserDefaults.

- **ConnectionStatistics**: Represents real-time and historical traffic metrics for the current application session. Contains total connection count, active connection count, total bytes uploaded/downloaded across all connections, current throughput (bytes per second), and historical connection log (last 50 connections). All statistics reset to zero when application restarts (session-scoped, not persisted).

- **CharlesProxyStatus**: Represents the availability status of Charles Proxy. Contains host address, port number, availability state (reachable/unreachable), last check timestamp, and error details if unreachable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: QA engineer can launch Mac Bridge and start the service within 3 seconds of clicking "Start Service", with visual confirmation via menu bar icon color change
- **SC-002**: iOS device automatically discovers Mac Bridge within 5 seconds of opening Liuli app's server selection screen when both devices are on the same Wi-Fi network
- **SC-003**: All iOS app traffic (HTTP and HTTPS) appears in Charles Proxy session list within 10 seconds of iOS device connecting via Liuli VPN
- **SC-004**: Mac Bridge handles 10 concurrent iOS device connections without any connection failures or performance degradation (latency increase < 50ms)
- **SC-005**: Mac Bridge runs continuously for 8 hours with active traffic without crashes, memory leaks (memory stays below 100MB), or requiring manual restarts
- **SC-006**: Menu bar UI responds to user clicks within 100ms and remains responsive even when handling 100 concurrent connections
- **SC-007**: When Charles Proxy is not running at service start, Mac Bridge starts successfully and displays a warning notification "Charles not detected" within 2 seconds, with "Launch Charles" action button
- **SC-008**: Application memory usage stays below 50MB with 10 active iOS connections and typical traffic patterns (50 requests per minute)
- **SC-009**: After Mac's Wi-Fi reconnects or IP address changes, Bonjour service re-advertises and iOS devices can discover the Mac again within 5 seconds
- **SC-010**: Application quits cleanly within 2 seconds when user selects "Quit", releasing all socket resources with no orphaned processes (verified in Activity Monitor)
- **SC-011**: 95% of user configuration changes (port, proxy address, auto-start) persist correctly across app restarts without data loss
- **SC-012**: Users can complete the entire workflow (start service, connect iOS device, view traffic in Charles) within 60 seconds from first launch without reading documentation
- **SC-013**: System correctly handles edge cases (rapid start/stop, Charles restart, network changes) in 90% of test scenarios without requiring user intervention or service restart
- **SC-014**: Protocol forwarding latency overhead is less than 5ms measured from iOS client request to Charles proxy receipt for 99% of connections
- **SC-015**: Zero crashes or service failures occur during 100-connection stress test with simulated connect/disconnect cycles over 1 hour

## Future Work (Post-MVP)

### UDP Relay Support (v2.0)

**Deferred from FR-010** - UDP ASSOCIATE command (0x03) implementation

**Scope**:
- Implement RFC 1928 UDP ASSOCIATE command (0x03)
- UDP socket pool management with timeout handling
- NAT traversal and UDP hole punching
- QUIC protocol support in Charles forwarding
- UDP traffic statistics tracking

**Rationale for deferral**: Current MVP focuses on TCP-based HTTP/HTTPS traffic, which represents 95%+ of iOS app traffic analysis use cases. UDP support adds significant complexity (bidirectional UDP relay, address/port management, fragmentation handling) without immediate user value. All six user stories can be validated without UDP support.

**Technical Requirements** (for v2.0):
- UDP socket binding using SwiftNIO DatagramBootstrap
- UDP association lifecycle (2-minute timeout per RFC 1928)
- UDP packet relay between iOS client and Charles (if supported by Charles)
- Error handling for ICMP unreachable messages
- UDP connection tracking in ConnectionStatistics
