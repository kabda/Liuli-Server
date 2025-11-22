import AppKit
import SwiftUI

/// Statistics window coordinator
@MainActor
public final class StatisticsWindowCoordinator {
    private var window: NSWindow?
    private let viewModel: StatisticsViewModel

    public init(viewModel: StatisticsViewModel) {
        self.viewModel = viewModel
    }

    public func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "statistics.title".localized()
        window.center()
        window.contentView = NSHostingView(
            rootView: StatisticsView(viewModel: viewModel)
        )

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    public func close() {
        window?.close()
        window = nil
    }
}
