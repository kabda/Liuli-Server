# Feature Specification: LAN Auto-Discovery and Pairing

**Feature Branch**: `001-lan-auto-discovery`
**Created**: 2025-11-23
**Status**: Draft
**Input**: User description: "现在需要在Liuli-iOS App中输入mac电脑的ip地址和端口号，才能完成连接，这种操作仍旧比较麻烦。我希望liuli-ios和liuli-server之间，能通过类似局域网广播的方式完成自动识别、配对，并建立连接。且当liuli-server关闭bridge或退出软件后，liuli-ios能感知到，并关闭vpn连接，避免影响手机上网。" + Additional requirement: "还需要支持Android手机的连接"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatic Server Discovery (Priority: P1)

As a Liuli mobile user (iOS or Android), I want my mobile device to automatically discover available Liuli-Server instances on my local network without manually entering IP addresses and port numbers, so that I can quickly establish a connection with minimal effort.

**Why this priority**: This is the core value proposition of the feature. Without automatic discovery, users must manually configure connection details, which is error-prone and time-consuming. This story delivers immediate value by eliminating manual configuration.

**Independent Test**: Can be fully tested by launching Liuli-Server on a Mac and opening Liuli mobile app (iOS or Android) on a device within the same LAN. The mobile app should display a list of discovered servers without any manual input.

**Acceptance Scenarios**:

1. **Given** Liuli-Server is running on Mac with bridge enabled, **When** user opens Liuli mobile app (iOS or Android) on same LAN, **Then** the mobile app displays the Mac device name and shows it as "Available"
2. **Given** multiple Liuli-Server instances running on different Macs in the LAN, **When** user opens Liuli mobile app, **Then** all available servers are listed with their respective device names
3. **Given** Liuli-Server is not running on any device in the LAN, **When** user opens Liuli mobile app, **Then** the app displays "No servers found" message with option to manually configure

---

### User Story 2 - One-Tap Connection Pairing (Priority: P1)

As a Liuli mobile user (iOS or Android), I want to select a discovered server from the list and establish a VPN connection with a single tap, so that I can start capturing traffic immediately without additional configuration steps.

**Why this priority**: Automatic discovery alone is not sufficient - users need to actually connect. This story completes the P1 MVP by enabling users to act on discovered servers. Together with Story 1, this provides a complete zero-configuration experience.

**Independent Test**: Can be fully tested by discovering a server (from Story 1) and tapping on it. The mobile app should establish a VPN connection and the Dashboard on Liuli-Server should show the connected device.

**Acceptance Scenarios**:

1. **Given** mobile app (iOS or Android) has discovered a Liuli-Server, **When** user taps on the server entry, **Then** VPN connection is established and device appears in server's Dashboard
2. **Given** user is already connected to a server, **When** user taps on a different server, **Then** existing connection is closed and new connection is established
3. **Given** user taps on a server but connection fails, **When** error occurs, **Then** app displays user-friendly error message and allows retry

---

### User Story 3 - Automatic Disconnection on Server Shutdown (Priority: P2)

As a Liuli mobile user (iOS or Android), I want my VPN connection to automatically disconnect when the Liuli-Server stops the bridge service or exits, so that my mobile device's internet access is not disrupted and I don't have to manually disable VPN.

**Why this priority**: This prevents a common failure mode where users forget the VPN is active after the server stops, resulting in no internet access. While important for user experience, it's not essential for initial connectivity (Stories 1-2), making it P2.

**Independent Test**: Can be fully tested by establishing a connection (from Story 2), then stopping the bridge service or quitting Liuli-Server. The mobile device should automatically disconnect VPN and restore normal internet access.

**Acceptance Scenarios**:

1. **Given** mobile device (iOS or Android) is connected via VPN to Liuli-Server, **When** server stops bridge service, **Then** mobile app receives disconnect signal and closes VPN connection
2. **Given** mobile device is connected via VPN to Liuli-Server, **When** Liuli-Server application is quit, **Then** mobile app detects server unavailability and closes VPN connection within 10 seconds
3. **Given** VPN connection is automatically closed due to server shutdown, **When** disconnection occurs, **Then** mobile app shows notification explaining why VPN was disconnected

---

### User Story 4 - Persistent Pairing for Quick Reconnection (Priority: P3)

