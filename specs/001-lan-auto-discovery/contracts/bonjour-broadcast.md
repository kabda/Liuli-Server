# mDNS/DNS-SD Service Broadcast Contract

**Feature**: 001-lan-auto-discovery
**Date**: 2025-11-23
**Protocol**: mDNS (RFC 6762) + DNS-SD (RFC 6763)

## Overview

This document specifies the mDNS/DNS-SD service advertisement format used by Liuli-Server to broadcast its availability on the local network.

---

## Service Type Registration

**Service Type**: `_liuli-proxy._tcp.local.`

Following RFC 6763 naming conventions:
- `_liuli-proxy`: Application protocol (Liuli proxy service)
- `_tcp`: Transport protocol (TCP for SOCKS5)
- `.local.`: mDNS domain (link-local)

**Service Name**: Server's device hostname (e.g., "John's MacBook Pro")

---

## TXT Record Schema

TXT records convey additional service metadata as key-value pairs.

### Required Fields

| Key | Type | Format | Description | Example |
|-----|------|--------|-------------|---------|
| `port` | integer | String representation | SOCKS5 proxy port (1024-65535) | `"9050"` |
| `version` | string | Semver (X.Y.Z) | Protocol version for compatibility | `"1.0.0"` |
| `device_id` | UUID | Hyphenated uppercase | Unique server identifier | `"550E8400-E29B-41D4-A716-446655440000"` |
| `bridge_status` | enum | `"active"` or `"inactive"` | Current bridge service status | `"active"` |
| `cert_hash` | hex string | SHA-256 (64 chars) | Certificate SPKI fingerprint for TOFU | `"A1B2C3D4..."` |

### Optional Fields

| Key | Type | Format | Description | Example |
|-----|------|--------|-------------|---------|
| `model` | string | Free text | Mac model identifier | `"MacBookPro18,1"` |
| `os_version` | string | Semver | macOS version | `"14.0.0"` |
| `max_clients` | integer | String representation | Maximum concurrent connections | `"10"` |

---

## Example mDNS Packet

### Service Announcement (PTR Record)

```dns
_liuli-proxy._tcp.local. PTR John's MacBook Pro._liuli-proxy._tcp.local.
```

### Service Record (SRV + A + TXT)

```dns
John's MacBook Pro._liuli-proxy._tcp.local. SRV 0 0 9050 johns-mbp.local.
johns-mbp.local. A 192.168.1.100
John's MacBook Pro._liuli-proxy._tcp.local. TXT "port=9050" "version=1.0.0" "device_id=550E8400-E29B-41D4-A716-446655440000" "bridge_status=active" "cert_hash=A1B2C3D4E5F6..."
```

---

## Broadcast Behavior

### Timing
- **Initial Announcement**: Immediate on bridge start (3 consecutive announcements 1 second apart)
- **Periodic Refresh**: Every 5 seconds while bridge is active
- **Goodbye Packet**: On bridge stop or application exit (TTL=0)

### TTL (Time To Live)
- **Active Service**: 120 seconds
- **Goodbye**: 0 seconds (immediate invalidation)

### Network Interface
- **Multicast**: 224.0.0.251 (IPv4) / FF02::FB (IPv6)
- **Port**: UDP 5353
- **Scope**: Link-local only (no routing beyond subnet)

---

## Client Discovery Process

### 1. Browse for Service Type
```
DNS-SD Browse Query: _liuli-proxy._tcp.local.
```

### 2. Receive PTR Record(s)
```
Response: John's MacBook Pro._liuli-proxy._tcp.local.
```

### 3. Resolve Service Name
```
DNS-SD Resolve Query: John's MacBook Pro._liuli-proxy._tcp.local.
```

### 4. Receive SRV + A + TXT Records
```
SRV: johns-mbp.local. port 9050
A: 192.168.1.100
TXT: [key-value pairs]
```

### 5. Parse TXT Record
Extract metadata:
- Proxy port: `9050`
- Server ID: `550E8400-...`
- Bridge status: `active`
- Cert hash: `A1B2C3D4...`

### 6. Display in UI
Show server name, status, and allow user to connect.

---

## Platform-Specific Implementation

### macOS Server (NetService)

```swift
let txtRecord: [String: Data] = [
    "port": "9050".data(using: .utf8)!,
    "version": "1.0.0".data(using: .utf8)!,
    "device_id": "550E8400-E29B-41D4-A716-446655440000".data(using: .utf8)!,
    "bridge_status": "active".data(using: .utf8)!,
    "cert_hash": "A1B2C3D4E5F6...".data(using: .utf8)!
]

let service = NetService(domain: "local.", type: "_liuli-proxy._tcp.", name: "", port: 9050)
service.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
service.publish()
```

