import Foundation

/// SOCKS5 protocol error codes per RFC 1928 (FR-016)
public enum SOCKS5ErrorCode: UInt8, Sendable, Codable, Equatable, Error {
    /// 0x00 - Request granted (success)
    case success = 0x00

    /// 0x01 - General SOCKS server failure
    case generalFailure = 0x01

    /// 0x02 - Connection not allowed by ruleset
    case connectionNotAllowed = 0x02

    /// 0x03 - Network unreachable
    case networkUnreachable = 0x03

    /// 0x04 - Host unreachable (also used for DNS failures per FR-015)
    case hostUnreachable = 0x04

    /// 0x05 - Connection refused (used when Charles is unreachable per FR-021)
    case connectionRefused = 0x05

    /// 0x06 - TTL expired
    case ttlExpired = 0x06

    /// 0x07 - Command not supported
    case commandNotSupported = 0x07

    /// 0x08 - Address type not supported
    case addressTypeNotSupported = 0x08

    public var localizedDescription: String {
        switch self {
        case .success: return "Request granted"
        case .generalFailure: return "General SOCKS server failure"
        case .connectionNotAllowed: return "Connection not allowed"
        case .networkUnreachable: return "Network unreachable"
        case .hostUnreachable: return "Host unreachable"
        case .connectionRefused: return "Connection refused"
        case .ttlExpired: return "TTL expired"
        case .commandNotSupported: return "Command not supported"
        case .addressTypeNotSupported: return "Address type not supported"
        }
    }
}
