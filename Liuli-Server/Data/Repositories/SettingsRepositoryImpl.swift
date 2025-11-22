import Foundation

/// Actor-based repository for settings persistence using UserDefaults with crash detection
/// Note: UserDefaults is thread-safe, so nonisolated(unsafe) is acceptable here
public actor SettingsRepositoryImpl: SettingsRepository {
    private nonisolated(unsafe) let userDefaults: UserDefaults
    private let settingsKey = "app.settings"
    private let bridgeStateKey = "bridge.enabled"
    private let cleanShutdownKey = "app.clean_shutdown"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadSettings() async -> ApplicationSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ApplicationSettings.self, from: data) else {
            return ApplicationSettings()  // Return defaults
        }
        return settings
    }

    public func saveSettings(_ settings: ApplicationSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        userDefaults.set(data, forKey: settingsKey)
    }

    public func saveBridgeState(_ enabled: Bool) async {
        userDefaults.set(enabled, forKey: bridgeStateKey)
        // Mark as dirty (not clean shutdown yet)
        userDefaults.set(false, forKey: cleanShutdownKey)
    }

    public func loadBridgeState() async -> Bool {
        // Check if last shutdown was clean
        let wasCleanShutdown = userDefaults.bool(forKey: cleanShutdownKey)

        if !wasCleanShutdown {
            // Crash detected - disable bridge for safety
            userDefaults.set(false, forKey: bridgeStateKey)
            return false
        }

        return userDefaults.bool(forKey: bridgeStateKey)
    }

    public func markCleanShutdown() async {
        userDefaults.set(true, forKey: cleanShutdownKey)
    }
}
