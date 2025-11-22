import Foundation
import Network

/// IP address validation for RFC 1918 private ranges and link-local addresses (FR-011)
extension String {
    /// Check if IP address is from allowed local network ranges
    /// - Returns: true if IP is RFC 1918 or link-local, false otherwise
    public func isLocalNetworkAddress() -> Bool {
        // Try to parse as IPv4
        if let ipv4 = IPv4Address(self) {
            return ipv4.isRFC1918() || ipv4.isLinkLocal()
        }

        // Try to parse as IPv6
        if let ipv6 = IPv6Address(self) {
            return ipv6.isLinkLocal()
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
        let bytes = rawValue.bigEndian

        let octet1 = UInt8((bytes >> 24) & 0xFF)
        let octet2 = UInt8((bytes >> 16) & 0xFF)

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
        let bytes = rawValue.bigEndian
        let octet1 = UInt8((bytes >> 24) & 0xFF)
        let octet2 = UInt8((bytes >> 16) & 0xFF)

        return octet1 == 169 && octet2 == 254
    }
}

extension IPv6Address {
    /// Check if IPv6 address is link-local (fe80::/10)
    public func isLinkLocal() -> Bool {
        let bytes = self.rawValue
        // Link-local IPv6 starts with fe80
        return bytes.0 == 0xfe && (bytes.1 & 0xc0) == 0x80
    }
}
