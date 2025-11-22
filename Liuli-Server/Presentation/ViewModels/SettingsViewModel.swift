import Foundation
import SwiftUI

/// State for settings view
public struct SettingsState: Sendable, Equatable {
    /// Application settings
    public var settings: ApplicationSettings

    /// Whether changes are being saved
    public var isSaving: Bool

    /// Error message if save fails
    public var errorMessage: String?

    /// Validation errors
    public var portError: String?

    public init(
        settings: ApplicationSettings = ApplicationSettings(),
        isSaving: Bool = false,
        errorMessage: String? = nil,
        portError: String? = nil
    ) {
        self.settings = settings
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.portError = portError
    }
}

/// Actions for settings view
public enum SettingsAction: Sendable {
    case load
    case save
    case cancel
    case updateCharlesHost(String)
    case updateCharlesPort(String)
    case toggleAutoStart
    case toggleShowMenuBarIcon
    case toggleShowMainWindowOnLaunch
}

/// ViewModel for settings window
@MainActor
@Observable
public final class SettingsViewModel {
    private let manageSettingsUseCase: ManageSettingsUseCase

    private(set) var state = SettingsState()

    public init(manageSettingsUseCase: ManageSettingsUseCase) {
        self.manageSettingsUseCase = manageSettingsUseCase
    }

    public func send(_ action: SettingsAction) {
        Task {
            switch action {
            case .load:
                await loadSettings()
            case .save:
                await saveSettings()
            case .cancel:
                // View will handle dismissal
                break
            case .updateCharlesHost(let host):
                state.settings.charlesProxyHost = host
            case .updateCharlesPort(let portString):
                if let port = UInt16(portString), port > 0 && port <= 65535 {
                    state.settings.charlesProxyPort = port
                    state.portError = nil
                } else {
                    state.portError = "Port must be between 1 and 65535"
                }
            case .toggleAutoStart:
                state.settings.autoStartBridge.toggle()
            case .toggleShowMenuBarIcon:
                state.settings.showMenuBarIcon.toggle()
            case .toggleShowMainWindowOnLaunch:
                state.settings.showMainWindowOnLaunch.toggle()
            }
        }
    }

    private func loadSettings() async {
        let settings = await manageSettingsUseCase.loadSettings()
        state.settings = settings
        state.errorMessage = nil
    }

    private func saveSettings() async {
        // Validate port
        if state.settings.charlesProxyPort == 0 || state.settings.charlesProxyPort > 65535 {
            state.portError = "Port must be between 1 and 65535"
            return
        }

        state.isSaving = true
        state.errorMessage = nil

        do {
            try await manageSettingsUseCase.saveSettings(state.settings)
            state.isSaving = false
        } catch {
            state.isSaving = false
            state.errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    public var canSave: Bool {
        state.portError == nil && !state.isSaving
    }
}
