import Foundation

/// Actor-based repository for network status monitoring with bridge integration stubs
public actor NetworkStatusRepositoryImpl: NetworkStatusRepository {
    private var currentStatus: NetworkStatus
    private var continuation: AsyncStream<NetworkStatus>.Continuation?

    public init() {
        self.currentStatus = NetworkStatus(isListening: false)
    }

    public nonisolated func observeStatus() -> AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            Task {
                await self.setupContinuation(continuation)
            }
        }
    }

    private func setupContinuation(_ continuation: AsyncStream<NetworkStatus>.Continuation) {
        self.continuation = continuation

        // Emit current state immediately
        emitCurrentState()

        continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.clearContinuation()
            }
        }
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
        continuation?.yield(currentStatus)
    }

    private func clearContinuation() {
        continuation = nil
    }
}
