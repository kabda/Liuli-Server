# SOCKS5 Protocol Wire Format (RFC 1928)

**Feature**: iOS VPN Traffic Bridge to Charles
**Date**: 2025-11-22
**Purpose**: Document SOCKS5 protocol implementation for SwiftNIO channel handlers

## Reference

- [RFC 1928: SOCKS Protocol Version 5](https://datatracker.ietf.org/doc/html/rfc1928)
- [RFC 1929: Username/Password Authentication for SOCKS V5](https://datatracker.ietf.org/doc/html/rfc1929) (NOT IMPLEMENTED - we use 0x00 No Auth only)

## Supported Features

| Feature | Support | FR Reference |
|---------|---------|--------------|
| SOCKS5 version | ✅ Version 5 only | FR-007 |
| Authentication | ✅ 0x00 (No Auth) only | FR-008 |
| Commands | ✅ CONNECT (0x01), UDP ASSOCIATE (0x03) | FR-009, FR-010 |
| Address Types | ✅ IPv4 (0x01), IPv6 (0x04), Domain (0x03) | FR-013, FR-014, FR-015 |
| DNS Resolution | ✅ Server-side (return 0x04 on failure) | FR-015 |

## Handshake Sequence

```
iOS Client                 Liuli-Server               Charles Proxy
    │                           │                           │
    │──(1) Auth Methods─────────>│                           │
    │<─(2) Selected Method───────│                           │
    │──(3) Connect Request───────>│                           │
    │                           │──HTTP CONNECT────────────>│
    │                           │<─200 Connection Established│
    │<─(4) Connect Reply─────────│                           │
    │                           │                           │
    │══(5) Data Forwarding══════>│═══════════════════════════>│
    │<══════════════════════════│<═══════════════════════════│
```

## Message Formats

### 1. Client Authentication Methods (iOS → Server)

**Byte Layout**:
```
+----+----------+----------+
|VER | NMETHODS | METHODS  |
+----+----------+----------+
| 1  |    1     | 1 to 255 |
+----+----------+----------+
```

**Fields**:
- `VER`: SOCKS version (0x05 for SOCKS5)
- `NMETHODS`: Number of method bytes
- `METHODS`: Array of authentication methods (0x00 = No Auth, 0x02 = Username/Password)

**Example**:
```
05 01 00  // SOCKS5, 1 method, No Auth
```

**SwiftNIO Parsing**:
```swift
struct SOCKS5AuthRequest {
    let version: UInt8     // Must be 0x05
    let methods: [UInt8]   // Must contain 0x00

    static func parse(buffer: inout ByteBuffer) -> SOCKS5AuthRequest? {
        guard let version = buffer.readInteger(as: UInt8.self), version == 0x05 else {
            return nil
        }
        guard let methodCount = buffer.readInteger(as: UInt8.self) else {
            return nil
        }
        guard let methods = buffer.readBytes(length: Int(methodCount)) else {
            return nil
        }
        return SOCKS5AuthRequest(version: version, methods: methods)
    }
}
```

---

### 2. Server Auth Method Selection (Server → iOS)

**Byte Layout**:
```
+----+--------+
|VER | METHOD |
+----+--------+
| 1  |   1    |
+----+--------+
```

**Fields**:
- `VER`: SOCKS version (0x05)
- `METHOD`: Selected method (0x00 = No Auth, 0xFF = No acceptable methods)

**Example**:
```
05 00  // SOCKS5, No Auth selected
```

**SwiftNIO Writing**:
```swift
func sendAuthResponse(context: ChannelHandlerContext) {
    var buffer = context.channel.allocator.buffer(capacity: 2)
    buffer.writeInteger(UInt8(0x05))  // SOCKS5
    buffer.writeInteger(UInt8(0x00))  // No Auth
    context.writeAndFlush(NIOAny(buffer), promise: nil)
}
```

---

### 3. Connect Request (iOS → Server)

**Byte Layout**:
```
+----+-----+-------+------+----------+----------+
|VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | 0x00  |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+
```

**Fields**:
- `VER`: SOCKS version (0x05)
- `CMD`: Command code
  - 0x01 = CONNECT (TCP)
  - 0x03 = UDP ASSOCIATE
- `RSV`: Reserved (must be 0x00)
- `ATYP`: Address type
  - 0x01 = IPv4 (4 bytes)
  - 0x03 = Domain name (1 byte length + domain)
  - 0x04 = IPv6 (16 bytes)
- `DST.ADDR`: Destination address (format depends on ATYP)
- `DST.PORT`: Destination port (2 bytes, network byte order)

**Examples**:
```
// IPv4: example.com (93.184.216.34) port 443
05 01 00 01 5D B8 D8 22 01 BB

// Domain: example.com port 443
05 01 00 03 0B 65 78 61 6D 70 6C 65 2E 63 6F 6D 01 BB
          ↑  ↑─────────────────────────────────┘
       length     "example.com" (11 bytes)

// IPv6: 2001:db8::1 port 8080
05 01 00 04 20010DB8000000000000000000000001 1F90
```

**SwiftNIO Parsing**:
```swift
struct SOCKS5ConnectRequest {
    enum Address {
        case ipv4(SocketAddress)
        case ipv6(SocketAddress)
        case domain(String, port: UInt16)
    }

    let command: UInt8
    let address: Address

    static func parse(buffer: inout ByteBuffer) throws -> SOCKS5ConnectRequest {
        guard buffer.readInteger(as: UInt8.self) == 0x05 else {
            throw SOCKS5ErrorCode.generalFailure
        }
        guard let command = buffer.readInteger(as: UInt8.self) else {
            throw SOCKS5ErrorCode.generalFailure
        }
        _ = buffer.readInteger(as: UInt8.self)  // Skip reserved byte

        guard let addressType = buffer.readInteger(as: UInt8.self) else {
            throw SOCKS5ErrorCode.generalFailure
        }

        let address: Address
        switch addressType {
        case 0x01:  // IPv4
            guard let ipv4Bytes = buffer.readBytes(length: 4),
                  let port = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                throw SOCKS5ErrorCode.generalFailure
            }
            address = .ipv4(try SocketAddress(ipAddress: formatIPv4(ipv4Bytes), port: Int(port)))

        case 0x03:  // Domain
            guard let domainLength = buffer.readInteger(as: UInt8.self),
                  let domainBytes = buffer.readBytes(length: Int(domainLength)),
                  let domain = String(bytes: domainBytes, encoding: .utf8),
                  let port = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                throw SOCKS5ErrorCode.generalFailure
            }
            address = .domain(domain, port: port)

        case 0x04:  // IPv6
            guard let ipv6Bytes = buffer.readBytes(length: 16),
                  let port = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                throw SOCKS5ErrorCode.generalFailure
            }
            address = .ipv6(try SocketAddress(ipAddress: formatIPv6(ipv6Bytes), port: Int(port)))

        default:
            throw SOCKS5ErrorCode.addressTypeNotSupported
        }

        return SOCKS5ConnectRequest(command: command, address: address)
    }
}
```

---

### 4. Connect Reply (Server → iOS)

**Byte Layout**:
```
+----+-----+-------+------+----------+----------+
|VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
+----+-----+-------+------+----------+----------+
| 1  |  1  | 0x00  |  1   | Variable |    2     |
+----+-----+-------+------+----------+----------+
```

**Fields**:
- `VER`: SOCKS version (0x05)
- `REP`: Reply field (error codes from SOCKS5ErrorCode enum)
  - 0x00 = Succeeded
  - 0x01 = General server failure (FR-016)
  - 0x04 = Host unreachable (DNS failure, FR-015)
  - 0x05 = Connection refused (FR-016)
- `RSV`: Reserved (must be 0x00)
- `ATYP`: Address type (same as request)
- `BND.ADDR`: Server bound address (usually 0.0.0.0)
- `BND.PORT`: Server bound port (usually 0 or actual bind port)

**Success Example**:
```
05 00 00 01 00 00 00 00 00 00  // Success, IPv4 0.0.0.0:0
```

**Error Example**:
```
05 04 00 01 00 00 00 00 00 00  // Host unreachable (DNS failure)
```

**SwiftNIO Writing**:
```swift
func sendConnectReply(context: ChannelHandlerContext, status: SOCKS5ErrorCode) {
    var buffer = context.channel.allocator.buffer(capacity: 10)
    buffer.writeInteger(UInt8(0x05))       // SOCKS5
    buffer.writeInteger(status.rawValue)   // Reply code
    buffer.writeInteger(UInt8(0x00))       // Reserved
    buffer.writeInteger(UInt8(0x01))       // IPv4 address type
    buffer.writeInteger(UInt32(0))         // 0.0.0.0 (4 bytes)
    buffer.writeInteger(UInt16(0))         // Port 0
    context.writeAndFlush(NIOAny(buffer), promise: nil)
}
```

---

## Data Forwarding (Step 5)

After successful handshake, all subsequent data is raw TCP forwarding:

```
iOS Client ════ Liuli-Server ════ Charles Proxy
           raw bytes        raw bytes
```

**No SOCKS5 framing** - just bidirectional byte streams.

**SwiftNIO Handler**:
```swift
final class ForwardingHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let charlesChannel: Channel

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let buffer = unwrapInboundIn(data)
        // Forward iOS → Charles
        charlesChannel.writeAndFlush(buffer, promise: nil)
    }
}
```

---

## Error Handling Matrix

| Scenario | SOCKS5 Error Code | FR Reference |
|----------|-------------------|--------------|
| Server internal error | 0x01 (General failure) | FR-016 |
| Non-RFC 1918 source IP | Close socket immediately (no reply) | FR-011 |
| DNS resolution fails | 0x04 (Host unreachable) | FR-015 |
| TCP connection refused | 0x05 (Connection refused) | FR-016, FR-021 |
| Charles unreachable | 0x05 (Connection refused) | FR-021 |
| Unsupported command | 0x07 (Command not supported) | FR-009, FR-010 |
| Idle timeout (60s) | Close socket gracefully | FR-032 |

---

## Implementation Checklist

- [ ] Parse all address types (IPv4, IPv6, Domain)
- [ ] Perform DNS resolution for domain names (server-side)
- [ ] Return 0x04 on DNS failures (not 0x01)
- [ ] Return 0x05 when Charles unreachable
- [ ] Reject non-RFC 1918 source IPs at socket accept
- [ ] Support CONNECT (0x01) command
- [ ] Support UDP ASSOCIATE (0x03) command (optional, low priority)
- [ ] Implement 60-second idle timeout with IdleStateHandler
- [ ] Log all connections to OSLog (source IP, dest, bytes)
- [ ] Track bytes transferred for statistics
