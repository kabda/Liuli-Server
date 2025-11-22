import Foundation
import Observation

/// Preferences view model (FR-028)
@MainActor
@Observable
public final class PreferencesViewModel {
    private(set) var state: PreferencesViewState

    private let manageConfigurationUseCase: ManageConfigurationUseCase
    private var originalConfiguration: ProxyConfiguration?

    public init(manageConfigurationUseCase: ManageConfigurationUseCase) {
        self.manageConfigurationUseCase = manageConfigurationUseCase
        self.state = PreferencesViewState()
    }

    /// Handle user action
    public func send(_ action: PreferencesViewAction) {
        Task {
            switch action {
            case .onAppear:
                await loadConfiguration()
            case .save:
                await saveConfiguration()
            case .resetToDefaults:
                resetToDefaults()
            case .close:
                // Window will be closed by coordinator
                break
            }
        }
    }

    private func loadConfiguration() async {
        do {
            let config = try await manageConfigurationUseCase.loadConfiguration()
            originalConfiguration = config
            state = PreferencesViewState(configuration: config)
        } catch {
            Logger.ui.error("Failed to load configuration: \(error.localizedDescription)")
            state = PreferencesViewState(
                configuration: ProxyConfiguration.defaultConfiguration,
                validationError: error.localizedDescription
            )
        }
    }

    private func saveConfiguration() async {
        // Validate configuration
        do {
            try state.configuration.validate()
        } catch {
            state = PreferencesViewState(
                configuration: state.configuration,
                validationError: error.localizedDescription,
                isValid: false
            )
            return
        }

        // Save configuration
        do {
            try await manageConfigurationUseCase.saveConfiguration(state.configuration)

            // Show success notification
            showNotification(
                title: "preferences.savedSuccessfully".localized(),
                body: ""
            )

            // Close window
            // (Coordinator should close window after this)
        } catch {
            Logger.ui.error("Failed to save configuration: \(error.localizedDescription)")
            state = PreferencesViewState(
                configuration: state.configuration,
                validationError: error.localizedDescription
            )
        }
    }

    private func resetToDefaults() {
        state = PreferencesViewState(
            configuration: ProxyConfiguration.defaultConfiguration
        )
    }

    private func showNotification(title: String, body: String) {
        // TODO: Implement using UserNotifications framework
        Logger.ui.info("Notification: \(title)")
    }
}
