import Foundation

/// Menu bar view state (FR-025, FR-026)
public struct MenuBarViewState: Sendable, Equatable {
    public let serviceState: ServiceState
    public let connectedDeviceCount: Int
    public let charlesStatus: CharlesProxyStatus
    public let errorMessage: String?

    public init(
        serviceState: ServiceState = .idle,
        connectedDeviceCount: Int = 0,
        charlesStatus: CharlesProxyStatus = .unknown,
        errorMessage: String? = nil
    ) {
        self.serviceState = serviceState
        self.connectedDeviceCount = connectedDeviceCount
        self.charlesStatus = charlesStatus
        self.errorMessage = errorMessage
    }

    /// Status text for menu bar
    public var statusText: String {
        serviceState.displayText.localized()
    }

    /// Should show Charles warning
    public var showCharlesWarning: Bool {
        serviceState == .running && !charlesStatus.isReachable
    }
}
