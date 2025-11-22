# Bonjour/mDNS Service Advertisement

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Purpose**: Document Bonjour service configuration for iOS device discovery (zero-configuration networking)

## Reference

- [RFC 6763: DNS-Based Service Discovery](https://datatracker.ietf.org/doc/html/rfc6763)
- [Apple Bonjour Overview](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Introduction.html)

## Service Configuration

### Service Type

**Format**: `_<service>._<transport>.<domain>`

| Parameter | Value | FR Reference |
|-----------|-------|--------------|
| Service | `charles-bridge` | Custom service name |
| Transport | `tcp` | SOCKS5 uses TCP | FR-009 |
| Domain | `local.` | mDNS local domain | FR-001 |

**Full Service Type**: `_charles-bridge._tcp.local.`

### Service Name

**Source**: Mac device hostname (e.g., "MacBook-Pro", "Mac-Mini")

**API**: `Host.current().localizedName ?? "Liuli-Server"`

**FR Reference**: FR-002

**Example**: If hostname is "John's MacBook Pro", service name will be "John's MacBook Pro"

### Port Number

**Source**: User-configured SOCKS5 port from `ProxyConfiguration.socks5Port`

**Default**: 9000

**Range**: 1024-65535 (validated per FR-044)

### TXT Record (Metadata)

**Format**: Key-value pairs (DNS TXT record format)

| Key | Value Example | Description | FR Reference |
|-----|---------------|-------------|--------------|
| `version` | `"1.0.0"` | App version string | FR-003 |
| `port` | `"9000"` | SOCKS5 port (redundant but useful) | FR-003 |
| `device` | `"MacBookPro18,1"` | Hardware model identifier | FR-003 |

**Getting Hardware Model**:
```swift
import Foundation

func getHardwareModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}
```

**Example TXT Record**:
```swift
let txtRecord: [String: Data] = [
    "version": "1.0.0".data(using: .utf8)!,
    "port": "9000".data(using: .utf8)!,
    "device": "MacBookPro18,1".data(using: .utf8)!
]
```

---

## iOS Discovery Process

### 1. iOS Liuli VPN App Browses for Services

```swift
// iOS side (for reference)
let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_charles-bridge._tcp", domain: "local."), using: .tcp)
browser.browseResultsChangedHandler = { results, changes in
    for result in results {
        if case .service(let name, let type, let domain, let interface) = result.endpoint {
            print("Found Mac: \(name)")
            // Resolve to get IP address and port
        }
    }
}
browser.start(queue: .main)
```

### 2. iOS Resolves Service to IP + Port

Bonjour automatically resolves:
- Mac's IP address (e.g., 192.168.1.5)
- SOCKS5 port (e.g., 9000)

**No manual configuration needed** - this is the "zero-configuration" aspect (FR-002, SC-002).

### 3. iOS Connects to SOCKS5 Server

```
iOS VPN ──SOCKS5──> 192.168.1.5:9000 (Mac Liuli-Server)
```

---

## Foundation NetService Implementation

### Publishing Service

```swift
import Foundation

actor BonjourPublisher {
    private var netService: NetService?
    private var delegate: BonjourServiceDelegate?

    func publish(name: String, port: Int, txtRecord: [String: String]) async throws {
        let service = NetService(domain: "local.", type: "_charles-bridge._tcp.", name: name, port: Int32(port))

        // Convert txtRecord to Data
        let txtData = NetService.data(fromTXTRecord: txtRecord.mapValues { $0.data(using: .utf8)! })
        service.setTXTRecord(txtData)

        // Set delegate for callbacks
        let delegate = BonjourServiceDelegate()
        service.delegate = delegate
        self.delegate = delegate

        // Publish service
        service.publish(options: [.listenForConnections])

        // Wait for publication confirmation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delegate.onPublished = {
                continuation.resume()
            }
            delegate.onError = { error in
                continuation.resume(throwing: error)
            }
        }

        self.netService = service
    }

    func unpublish() async {
        netService?.stop()
        netService = nil
    }
}

class BonjourServiceDelegate: NSObject, NetServiceDelegate {
    var onPublished: (() -> Void)?
    var onError: ((Error) -> Void)?

    func netServiceDidPublish(_ sender: NetService) {
        onPublished?()
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        let error = BridgeServiceError.bonjourRegistrationFailed(errorDict.description)
        onError?(error)
    }
}
```

---

## Network Interface Handling

### Automatic Re-advertisement (FR-005)

Bonjour automatically re-advertises when:
- Network interface changes (Wi-Fi ↔ Ethernet)
- IP address changes (DHCP lease renewal)
- Interface goes down and comes back up

**No manual intervention required** - Foundation NetService handles this automatically.

### Multi-Interface Advertisement (FR-004)

**Default Behavior**: NetService advertises on ALL active network interfaces by default.

**Manual Control**: Use `NetService.publish(options: [])` without `.listenForConnections` to disable automatic interface selection, then manually specify interface:

```swift
// For specific interface only (not needed for this project)
service.publish(options: [])
service.schedule(in: .main, forMode: .default)  // Control scheduling manually
```

**For Liuli-Server**: Use default behavior (advertise on all interfaces) per FR-004.

---

## Testing Bonjour Service

### Command Line (macOS)

```bash
# Discover services
dns-sd -B _charles-bridge._tcp local.

# Resolve specific service
dns-sd -L "MacBook-Pro" _charles-bridge._tcp local.

# Query TXT record
dns-sd -Q "MacBook-Pro._charles-bridge._tcp.local." TXT
```

**Expected Output**:
```
Browsing for _charles-bridge._tcp.local.
Timestamp     A/R Flags if Domain               Service Type         Instance Name
14:23:45.123  Add  2    4  local.               _charles-bridge._tcp. MacBook-Pro

Lookup MacBook-Pro._charles-bridge._tcp.local.
14:23:46.456  MacBook-Pro._charles-bridge._tcp.local. can be reached at MacBook-Pro.local.:9000 (interface 4)
 version=1.0.0 port=9000 device=MacBookPro18,1
```

### iOS Simulator Testing

**Limitation**: Bonjour does NOT work in iOS Simulator (no network stack for mDNS).

**Solution**: Test on physical iOS device on same Wi-Fi network as Mac.

---

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| Service not appearing on iOS | Firewall blocking mDNS port 5353 | Disable firewall or allow mDNS |
| Service name conflicts | Multiple Macs with same hostname | NetService auto-appends "(2)" |
| Service disappears after 5s | Mac went to sleep | Re-advertise on wake (use NSWorkspace notifications) |
| TXT record not visible | TXT data > 255 bytes | Reduce TXT record size (DNS limit) |
| No discovery on Ethernet | mDNS disabled on interface | Enable mDNS in Network Preferences |

---

## Performance Considerations

### Advertisement Latency

- **Initial advertisement**: < 1 second
- **iOS discovery**: < 5 seconds (SC-002)
- **Re-advertisement after IP change**: < 5 seconds (SC-009, FR-005)

### Resource Usage

- **Memory**: < 100 KB (NetService overhead)
- **Network**: ~100 bytes every 5-10 seconds (mDNS keepalive)
- **CPU**: Negligible (handled by mDNSResponder system daemon)

---

## Security Considerations

### No Authentication in Bonjour

Bonjour itself has **no authentication or encryption**. Any device on the local network can discover the service.

**Mitigation**: FR-011 restricts SOCKS5 connections to RFC 1918 private IP ranges only, preventing internet-based attacks even if service is discovered.

### TXT Record Privacy

TXT record data is **visible to all devices on local network**. Do not include:
- Passwords or API keys
- User personal information
- System serial numbers or MAC addresses

**Safe Data**: App version, port number, generic device model are acceptable.

---

## Implementation Checklist

- [ ] Use `_charles-bridge._tcp.local.` as service type
- [ ] Get service name from `Host.current().localizedName`
- [ ] Include version, port, device in TXT record
- [ ] Advertise on all active interfaces (default behavior)
- [ ] Stop advertising when service stops (FR-006)
- [ ] Handle NetService delegate errors
- [ ] Re-advertise automatically on network changes (Foundation does this)
- [ ] Test with `dns-sd` command line tool
- [ ] Test with physical iOS device (Simulator won't work)
- [ ] Log advertisement success/failure to OSLog
