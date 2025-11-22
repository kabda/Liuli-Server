import Foundation
import Network

/// IP address validation for RFC 1918 private ranges and link-local addresses (FR-011)
extension String {
    /// Check if IP address is from allowed local network ranges
    /// - Returns: true if IP is RFC 1918, link-local, or loopback, false otherwise
    nonisolated public func isLocalNetworkAddress() -> Bool {
        // Try to parse as IPv4
        if let ipv4 = IPv4Address(self) {
            return ipv4.isRFC1918() || ipv4.isLinkLocal() || ipv4.isLoopback()
        }

        // Try to parse as IPv6
        if let ipv6 = IPv6Address(self) {
            return ipv6.isLinkLocal() || ipv6.isLoopback()
        }

        return false
    }
}

extension IPv4Address {
    /// Check if IPv4 address is in RFC 1918 private ranges
    /// - 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)
    /// - 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
    /// - 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)
    public func isRFC1918() -> Bool {
        let bytes = withUnsafeBytes(of: self.rawValue) { Array($0) }
        guard bytes.count >= 2 else { return false }

        let octet1 = bytes[0]
        let octet2 = bytes[1]

        // 10.0.0.0/8
        if octet1 == 10 {
            return true
        }

        // 172.16.0.0/12
        if octet1 == 172 && (octet2 >= 16 && octet2 <= 31) {
            return true
        }

        // 192.168.0.0/16
        if octet1 == 192 && octet2 == 168 {
            return true
        }

        return false
    }

    /// Check if IPv4 address is link-local (169.254.0.0/16)
    public func isLinkLocal() -> Bool {
        let bytes = withUnsafeBytes(of: self.rawValue) { Array($0) }
        guard bytes.count >= 2 else { return false }

        let octet1 = bytes[0]
        let octet2 = bytes[1]

        return octet1 == 169 && octet2 == 254
    }

    /// Check if IPv4 address is loopback (127.0.0.0/8)
    public func isLoopback() -> Bool {
        let bytes = withUnsafeBytes(of: self.rawValue) { Array($0) }
        guard bytes.count >= 1 else { return false }

        return bytes[0] == 127
    }
}

extension IPv6Address {
    /// Check if IPv6 address is link-local (fe80::/10)
    public func isLinkLocal() -> Bool {
        let bytes = withUnsafeBytes(of: rawValue) { Array($0) }
        // Link-local IPv6 starts with fe80
        return bytes.count >= 2 && bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
    }

    /// Check if IPv6 address is loopback (::1)
    public func isLoopback() -> Bool {
        let bytes = withUnsafeBytes(of: rawValue) { Array($0) }
        // ::1 is all zeros except the last byte
        guard bytes.count == 16 else { return false }
        for i in 0..<15 {
            if bytes[i] != 0 { return false }
        }
        return bytes[15] == 1
    }
}
