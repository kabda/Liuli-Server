import Foundation

/// Preferences view state (FR-028)
public struct PreferencesViewState: Sendable, Equatable {
    public var configuration: ProxyConfiguration
    public var validationError: String?
    public var isValid: Bool

    public init(
        configuration: ProxyConfiguration = .default,
        validationError: String? = nil,
        isValid: Bool = true
    ) {
        self.configuration = configuration
        self.validationError = validationError
        self.isValid = isValid
    }
}

/// Preferences view action
public enum PreferencesViewAction: Sendable {
    case onAppear
    case save
    case resetToDefaults
    case close
}
