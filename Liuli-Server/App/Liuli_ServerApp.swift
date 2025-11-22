import SwiftUI

@main
struct Liuli_ServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scenes - this is a menu bar only app (LSUIElement=YES)
        Settings {
            EmptyView()
        }
    }
}

/// App delegate for menu bar setup
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarCoordinator: MenuBarCoordinator?
    private var dashboardWindowCoordinator: DashboardWindowCoordinator?
    private var statisticsWindowCoordinator: StatisticsWindowCoordinator?
    private var preferencesWindowCoordinator: PreferencesWindowCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (LSUIElement in Info.plist should handle this, but double-check)
        NSApp.setActivationPolicy(.accessory)

        // Request notification authorization
        Task {
            try? await NotificationService.shared.requestAuthorization()
        }

        // Setup dependency injection
        let container = AppDependencyContainer.shared

        // Create window coordinators
        let dashboardCoordinator = container.makeDashboardWindowCoordinator()
        let statisticsCoordinator = container.makeStatisticsWindowCoordinator()
        let preferencesCoordinator = container.makePreferencesWindowCoordinator()

        // Create and setup menu bar coordinator
        let viewModel = container.makeMenuBarViewModel()

        // TODO: Phase 7 - Wire up window coordinator callbacks
        viewModel.onShowMainWindow = { [weak dashboardCoordinator] in
            dashboardCoordinator?.showWindow()
        }
        viewModel.onOpenSettings = { [weak preferencesCoordinator] in
            preferencesCoordinator?.show()
        }
        viewModel.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        let coordinator = MenuBarCoordinator(viewModel: viewModel)
        coordinator.setup()

        self.menuBarCoordinator = coordinator
        self.dashboardWindowCoordinator = dashboardCoordinator
        self.statisticsWindowCoordinator = statisticsCoordinator
        self.preferencesWindowCoordinator = preferencesCoordinator

        // Auto-start bridge on app launch
        Task {
            let toggleBridgeUseCase = container.toggleBridgeUseCase
            do {
                try await toggleBridgeUseCase.enable()
                Logger.service.info("Bridge auto-started on app launch")
            } catch {
                Logger.service.error("Failed to auto-start bridge: \(error.localizedDescription)")
            }
        }

        Logger.service.info("Liuli-Server application started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.service.info("Liuli-Server application terminating")
        // TODO: Cleanup - stop services, close connections
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
