import Foundation

/// Repository protocol for monitoring device connections
public protocol DeviceMonitorRepository: Sendable {
    /// Observe real-time device connection updates
    nonisolated func observeConnections() -> AsyncStream<[DeviceConnection]>

    /// Add a new device connection
    func addConnection(_ device: DeviceConnection) async

    /// Remove a device by ID (on disconnect)
    func removeConnection(_ deviceId: UUID) async

    /// Update traffic statistics for a device
    func updateTrafficStatistics(_ deviceId: UUID, bytesSent: Int64, bytesReceived: Int64) async
}
