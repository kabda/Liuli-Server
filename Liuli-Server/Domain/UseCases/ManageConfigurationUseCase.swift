import Foundation

/// Manage user configuration use case (FR-041 to FR-045)
public struct ManageConfigurationUseCase: Sendable {
    private let configRepository: ConfigurationRepository

    public init(configRepository: ConfigurationRepository) {
        self.configRepository = configRepository
    }

    /// Load current configuration
    public func loadConfiguration() async throws -> ProxyConfiguration {
        try await configRepository.loadConfiguration()
    }

    /// Save configuration
    /// - Parameter config: Configuration to save
    /// - Throws: BridgeServiceError if validation fails
    public func saveConfiguration(_ config: ProxyConfiguration) async throws {
        // Validate before saving (FR-044)
        try config.validate()

        try await configRepository.saveConfiguration(config)
    }

    /// Reset to default configuration
    public func resetToDefaults() async throws {
        try await configRepository.resetToDefaults()
    }
}
