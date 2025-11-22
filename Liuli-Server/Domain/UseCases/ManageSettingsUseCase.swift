import Foundation

/// Use case for managing application settings
public struct ManageSettingsUseCase: Sendable {
    private let repository: SettingsRepository

    public init(repository: SettingsRepository) {
        self.repository = repository
    }

    /// Load current settings
    public func loadSettings() async -> ApplicationSettings {
        await repository.loadSettings()
    }

    /// Save settings
    public func saveSettings(_ settings: ApplicationSettings) async throws {
        try await repository.saveSettings(settings)
    }

    /// Mark clean shutdown (called on app termination)
    public func markCleanShutdown() async {
        await repository.markCleanShutdown()
    }
}
