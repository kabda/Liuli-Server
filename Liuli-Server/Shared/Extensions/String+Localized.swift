import Foundation

/// String localization convenience extension
extension String {
    /// Localized string from Localizable.strings
    /// - Parameter comment: Comment for translators
    /// - Returns: Localized string
    public func localized(comment: String = "") -> String {
        NSLocalizedString(self, comment: comment)
    }

    /// Localized string with format arguments
    /// - Parameters:
    ///   - arguments: Format arguments
    ///   - comment: Comment for translators
    /// - Returns: Formatted localized string
    public func localized(with arguments: CVarArg..., comment: String = "") -> String {
        let format = NSLocalizedString(self, comment: comment)
        return String(format: format, arguments: arguments)
    }
}
