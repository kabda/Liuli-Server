import AppKit
import SwiftUI

/// Preferences window coordinator
@MainActor
public final class PreferencesWindowCoordinator: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: PreferencesViewModel

    public override init() {
        fatalError("Use init(viewModel:) instead")
    }

    public init(viewModel: PreferencesViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    public func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "preferences.title".localized()
        window.center()
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: PreferencesView(viewModel: viewModel)
        )

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    public func close() {
        window?.close()
        window = nil
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
