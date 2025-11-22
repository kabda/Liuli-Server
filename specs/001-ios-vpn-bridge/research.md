# Research & Technology Decisions

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Phase**: 0 (Design Research)

## Purpose

This document captures all technology decisions, patterns, and architectural choices for implementing the Liuli-Server macOS application. All "NEEDS CLARIFICATION" items from the Technical Context have been researched and resolved.

## Technology Stack Decisions

### 1. SOCKS5 Server Implementation

**Decision**: Use SwiftNIO 2.60+ with custom channel handlers

**Rationale**:
- SwiftNIO is Apple's high-performance networking framework, battle-tested in production (Vapor, gRPC-Swift)
- Event-driven architecture handles 100+ concurrent connections with minimal overhead
- ChannelHandler pattern allows clean separation of SOCKS5 protocol logic from forwarding logic
- Structured concurrency support (async/await) introduced in SwiftNIO 2.29+
- Active maintenance by Apple's Server Side Swift team

**Alternatives Considered**:
1. **Raw BSD sockets** - Rejected: Requires manual thread management, no structured concurrency, high complexity
2. **Network.framework (Apple)** - Rejected: Designed for client-side connections, lacks server listener ergonomics, no SOCKS5 helpers
3. **Third-party SOCKS5 libraries** - Rejected: No Swift 6-compatible options, most unmaintained since 2019

**Implementation Pattern**:
```swift
// Bootstrap SOCKS5 server on configurable port
let bootstrap = ServerBootstrap(group: eventLoopGroup)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .childChannelInitializer { channel in
        channel.pipeline.addHandlers([
            IPAddressValidationHandler(),  // Reject non-RFC 1918 sources
            SOCKS5HandshakeHandler(),       // RFC 1928 protocol negotiation
            CharlesForwardingHandler()       // HTTP CONNECT tunneling
        ])
    }
```

