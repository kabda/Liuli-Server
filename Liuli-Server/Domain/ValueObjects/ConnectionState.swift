import Foundation

/// Individual connection states
public enum ConnectionState: String, Sendable, Codable, Equatable {
    /// Connection is being established
    case connecting

    /// Connection is active and forwarding data
    case active

    /// Connection is idle (no data transfer)
    case idle

    /// Connection is being closed
    case closing

    /// Connection is closed
    case closed

    /// Connection encountered an error
    case error
}
