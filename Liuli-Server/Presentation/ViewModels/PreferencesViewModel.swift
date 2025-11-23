import Foundation
import Observation

/// Preferences view model (FR-028)
@MainActor
@Observable
public final class PreferencesViewModel {
    public var state: PreferencesViewState

    private let manageConfigurationUseCase: ManageConfigurationUseCase
    private let notificationService: NotificationService

    public init(
        manageConfigurationUseCase: ManageConfigurationUseCase,
        notificationService: NotificationService
    ) {
        self.manageConfigurationUseCase = manageConfigurationUseCase
        self.notificationService = notificationService
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
            case .close:
                // Window will be closed by coordinator
                break
            }
        }
    }

    private func loadConfiguration() async {
        do {
            let config = try await manageConfigurationUseCase.loadConfiguration()
            state = PreferencesViewState(configuration: config)
        } catch {
            Logger.ui.error("Failed to load configuration: \(error.localizedDescription)")
            state = PreferencesViewState(
                configuration: ProxyConfiguration.default,
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
            try await notificationService.show(
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
}
