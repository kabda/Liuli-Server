import Foundation

/// Stop bridge service use case
public struct StopServiceUseCase: Sendable {
    private let socks5Repository: SOCKS5ServerRepository
    private let bonjourRepository: BonjourServiceRepository

    public init(
        socks5Repository: SOCKS5ServerRepository,
        bonjourRepository: BonjourServiceRepository
    ) {
        self.socks5Repository = socks5Repository
        self.bonjourRepository = bonjourRepository
    }

    /// Execute service stop
    /// - Returns: BridgeService with idle state
    /// - Throws: BridgeServiceError if stop fails
    public func execute() async throws -> BridgeService {
        // Stop Bonjour advertisement (FR-006)
        try await bonjourRepository.stopAdvertising()

        // Stop SOCKS5 server
        try await socks5Repository.stop()

        return BridgeService(
            state: .idle,
            connectedDeviceCount: 0,
            charlesStatus: .unknown,
            errorMessage: nil
        )
    }
}
