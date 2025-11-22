import Foundation
import SwiftUI

/// State for menu bar view
public struct MenuBarState: Sendable, Equatable {
    /// Whether bridge is currently enabled
    public var isBridgeEnabled: Bool

    /// Number of active connections
    public var connectionCount: Int

    /// Current network status
    public var networkStatus: NetworkStatus

    /// Error message if any
    public var errorMessage: String?

    public init(
        isBridgeEnabled: Bool = false,
        connectionCount: Int = 0,
        networkStatus: NetworkStatus = NetworkStatus(isListening: false),
        errorMessage: String? = nil
    ) {
        self.isBridgeEnabled = isBridgeEnabled
        self.connectionCount = connectionCount
        self.networkStatus = networkStatus
        self.errorMessage = errorMessage
    }
}

/// Actions for menu bar
public enum MenuBarAction: Sendable {
    case toggleBridge
    case showMainWindow
    case openSettings
    case quit
}

/// ViewModel for menu bar control
@MainActor
@Observable
public final class MenuBarViewModel {
    private let toggleBridgeUseCase: ToggleBridgeUseCase
    private let monitorNetworkUseCase: MonitorNetworkStatusUseCase

    private(set) var state = MenuBarState()

    private var networkTask: Task<Void, Never>?

    // TODO: Phase 7 - Inject window coordinators for app integration
    public var onShowMainWindow: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onQuit: (() -> Void)?

    public init(
        toggleBridgeUseCase: ToggleBridgeUseCase,
        monitorNetworkUseCase: MonitorNetworkStatusUseCase
    ) {
        self.toggleBridgeUseCase = toggleBridgeUseCase
        self.monitorNetworkUseCase = monitorNetworkUseCase
    }

    public func startMonitoring() {
        networkTask = Task {
            for await status in monitorNetworkUseCase.execute() {
                state.networkStatus = status
                state.isBridgeEnabled = status.isListening
                state.connectionCount = status.activeConnectionCount
            }
        }
    }

    public func stopMonitoring() {
        networkTask?.cancel()
    }

    public func send(_ action: MenuBarAction) {
        Task {
            switch action {
            case .toggleBridge:
                await toggleBridge()
            case .showMainWindow:
                onShowMainWindow?()
            case .openSettings:
                onOpenSettings?()
            case .quit:
                onQuit?()
            }
        }
    }

    private func toggleBridge() async {
        do {
            if state.isBridgeEnabled {
                try await toggleBridgeUseCase.disable()
            } else {
                try await toggleBridgeUseCase.enable()
            }
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }
}
