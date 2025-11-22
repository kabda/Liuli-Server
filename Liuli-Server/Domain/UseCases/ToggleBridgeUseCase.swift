import Foundation

/// Use case for toggling bridge on/off
public struct ToggleBridgeUseCase: Sendable {
    private let networkRepository: NetworkStatusRepository
    private let settingsRepository: SettingsRepository

    public init(
        networkRepository: NetworkStatusRepository,
        settingsRepository: SettingsRepository
    ) {
        self.networkRepository = networkRepository
        self.settingsRepository = settingsRepository
    }

    /// Enable bridge
    public func enable() async throws {
        try await networkRepository.enableBridge()
        await settingsRepository.saveBridgeState(true)
    }

    /// Disable bridge
    public func disable() async throws {
        try await networkRepository.disableBridge()
        await settingsRepository.saveBridgeState(false)
    }

    /// Get current bridge state
    public func getCurrentState() async -> Bool {
        await settingsRepository.loadBridgeState()
    }
}
