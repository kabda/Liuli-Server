import Foundation

/// In-memory actor-based repository for device connection monitoring
public actor DeviceMonitorRepositoryImpl: DeviceMonitorRepository {
    private var devices: [UUID: DeviceConnection] = [:]
    private var continuation: AsyncStream<[DeviceConnection]>.Continuation?

    public init() {}

    public nonisolated func observeConnections() -> AsyncStream<[DeviceConnection]> {
        AsyncStream { continuation in
            Task {
                await self.setupContinuation(continuation)
            }
        }
    }

    private func setupContinuation(_ continuation: AsyncStream<[DeviceConnection]>.Continuation) {
        self.continuation = continuation

        // Emit current state immediately
        emitCurrentState()

        continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.clearContinuation()
            }
        }
    }

    public func addConnection(_ device: DeviceConnection) async {
        devices[device.id] = device
        emitCurrentState()
    }

    public func removeConnection(_ deviceId: UUID) async {
        devices.removeValue(forKey: deviceId)
        emitCurrentState()
    }

    public func updateTrafficStatistics(_ deviceId: UUID, bytesSent: Int64, bytesReceived: Int64) async {
        guard var device = devices[deviceId] else { return }
        device.bytesSent = bytesSent
        device.bytesReceived = bytesReceived
        devices[deviceId] = device
        emitCurrentState()
    }

    private func emitCurrentState() {
        let deviceList = Array(devices.values).sorted { $0.connectedAt > $1.connectedAt }
        continuation?.yield(deviceList)
    }

    private func clearContinuation() {
        continuation = nil
    }
}
