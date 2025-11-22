import Foundation

/// User preferences persistence (FR-041 to FR-045)
public protocol ConfigurationRepository: Sendable {
    /// Load configuration from storage
    func loadConfiguration() async throws -> ProxyConfiguration

    /// Save configuration to storage
    func saveConfiguration(_ config: ProxyConfiguration) async throws

    /// Reset to default configuration
    func resetToDefaults() async throws
}
