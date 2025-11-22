import Foundation

/// Actor-based repository for network status monitoring with bridge integration stubs
public actor NetworkStatusRepositoryImpl: NetworkStatusRepository {
    private var currentStatus: NetworkStatus
    private var continuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]

    public init() {
        self.currentStatus = NetworkStatus(isListening: false)
    }

    public nonisolated func observeStatus() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            let id = UUID()
            Task {
                await self.addContinuation(id: id, continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(id: id)
                }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<NetworkStatus>.Continuation) {
        continuations[id] = continuation
        // Emit current state immediately to new subscriber
        continuation.yield(currentStatus)
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    public func enableBridge() async throws {
        // TODO: Phase 7 - Integrate with actual bridge implementation
        // For now, simulate bridge activation
        currentStatus = NetworkStatus(
            isListening: true,
            listeningPort: 12345,
            activeConnectionCount: 0
        )
        emitCurrentState()
    }

    public func disableBridge() async throws {
        // TODO: Phase 7 - Integrate with actual bridge implementation
        // For now, simulate bridge deactivation
        let activeCount = currentStatus.activeConnectionCount
        currentStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: activeCount  // Keep existing connections
        )
        emitCurrentState()
    }

    private func emitCurrentState() {
        for continuation in continuations.values {
            continuation.yield(currentStatus)
        }
    }
}
