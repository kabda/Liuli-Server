import Foundation

/// Service lifecycle states (FR-025)
public enum ServiceState: String, Sendable, Codable, Equatable {
    /// Service is idle (not started)
    case idle

    /// Service is starting up
    case starting

    /// Service is running and accepting connections
    case running

    /// Service is stopping
    case stopping

    /// Service encountered an error
    case error

    /// User-facing status text
    public var displayText: String {
        switch self {
        case .idle: return "service.status.stopped"
        case .starting: return "service.status.starting"
        case .running: return "service.status.running"
        case .stopping: return "service.status.stopping"
        case .error: return "service.status.error"
        }
    }

    /// Menu bar icon color (FR-025)
    public var iconColor: IconColor {
        switch self {
        case .idle: return .gray
        case .starting: return .blue
        case .running: return .green
        case .stopping: return .blue
        case .error: return .red
        }
    }

    public enum IconColor: String, Sendable {
        case gray, blue, green, yellow, red
    }
}
