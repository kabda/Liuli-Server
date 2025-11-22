import Foundation

/// Represents network bridge listening state
public struct NetworkStatus: Sendable, Equatable, Codable {
    /// Whether bridge is currently accepting connections
    public let isListening: Bool

    /// Port number bridge is listening on (if listening)
    public let listeningPort: UInt16?

    /// Number of currently active connections
    public let activeConnectionCount: Int

    /// Timestamp of last status update
    public let lastUpdated: Date

    public nonisolated init(
        isListening: Bool,
        listeningPort: UInt16? = nil,
        activeConnectionCount: Int = 0,
        lastUpdated: Date? = nil
    ) {
        self.isListening = isListening
        self.listeningPort = listeningPort
        self.activeConnectionCount = activeConnectionCount
        self.lastUpdated = lastUpdated ?? Date.now
    }
}
