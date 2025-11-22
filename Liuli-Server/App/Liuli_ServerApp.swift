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
        let statisticsCoordinator = container.makeStatisticsWindowCoordinator()
        let preferencesCoordinator = container.makePreferencesWindowCoordinator()

        // Create and setup menu bar coordinator
        let viewModel = container.makeMenuBarViewModel()
        viewModel.statisticsWindowCoordinator = statisticsCoordinator
        viewModel.preferencesWindowCoordinator = preferencesCoordinator

        let coordinator = MenuBarCoordinator(viewModel: viewModel)
        coordinator.setup()

        self.menuBarCoordinator = coordinator
        self.statisticsWindowCoordinator = statisticsCoordinator
        self.preferencesWindowCoordinator = preferencesCoordinator

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
