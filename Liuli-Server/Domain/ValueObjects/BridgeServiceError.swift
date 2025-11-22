import Foundation

/// Domain-level errors for bridge service operations
public enum BridgeServiceError: Error, Sendable, Equatable {
    /// Port is already in use (FR-046)
    case portInUse(port: UInt16)

    /// Charles Proxy is not reachable (FR-046)
    case charlesUnreachable(host: String, port: UInt16)

    /// Network interface is unavailable (FR-046)
    case networkInterfaceUnavailable

    /// Bonjour service registration failed (FR-046)
    case bonjourRegistrationFailed(reason: String)

    /// Service start failed
    case serviceStartFailed(reason: String)

    /// Service stop failed
    case serviceStopFailed(reason: String)

    /// Invalid configuration
    case invalidConfiguration(reason: String)

    /// Connection limit reached (FR-012: max 100 concurrent)
    case connectionLimitReached

    /// DNS resolution failed (FR-015)
    case dnsResolutionFailed(domain: String)

    /// Memory limit exceeded (edge case)
    case memoryLimitExceeded

    public var localizedDescription: String {
        switch self {
        case .portInUse(let port):
            return String(format: NSLocalizedString("error.portInUse.message", comment: ""), port)
        case .charlesUnreachable(let host, let port):
            return "Charles Proxy unreachable at \(host):\(port)"
        case .networkInterfaceUnavailable:
            return NSLocalizedString("error.networkInterfaceUnavailable", comment: "")
        case .bonjourRegistrationFailed(let reason):
            return "Bonjour registration failed: \(reason)"
        case .serviceStartFailed(let reason):
            return "Service start failed: \(reason)"
        case .serviceStopFailed(let reason):
            return "Service stop failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .connectionLimitReached:
            return "Connection limit reached (max 100)"
        case .dnsResolutionFailed(let domain):
            return "DNS resolution failed for \(domain)"
        case .memoryLimitExceeded:
            return "Memory limit exceeded"
        }
    }

    /// Suggested recovery action (FR-047)
    public var recoveryAction: RecoveryAction {
        switch self {
        case .portInUse:
            return .changePort
        case .charlesUnreachable:
            return .launchCharles
        case .serviceStartFailed, .serviceStopFailed:
            return .restartService
        default:
            return .none
        }
    }

    public enum RecoveryAction: Sendable {
        case changePort
        case launchCharles
        case restartService
        case none
    }
}
