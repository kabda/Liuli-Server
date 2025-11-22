import Foundation

/// Represents Charles proxy availability state
public struct CharlesStatus: Sendable, Equatable, Codable {
    /// Current availability state
    public let availability: Availability

    /// Configured proxy host (e.g., "localhost")
    public let proxyHost: String

    /// Configured proxy port (e.g., 8888)
    public let proxyPort: UInt16

    /// Timestamp of last availability check
    public let lastChecked: Date

    /// Optional error message if unavailable
    public let errorMessage: String?

    public nonisolated init(
        availability: Availability,
        proxyHost: String,
        proxyPort: UInt16,
        lastChecked: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.availability = availability
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.lastChecked = lastChecked ?? Date.now
        self.errorMessage = errorMessage
    }
}

public enum Availability: String, Sendable, Codable {
    case unknown = "unknown"        // Initial state, not yet checked
    case available = "available"    // CONNECT probe succeeded
    case unavailable = "unavailable" // CONNECT probe failed or timeout
}
