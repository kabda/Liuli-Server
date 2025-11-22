import Foundation
import Observation
import AppKit

/// Menu bar view model (FR-024 to FR-030)
@MainActor
@Observable
public final class MenuBarViewModel {
    private(set) var state: MenuBarViewState

    private let startServiceUseCase: StartServiceUseCase
    private let stopServiceUseCase: StopServiceUseCase
    private let detectCharlesUseCase: DetectCharlesUseCase

    // Window coordinators (injected externally)
    public var statisticsWindowCoordinator: StatisticsWindowCoordinator?
    public var preferencesWindowCoordinator: PreferencesWindowCoordinator?

    public init(
        startServiceUseCase: StartServiceUseCase,
        stopServiceUseCase: StopServiceUseCase,
        detectCharlesUseCase: DetectCharlesUseCase
    ) {
        self.startServiceUseCase = startServiceUseCase
        self.stopServiceUseCase = stopServiceUseCase
        self.detectCharlesUseCase = detectCharlesUseCase
        self.state = MenuBarViewState()
    }

    /// Handle user action
    public func send(_ action: MenuBarViewAction) {
        Task {
            switch action {
            case .startService:
                await startService()
            case .stopService:
                await stopService()
            case .openCharles:
                await openCharles()
            case .viewStatistics:
                statisticsWindowCoordinator?.show()
            case .openPreferences:
                preferencesWindowCoordinator?.show()
            case .quit:
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func startService() async {
        state = MenuBarViewState(serviceState: .starting)

        do {
            let bridge = try await startServiceUseCase.execute()

            state = MenuBarViewState(
                serviceState: bridge.state,
                connectedDeviceCount: bridge.connectedDeviceCount,
                charlesStatus: bridge.charlesStatus
            )

            // Show notification (FR-029)
            await NotificationService.shared.showServiceStarted()

            // Show Charles warning if not detected (FR-037)
            if !bridge.charlesStatus.isReachable {
                await NotificationService.shared.showCharlesNotDetected()
            }
        } catch {
            state = MenuBarViewState(
                serviceState: .error,
                errorMessage: error.localizedDescription
            )

            if let bridgeError = error as? BridgeServiceError {
                showErrorAlert(bridgeError)
            } else {
                // For generic errors, log them
                Logger.ui.error("Service start failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopService() async {
        state = MenuBarViewState(serviceState: .stopping)

        do {
            let bridge = try await stopServiceUseCase.execute()

            state = MenuBarViewState(
                serviceState: bridge.state,
                connectedDeviceCount: 0,
                charlesStatus: .unknown
            )

            // Show notification (FR-029)
            await NotificationService.shared.showServiceStopped()
        } catch {
            state = MenuBarViewState(
                serviceState: .error,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func openCharles() async {
        do {
            try await detectCharlesUseCase.launchCharles()
        } catch {
            if let bridgeError = error as? BridgeServiceError {
                showErrorAlert(bridgeError)
            } else {
                Logger.ui.error("Failed to launch Charles: \(error.localizedDescription)")
            }
        }
    }

    private func showErrorAlert(_ error: BridgeServiceError) {
        // For now, just log the error
        Logger.ui.error("Error: \(error.localizedDescription)")
    }

    private func handleRecoveryAction(_ action: BridgeServiceError.RecoveryAction) {
        Task {
            switch action {
            case .changePort:
                preferencesWindowCoordinator?.show()
            case .launchCharles:
                await openCharles()
            case .restartService:
                await stopService()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await startService()
            case .none:
                break
            }
        }
    }
}
