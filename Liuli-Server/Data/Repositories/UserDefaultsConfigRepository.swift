import Foundation

/// UserDefaults-based configuration repository (FR-041 to FR-044)
public actor UserDefaultsConfigRepository: ConfigurationRepository {
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key = "com.liuli.server.configuration"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadConfiguration() async throws -> ProxyConfiguration {
        guard let data = defaults.data(forKey: key) else {
            // Return default configuration if not found (FR-043)
            return .default
        }

        do {
            let config = try JSONDecoder().decode(ProxyConfiguration.self, from: data)
            return config
        } catch {
            // Handle corrupted data (FR-050)
            Logger.configuration.warning("Corrupted configuration data, resetting to defaults")
            try await resetToDefaults()
            return .default
        }
    }

    public func saveConfiguration(_ config: ProxyConfiguration) async throws {
        // Validate before saving
        try config.validate()

        let data = try JSONEncoder().encode(config)
        defaults.set(data, forKey: key)
        defaults.synchronize()

        Logger.configuration.info("Configuration saved: port=\(config.socks5Port)")
    }

    public func resetToDefaults() async throws {
        defaults.removeObject(forKey: key)
        defaults.synchronize()
        Logger.configuration.info("Configuration reset to defaults")
    }
}