**Key References**:
- [SwiftNIO Documentation](https://github.com/apple/swift-nio)
- [RFC 1928: SOCKS Protocol Version 5](https://datatracker.ietf.org/doc/html/rfc1928)
- [SwiftNIO Examples: Echo Server](https://github.com/apple/swift-nio/tree/main/Sources/NIOEchoServer)

---

### 2. Bonjour/mDNS Service Advertisement

**Decision**: Use Foundation NetService (no third-party dependencies)

**Rationale**:
- Native macOS API with zero external dependencies
- Automatic handling of network interface changes (Wi-Fi ↔ Ethernet)
- Thread-safe delegate-based API compatible with Swift concurrency via Continuation
- Integrated with macOS system-level mDNS responder (reliable discovery)
- No SPM package versioning risk (part of Foundation)

**Alternatives Considered**:
1. **Manual mDNS packets (DNS-SD protocol)** - Rejected: Complex wire format, must implement responder daemon, error-prone
2. **Third-party Bonjour wrappers** - Rejected: NetService already provides clean Swift interface, no value added

**Implementation Pattern**:
```swift
actor BonjourPublisher {
    private var netService: NetService?

    func publish(port: Int, version: String) async throws {
        let service = NetService(domain: "local.", type: "_charles-bridge._tcp.",
                                 name: Host.current().localizedName ?? "Mac Bridge",
                                 port: Int32(port))
        let txtRecord = NetService.data(fromTXTRecord: [
            "version": version.data(using: .utf8)!,
            "port": "\(port)".data(using: .utf8)!,
            "device": hardwareModel().data(using: .utf8)!
        ])
        service.setTXTRecord(txtRecord)
        service.publish(options: .listenForConnections)
        self.netService = service
    }
}
```

**Key References**:
- [Apple NetService Documentation](https://developer.apple.com/documentation/foundation/netservice)
- [RFC 6763: DNS-Based Service Discovery](https://datatracker.ietf.org/doc/html/rfc6763)

---

### 3. Menu Bar Integration (LSUIElement App)

**Decision**: SwiftUI + AppKit hybrid (NSStatusItem + NSPopover)

**Rationale**:
- SwiftUI 4.0+ (macOS 13+) supports declarative menu bar content via Scene and Commands
- NSStatusItem provides menu bar icon lifecycle (show/hide, system tray management)
- NSPopover allows rich SwiftUI content in dropdown (better than NSMenu for statistics)
- LSUIElement=YES in Info.plist hides Dock icon while keeping app active

**Alternatives Considered**:
1. **Pure AppKit (NSMenu, NSViewController)** - Rejected: More code, no declarative UI benefits, harder to maintain
2. **MenuBarExtra (SwiftUI 4.0)** - Rejected: macOS 13+ only, less control over popover presentation, limited customization
3. **SwiftUI Menu + Window** - Rejected: Cannot control menu bar icon color dynamically, no status bar integration

**Implementation Pattern**:
```swift
@main
struct Liuli_ServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup - LSUIElement app has no windows at launch
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Bridge")
        // Attach popover with SwiftUI content
    }
}
```

**Key References**:
- [Apple Human Interface Guidelines: Menu Bar Extras](https://developer.apple.com/design/human-interface-guidelines/macos/extensions/menu-bar-extras/)
- [SwiftUI + AppKit Integration Guide](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)

---

### 4. Charles Proxy Detection Strategy

**Decision**: Two-stage detection (process check + TCP connection)

**Rationale**:
- `pgrep Charles` or `NSWorkspace.runningApplications` detects if Charles is launched
- TCP socket connect to localhost:8888 verifies Charles proxy port is listening
- Two-stage approach avoids false positives (process running but port unavailable)
- Exponential backoff (1s/2s/4s, max 5 attempts) prevents tight retry loops

**Alternatives Considered**:
1. **Process check only** - Rejected: Charles may be running but proxy disabled or port changed
2. **TCP check only** - Rejected: Any app could occupy port 8888, would forward to wrong proxy
3. **HTTP OPTIONS request** - Rejected: Overhead unnecessary, TCP connection sufficient

**Implementation Pattern**:
```swift
actor CharlesDetector {
    func detect(host: String, port: Int) async -> CharlesProxyStatus {
        // Stage 1: Check process
        guard isCharlesProcessRunning() else {
            return .unreachable(reason: "Charles process not found")
        }

        // Stage 2: TCP connect with 2-second timeout
        do {
            let socket = try await NIOClientTCPBootstrap.connect(host: host, port: port,
                                                                   timeout: .seconds(2))
            try await socket.close()
            return .reachable(lastCheck: Date())
        } catch {
            return .unreachable(reason: "Port \(port) not accepting connections")
        }
    }

    private func isCharlesProcessRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == "Charles" || $0.bundleIdentifier == "com.xk72.charles"
        }
    }
}
```

**Key References**:
- [NSWorkspace Running Applications](https://developer.apple.com/documentation/appkit/nsworkspace/1534810-runningapplications)
- [TCP Connection Testing Pattern](https://github.com/apple/swift-nio/tree/main/Sources/NIOCore)

---

### 5. Configuration Persistence (UserDefaults)

**Decision**: Codable structs stored in UserDefaults with JSON encoding

**Rationale**:
- UserDefaults is standard macOS persistence for app preferences
- Codable provides type-safe encoding/decoding (no manual dictionary manipulation)
- JSONEncoder ensures forward compatibility (can add fields without migration)
- Atomic writes (UserDefaults synchronizes automatically)

**Alternatives Considered**:
1. **Property list files (.plist)** - Rejected: Manual file I/O, no automatic synchronization
2. **SwiftData (CoreData successor)** - Rejected: Overkill for simple key-value storage, requires schema management
3. **Keychain** - Rejected: Only needed for secrets (Charles has no credentials in current spec)

**Implementation Pattern**:
```swift
actor UserDefaultsConfigRepository: ConfigurationRepository {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() async throws -> ProxyConfiguration {
        guard let data = defaults.data(forKey: "proxyConfig") else {
            return ProxyConfiguration.default  // FR-043: Provide defaults
        }
        return try decoder.decode(ProxyConfiguration.self, from: data)
    }

    func save(_ config: ProxyConfiguration) async throws {
        let data = try encoder.encode(config)
        defaults.set(data, forKey: "proxyConfig")
    }
}
```

**Key References**:
- [UserDefaults Best Practices](https://developer.apple.com/documentation/foundation/userdefaults)
- [Codable Swift Documentation](https://developer.apple.com/documentation/swift/codable)

---

### 6. Logging Strategy (OSLog)

**Decision**: Use unified logging (os_log) with structured metadata

**Rationale**:
- Native macOS logging integrated with Console.app
- Supports log levels (debug, info, warning, error, fault)
- Structured data (e.g., sourceIP, destHost) queryable in Console.app
- Privacy redaction built-in (automatic PII masking)
- Zero external dependencies

**Alternatives Considered**:
1. **SwiftLog** - Rejected: Designed for server-side Swift, unnecessary layer for macOS GUI app
2. **CocoaLumberjack** - Rejected: Legacy Objective-C API, OSLog is modern replacement
3. **print() statements** - Rejected: No log levels, no persistence, not production-ready

**Implementation Pattern**:
```swift
import OSLog

extension Logger {
    static let network = Logger(subsystem: "com.liuli.server", category: "network")
    static let service = Logger(subsystem: "com.liuli.server", category: "service")
}

// Usage
Logger.network.info("Accepted SOCKS5 connection from \(sourceIP, privacy: .public)")
Logger.network.error("Charles proxy unreachable: \(error.localizedDescription)")
```

**Key References**:
- [Apple Logging Documentation](https://developer.apple.com/documentation/os/logging)
- [WWDC 2020: Explore Logging in Swift](https://developer.apple.com/videos/play/wwdc2020/10168/)

---

### 7. IP Address Validation (RFC 1918 + Link-Local)

**Decision**: Custom validation using CIDR range checks

**Rationale**:
- RFC 1918 private IP ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- Link-local addresses: 169.254.0.0/16 (IPv4), fe80::/10 (IPv6)
- Bitwise operations for efficient CIDR matching
- Reject all other sources to prevent internet exposure (security requirement)

**Alternatives Considered**:
1. **Regex matching** - Rejected: Slower, error-prone for CIDR ranges, no IPv6 support
2. **String-based checks** - Rejected: Fragile, doesn't handle /12 or /10 subnets correctly
3. **No validation** - Rejected: Security risk (exposes SOCKS5 to internet)

**Implementation Pattern**:
```swift
extension IPAddress {
    func isPrivateOrLinkLocal() -> Bool {
        switch self {
        case .v4(let addr):
            let octets = addr.address
            // 10.0.0.0/8
            if octets.0 == 10 { return true }
            // 172.16.0.0/12
            if octets.0 == 172 && (octets.1 >= 16 && octets.1 <= 31) { return true }
            // 192.168.0.0/16
            if octets.0 == 192 && octets.1 == 168 { return true }
            // 169.254.0.0/16 (link-local)
            if octets.0 == 169 && octets.1 == 254 { return true }
            return false

        case .v6(let addr):
            // fe80::/10 (link-local)
            return addr.address.0 == 0xfe && (addr.address.1 & 0xc0) == 0x80
        }
    }
}
```

**Key References**:
- [RFC 1918: Address Allocation for Private Internets](https://datatracker.ietf.org/doc/html/rfc1918)
- [RFC 3927: Link-Local IPv4 Addressing](https://datatracker.ietf.org/doc/html/rfc3927)
- [RFC 4291: IPv6 Addressing Architecture](https://datatracker.ietf.org/doc/html/rfc4291#section-2.5.6)

---

### 8. HTTP CONNECT Tunneling for HTTPS

**Decision**: Parse CONNECT requests and establish bidirectional pipes

**Rationale**:
- HTTPS traffic (port 443) requires HTTP CONNECT method per RFC 7231
- Charles expects CONNECT for TLS inspection (SSL Proxying feature)
- HTTP/1.1 plain text parsing (simpler than full HTTP/2 parser)
- Bidirectional NIO ByteBuffers for efficient forwarding (zero-copy where possible)

**Alternatives Considered**:
1. **TLS termination in Liuli-Server** - Rejected: Defeats purpose (want Charles to decrypt), requires CA cert trust
2. **SOCKS5 BIND command** - Rejected: Not supported by iOS VPN clients, CONNECT is standard
3. **Transparent TCP forwarding** - Rejected: Charles won't recognize traffic as proxy requests

**Implementation Pattern**:
```swift
// Simplified CONNECT handling
func handleCONNECT(request: HTTPServerRequestPart, context: ChannelHandlerContext) {
    guard case .head(let head) = request else { return }

    // Parse CONNECT example.com:443 HTTP/1.1
    let targetHost = head.uri.split(separator: ":")[0]
    let targetPort = Int(head.uri.split(separator: ":")[1]) ?? 443

    // Connect to Charles
    let charlesBootstrap = ClientBootstrap(group: context.eventLoop)
        .connect(host: "127.0.0.1", port: 8888)

    charlesBootstrap.whenSuccess { charlesChannel in
        // Send CONNECT request to Charles
        charlesChannel.writeAndFlush(request)
        // Establish bidirectional forwarding
        setupPipe(ios: context.channel, charles: charlesChannel)
    }
}
```

**Key References**:
- [RFC 7231: HTTP CONNECT Method](https://datatracker.ietf.org/doc/html/rfc7231#section-4.3.6)
- [Charles Proxy Documentation: External Proxy Configuration](https://www.charlesproxy.com/documentation/proxying/)

---

### 9. Idle Connection Timeout (60 seconds)

**Decision**: SwiftNIO IdleStateHandler with custom timeout action

**Rationale**:
- Many mobile apps hold connections open indefinitely (WebSockets, long-polling)
- 60-second idle timeout (FR-032) prevents resource exhaustion
- IdleStateHandler triggers event when no read/write for N seconds
- Graceful closure (send SOCKS5 teardown, then close socket)

**Alternatives Considered**:
1. **Manual Timer in repository** - Rejected: Must track per-connection timers, complex lifecycle management
2. **OS-level TCP keepalive** - Rejected: Operates at much longer timescales (hours), not application-level idle
3. **No timeout** - Rejected: Violates FR-032, allows connection exhaustion attack

**Implementation Pattern**:
```swift
channel.pipeline.addHandlers([
    IdleStateHandler(readTimeout: .seconds(60), writeTimeout: .seconds(60)),
    IdleStateChannelHandler()  // Custom handler to close on idle
])

final class IdleStateChannelHandler: ChannelInboundHandler {
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if event is IdleStateHandler.IdleStateEvent {
            Logger.network.info("Connection idle for 60s, closing: \(context.remoteAddress)")
            context.close(promise: nil)
        }
    }
}
```

**Key References**:
- [SwiftNIO IdleStateHandler](https://swiftpackageindex.com/apple/swift-nio/main/documentation/nioextras/idlestatehandler)

---

### 10. Exponential Backoff Retry (1s, 2s, 4s)

**Decision**: Capped exponential backoff with jitter

**Rationale**:
- Charles may restart temporarily (user updates settings)
- Exponential backoff prevents tight retry loops (server-friendly)
- Max 5 attempts (1s + 2s + 4s + 8s + 16s = 31s total before giving up)
- Jitter (±20%) prevents thundering herd if multiple connections fail simultaneously

**Alternatives Considered**:
1. **Fixed 1-second retry** - Rejected: Too aggressive, wastes CPU if Charles down for minutes
2. **Linear backoff (1s, 2s, 3s)** - Rejected: Doesn't scale well, still too frequent
3. **Immediate retry** - Rejected: Violates FR-039, creates tight loop

**Implementation Pattern**:
```swift
actor ExponentialBackoff {
    private var attemptCount = 0
    private let maxAttempts = 5
    private let baseDelay: TimeInterval = 1.0

    func nextDelay() -> TimeInterval? {
        guard attemptCount < maxAttempts else { return nil }
        let delay = baseDelay * pow(2.0, Double(attemptCount))
        let jitter = Double.random(in: 0.8...1.2)
        attemptCount += 1
        return delay * jitter
    }

    func reset() {
        attemptCount = 0
    }
}

// Usage
while let delay = backoff.nextDelay() {
    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    if try await charlesDetector.detect() == .reachable {
        backoff.reset()
        break
    }
}
```

**Key References**:
- [Exponential Backoff Algorithm (Google Cloud)](https://cloud.google.com/iot/docs/how-tos/exponential-backoff)

---

## Cross-Cutting Concerns

### Localization Strategy

**Decision**: Use String catalogs (Xcode 15+) for Chinese + English

**Rationale**:
- String catalogs replace legacy .strings files (better Xcode integration)
- Supports plural rules, variable interpolation, and context
- Build-time validation of localized strings
- CLAUDE.md specifies Chinese for user-facing UI

**Implementation**:
```swift
// Define in Localizable.xcstrings
Text("service.status.running")  // → "Service Running" (en) / "服务运行中" (zh-Hans)
Text("notification.charles.notFound")  // → "Charles not detected" (en) / "未检测到 Charles" (zh-Hans)
```

### Error Handling Pattern

**Decision**: Domain-specific error enums conforming to Error protocol

**Rationale**:
- Typed errors enable exhaustive switch in ViewModels
- Each layer defines its own error enum (no leaking implementation details)
- Repository errors mapped to domain errors at layer boundary

**Implementation**:
```swift
// Domain layer
public enum BridgeServiceError: Error, Sendable {
    case portInUse(Int)
    case bonjourRegistrationFailed(String)
    case charlesUnreachable
}

// Data layer
enum SOCKS5ServerError: Error {
    case bindFailed(SocketAddress)
    case invalidSOCKSVersion(UInt8)
}

// Mapping at repository boundary
func start() async throws {
    do {
        try await nioBootstrap.bind(host: "0.0.0.0", port: config.port)
    } catch let error as SOCKS5ServerError {
        throw BridgeServiceError.portInUse(config.port)  // Map to domain error
    }
}
```

---

## Summary of Resolved Unknowns

| Original Unknown | Resolution |
|------------------|------------|
| SOCKS5 implementation choice | SwiftNIO 2.60+ with custom channel handlers |
| Bonjour library | Foundation NetService (native) |
| Menu bar framework | SwiftUI + AppKit hybrid (NSStatusItem + NSPopover) |
| Charles detection method | Two-stage: process check + TCP connection |
| Configuration storage | UserDefaults with Codable JSON encoding |
| Logging framework | OSLog (unified logging) |
| IP validation approach | CIDR range checks for RFC 1918 + link-local |
| HTTPS forwarding method | HTTP CONNECT tunneling to Charles |
| Idle timeout mechanism | SwiftNIO IdleStateHandler (60s) |
| Retry strategy | Exponential backoff with jitter (1/2/4/8/16s, max 5) |

**All NEEDS CLARIFICATION items resolved. Ready for Phase 1 (data model and contracts generation).**