As a Liuli mobile user (iOS or Android), I want my mobile app to remember previously paired servers and automatically reconnect to the last used server when it becomes available again, so that I don't have to re-select the server each time.

**Why this priority**: This is a convenience enhancement that improves the user experience for repeat usage. However, it's not essential for the initial feature to work - users can manually select servers each time (Stories 1-2). This can be added after core functionality is stable.

**Independent Test**: Can be fully tested by connecting to a server, closing the mobile app, then reopening it while the server is still running. The app should automatically reconnect to the same server without user intervention.

**Acceptance Scenarios**:

1. **Given** user has previously connected to a specific server, **When** user opens mobile app (iOS or Android) and that server is available, **Then** app automatically initiates connection to that server
2. **Given** last connected server is not available, **When** user opens mobile app, **Then** app shows server list without auto-connecting
3. **Given** user manually selects a different server, **When** connection is established, **Then** this becomes the new preferred server for future auto-connection

---

### Edge Cases

- What happens when network changes during server discovery (e.g., WiFi to cellular)?
  - Discovery should stop when not on WiFi, and resume when returning to WiFi network
- What happens when multiple devices have identical device names?
  - System should append MAC address or unique identifier to disambiguate
- What happens when mobile device and Mac are on different subnets in the same physical location?
  - Discovery will not find servers on different subnets; app should display manual configuration option
- How does system handle rapid server start/stop cycles?
  - Server list should debounce updates with 2-second cooldown to avoid UI flicker
- What happens when VPN connection is lost due to network instability (not server shutdown)?
  - System should attempt automatic reconnection up to 3 times before requiring user intervention
- What happens when server is discoverable but port is blocked by firewall?
  - Connection attempt should timeout after 10 seconds and display firewall/network error message

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST broadcast server availability announcements on the local network periodically (every 5 seconds), with initial announcement consisting of 3 rapid broadcasts 1 second apart for faster discovery
- **FR-002**: System MUST include in broadcast message: server device name, service port number, unique server identifier, bridge status (active/inactive)
- **FR-003**: Mobile apps (iOS and Android) MUST listen for server broadcasts on local network when app is in foreground or background
- **FR-003-iOS**: iOS app MUST use Bonjour/mDNS API for service discovery
- **FR-003-Android**: Android app MUST use NSD (Network Service Discovery) API for service discovery
- **FR-004**: Mobile apps MUST display discovered servers in a list showing device name and connection status
- **FR-005**: Mobile apps MUST allow user to initiate VPN connection by selecting a discovered server from the list
- **FR-006**: Server MUST send periodic heartbeat signals (every 30 seconds when app is active, every 60 seconds when app is in background) to connected mobile devices
- **FR-007**: Mobile apps MUST monitor heartbeat signals and detect server unavailability when heartbeats stop for more than 90 seconds
- **FR-008**: Mobile apps MUST automatically disconnect VPN when server unavailability is detected
- **FR-009**: System MUST notify mobile users via notification when VPN is auto-disconnected due to server shutdown
- **FR-010**: Mobile apps MUST handle manual IP/port configuration as fallback when no servers are discovered
- **FR-011**: Server broadcast MUST cease immediately when bridge service is stopped or application exits
- **FR-012**: Mobile apps MUST remove servers from discovered list when no broadcast received for 15 seconds
- **FR-013**: System MUST validate server identity using self-signed certificates with trust-on-first-use (TOFU) pattern - on first connection, mobile app displays server certificate fingerprint for user verification, subsequent connections automatically trust the pinned certificate
- **FR-014**: Mobile apps MUST persist last connected server information for future auto-reconnection
- **FR-015**: Mobile apps MUST automatically attempt connection to last known server when it becomes available again
- **FR-016**: System MUST log critical events including connection establishment, connection disconnection, authentication failures, and error conditions for troubleshooting purposes
- **FR-017**: Server MUST support 5-10 concurrent mobile device connections (iOS and Android combined) simultaneously
- **FR-018**: Mobile apps MUST automatically purge pairing records older than 30 days
- **FR-019**: System MUST use mDNS/DNS-SD protocol for service discovery (Bonjour on iOS, NSD on Android)

### Key Entities

