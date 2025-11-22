import Foundation

/// Repository protocol for managing application settings
public protocol SettingsRepository: Sendable {
    /// Load settings from persistence
    func loadSettings() async -> ApplicationSettings

    /// Save settings to persistence
    func saveSettings(_ settings: ApplicationSettings) async throws

    /// Bridge state management (separate from settings for crash detection)
    func saveBridgeState(_ enabled: Bool) async
    func loadBridgeState() async -> Bool  // Returns false if crash detected

    /// Mark clean shutdown (for crash detection)
    func markCleanShutdown() async
}
