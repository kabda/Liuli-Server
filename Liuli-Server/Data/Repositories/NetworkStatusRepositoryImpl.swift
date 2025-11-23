import Foundation

/// Actor-based repository for network status monitoring with real bridge integration
public actor NetworkStatusRepositoryImpl: NetworkStatusRepository {
    private var currentStatus: NetworkStatus
    private var continuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]

    // Real service integration
    private let startServiceUseCase: StartServiceUseCase
    private let stopServiceUseCase: StopServiceUseCase
    private let configRepository: ConfigurationRepository
    private let socks5Repository: SOCKS5ServerRepository
    private let bridgeService: SOCKS5DeviceBridgeService

    public init(
        startServiceUseCase: StartServiceUseCase,
        stopServiceUseCase: StopServiceUseCase,
        configRepository: ConfigurationRepository,
        socks5Repository: SOCKS5ServerRepository,
        bridgeService: SOCKS5DeviceBridgeService
    ) {
        self.startServiceUseCase = startServiceUseCase
        self.stopServiceUseCase = stopServiceUseCase
        self.configRepository = configRepository
        self.socks5Repository = socks5Repository
        self.bridgeService = bridgeService
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
        // Start real SOCKS5 server
        let bridgeService = try await startServiceUseCase.execute()

        // Start SOCKS5-to-Device bridge monitoring
        await self.bridgeService.startMonitoring()

        // Get actual port from configuration
        let config = try await configRepository.loadConfiguration()

        currentStatus = NetworkStatus(
            isListening: bridgeService.state == .running,
            listeningPort: UInt16(config.socks5Port),
            activeConnectionCount: bridgeService.connectedDeviceCount
        )
        emitCurrentState()

        Logger.network.info("Bridge enabled on port \(config.socks5Port)")
    }

    public func disableBridge() async throws {
        // Stop SOCKS5-to-Device bridge monitoring
        await bridgeService.stopMonitoring()

        // Stop real SOCKS5 server
        _ = try await stopServiceUseCase.execute()

        currentStatus = NetworkStatus(
            isListening: false,
            listeningPort: nil,
            activeConnectionCount: 0
        )
        emitCurrentState()

        Logger.network.info("Bridge disabled")
    }

    private func emitCurrentState() {
        for continuation in continuations.values {
            continuation.yield(currentStatus)
        }
    }
}