- **Server Broadcast Message**: Represents availability announcement sent by Liuli-Server, containing device name, service port, unique identifier, bridge status, timestamp
- **Discovered Server**: Represents a Liuli-Server instance detected on the local network, including identity, network location, last seen time, connection status
- **Server Connection**: Represents active VPN tunnel between mobile device (iOS or Android) and Liuli-Server, including establishment time, data transfer statistics, heartbeat status
- **Pairing Record**: Represents historical connection between mobile device and specific server, including server identifier, device name, device platform (iOS/Android), last connection time, user preference for auto-reconnection; records are automatically purged after 30 days

## Clarifications

### Session 2025-11-23

- Q: What level of logging and monitoring should the system implement for troubleshooting? → A: Record only critical events (connection establishment/disconnection, authentication failures, errors)
- Q: How many concurrent iOS device connections should a single server instance support? → A: Support 5-10 concurrent mobile devices (iOS and Android combined, medium team scenario)
- Q: Should the mobile apps continue listening for server broadcasts when running in the background? → A: Continue listening in both foreground and background (applies to both iOS and Android)
- Q: How long should historical pairing records be retained? → A: Retain for 30 days then automatically purge
- Q: Is Bonjour/mDNS a hard requirement or just a suggestion for the discovery protocol? → A: Bonjour/mDNS is a hard requirement
- Q: Should the feature support Android devices in addition to iOS? → A: Yes, extend feature to support both iOS and Android mobile clients
- Q: Which service discovery protocol should Android use? → A: Android NSD (Network Service Discovery), compatible with iOS Bonjour via mDNS

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can discover and connect to a Liuli-Server in under 15 seconds without manually entering any configuration (applies to both iOS and Android)
- **SC-002**: Server discovery completes within 5 seconds of opening the mobile app when server is running (applies to both iOS and Android)
- **SC-003**: Mobile device (iOS or Android) automatically disconnects VPN within 10 seconds when server stops or exits
- **SC-004**: Zero manual IP/port entry required for 95% of users in typical home network scenarios
- **SC-005**: Connection establishment success rate exceeds 95% when server is available and reachable (measured across both platforms)
- **SC-006**: Auto-reconnection to preferred server succeeds within 10 seconds when server becomes available again (applies to both iOS and Android)
- **SC-007**: Users report 80% reduction in connection setup time compared to manual IP/port entry
- **SC-008**: Zero incidents of mobile device stuck with non-functional VPN after server shutdown
- **SC-009**: Server maintains stable performance with 5-10 concurrent mobile device connections (iOS and Android combined) without degradation

## Assumptions

- Users' mobile devices (iOS or Android) and Mac computers are connected to the same local area network (same subnet)
- Local network allows multicast or broadcast traffic for service discovery (mDNS/DNS-SD)
- Network firewalls permit traffic on mDNS ports (UDP 5353)
- Mobile apps have necessary network permissions granted by user
- Average home/office networks have typical multicast capabilities
- Users understand that automatic discovery only works on same LAN (not over internet)
- Server authentication uses TLS certificates or similar cryptographic validation to prevent spoofing
- Android devices run Android 4.1 (API level 16) or higher for NSD support
- iOS devices run iOS 14.0 or higher for local network permission requirements

## Dependencies

- iOS app requires network permission for local network scanning (iOS 14+ privacy requirement)
- iOS app requires background network capability for continuous server discovery when app is not in foreground
- Android app requires CHANGE_WIFI_MULTICAST_STATE and ACCESS_NETWORK_STATE permissions for NSD
- Android app requires foreground service for continuous background discovery
- Feature requires mobile apps (iOS and Android) and macOS server components to be updated together
- Server broadcast functionality must not interfere with existing SOCKS5 bridge service
- VPN connection mechanism (existing functionality) must support programmatic disconnect API on both iOS and Android

## Out of Scope

- Discovery across different subnets or VLANs
- Discovery over internet (WAN) connections
- Support for connecting through VPN or proxy to reach the server
- Advanced server filtering or search capabilities
- User authentication or multi-user account management
- Encrypted or authenticated broadcast messages (authentication occurs at connection time)
- Server capacity or load balancing when multiple mobile devices connect
- Bandwidth usage monitoring in the discovery protocol itself
- Platform-specific UI/UX optimizations beyond functional parity