### iOS Client (Network.framework)

```swift
let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_liuli-proxy._tcp", domain: "local."), using: .tcp)

browser.browseResultsChangedHandler = { results, changes in
    for result in results {
        if case .service(let name, let type, let domain, let interface) = result.endpoint {
            // Extract TXT record from result
            let txtRecord = result.txtRecord  // [String: Data]
            let port = String(data: txtRecord["port"]!, encoding: .utf8)!
            let deviceID = UUID(uuidString: String(data: txtRecord["device_id"]!, encoding: .utf8)!)!
            // ... parse other fields
        }
    }
}

browser.start(queue: .main)
```

### Android Client (JmDNS)

```kotlin
val jmdns = JmDNS.create(getLocalIPAddress())

jmdns.addServiceListener("_liuli-proxy._tcp.local.", object : ServiceListener {
    override fun serviceResolved(event: ServiceEvent) {
        val info = event.info
        val port = info.getPropertyString("port")?.toInt() ?: return
        val deviceID = UUID.fromString(info.getPropertyString("device_id"))
        val bridgeStatus = info.getPropertyString("bridge_status")
        val certHash = info.getPropertyString("cert_hash")
        // ... handle discovered server
    }
})
```

---

## Error Handling

### Client-Side

| Condition | Behavior |
|-----------|----------|
| No services found | Display "No servers found" + manual config option |
| Service found but bridge_status=inactive | Show server as "Unavailable" in list |
| Service disappears (TTL expired) | Remove from list after 15 seconds |
| TXT record parsing fails | Skip invalid service, log warning |
| Duplicate service names | Append device_id suffix to disambiguate |

### Server-Side

| Condition | Behavior |
|-----------|----------|
| Port already in use | Fail to publish, log error, retry with next available port |
| Network interface down | Pause broadcast, resume on network up |
| Bridge stops | Send goodbye packet immediately (TTL=0) |
| Application crashes | OS sends goodbye automatically (NetService cleanup) |

---

## Security Considerations

### Information Disclosure
- **Exposed**: Device name, IP address, port, server ID
- **Not Exposed**: VPN credentials, traffic content, user identities
- **Mitigation**: Local network only (RFC 1918), no internet exposure

### Spoofing Prevention
- mDNS broadcasts are unauthenticated (by design)
- Rely on TOFU certificate pinning during connection for server identity verification
- Clients MUST validate `cert_hash` matches actual server certificate

### Denial of Service
- Clients should rate-limit service resolution (max 1 resolve/sec per service)
- Servers should enforce max 10 concurrent connections to prevent resource exhaustion

---

## Compatibility Matrix

| Server Version | iOS Min | Android Min | Changes |
|----------------|---------|-------------|---------|
| 1.0.0 | 1.0.0 | 1.0.0 | Initial release |
| 1.1.0 | 1.0.0 | 1.0.0 | Add optional `max_clients` field (backward compatible) |

**Versioning Rule**: Increment protocol version on backward-incompatible changes (required field added/removed/renamed).

---

## Testing

### Manual Testing (macOS)

```bash
# Browse for services
dns-sd -B _liuli-proxy._tcp local.

# Resolve specific service
dns-sd -L "John's MacBook Pro" _liuli-proxy._tcp local.

# Monitor TXT record
dns-sd -Q "John's MacBook Pro._liuli-proxy._tcp.local." TXT local.
```

### Automated Testing

```swift
func testServiceBroadcast() async throws {
    let service = NetService(domain: "local.", type: "_liuli-proxy._tcp.", name: "Test Server", port: 9050)
    service.setTXTRecord(NetService.data(fromTXTRecord: [
        "port": "9050",
        "version": "1.0.0",
        "device_id": UUID().uuidString,
        "bridge_status": "active",
        "cert_hash": String(repeating: "A", count: 64)
    ]))

    let published = expectation(description: "Service published")
    let delegate = TestNetServiceDelegate()
    delegate.onPublish = { published.fulfill() }

    service.delegate = delegate
    service.publish()

    await fulfillment(of: [published], timeout: 5.0)

    // Verify service is discoverable
    let browser = NetServiceBrowser()
    let found = expectation(description: "Service found")
    let browserDelegate = TestBrowserDelegate()
    browserDelegate.onServiceFound = { name in
        if name == "Test Server" {
            found.fulfill()
        }
    }
    browser.delegate = browserDelegate
    browser.searchForServices(ofType: "_liuli-proxy._tcp.", inDomain: "local.")

    await fulfillment(of: [found], timeout: 10.0)
}
```

---

**Document Status**: ✅ Complete
**Related**: [heartbeat-protocol.md](./heartbeat-protocol.md), [tofu-handshake.md](./tofu-handshake.md)
