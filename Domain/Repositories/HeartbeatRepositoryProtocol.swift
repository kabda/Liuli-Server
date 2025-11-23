import Foundation

/// Protocol for heartbeat monitoring between server and connected devices
/// Detects server availability and connection health
public protocol HeartbeatRepositoryProtocol: Sendable {
    /// Start sending heartbeat signals to connected device (server-side)
    /// - Parameter connection: Active connection to monitor
    /// - Returns: AsyncStream of heartbeat results (success/failure)
    func startSendingHeartbeats(connection: ServerConnection) -> AsyncStream<HeartbeatResult>

    /// Stop sending heartbeat signals (server-side)
    /// - Parameter connectionID: Connection to stop monitoring
    func stopSendingHeartbeats(connectionID: UUID) async

    /// Start monitoring heartbeat signals from server (client-side)
    /// - Returns: AsyncStream of heartbeat events (received/timeout)
    func startMonitoringHeartbeats() -> AsyncStream<HeartbeatEvent>

    /// Stop monitoring heartbeat signals (client-side)
    func stopMonitoringHeartbeats() async

    /// Send heartbeat response to server (client-side)
    /// - Throws: HeartbeatError if response fails
    func sendHeartbeatResponse() async throws
}

// MARK: - Heartbeat Types

public enum HeartbeatResult: Sendable, Equatable {
    case success(connectionID: UUID, latency: TimeInterval)
    case failure(connectionID: UUID, reason: String)
    case timeout(connectionID: UUID)
}

public enum HeartbeatEvent: Sendable, Equatable {
    case received(timestamp: Date)
    case timeout(lastReceivedAt: Date)
}

// MARK: - Errors

public enum HeartbeatError: Error, LocalizedError {
    case sendFailed(reason: String)
    case connectionClosed
    case invalidPacket

    public var errorDescription: String? {
        switch self {
        case .sendFailed(let reason):
            return "Heartbeat send failed: \(reason)"
        case .connectionClosed:
            return "Connection closed - cannot send heartbeat"
        case .invalidPacket:
            return "Invalid heartbeat packet received"
        }
    }
}
