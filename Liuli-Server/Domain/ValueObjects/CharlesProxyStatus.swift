import Foundation

/// Charles Proxy availability status (FR-036 to FR-040)
public enum CharlesProxyStatus: Sendable, Equatable {
    /// Charles is reachable at the configured address
    case reachable(host: String, port: UInt16)

    /// Charles is unreachable
    case unreachable(host: String, port: UInt16, error: String)

    /// Charles availability is unknown (not yet checked)
    case unknown

    public var isReachable: Bool {
        if case .reachable = self {
            return true
        }
        return false
    }

    public var host: String {
        switch self {
        case .reachable(let host, _), .unreachable(let host, _, _):
            return host
        case .unknown:
            return "localhost"
        }
    }

    public var port: UInt16 {
        switch self {
        case .reachable(_, let port), .unreachable(_, let port, _):
            return port
        case .unknown:
            return 8888
        }
    }
}
