import AppKit
import SwiftUI

/// Menu bar coordinator for managing NSStatusItem (FR-024, FR-025)
@MainActor
public final class MenuBarCoordinator {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let viewModel: MenuBarViewModel

    public init(viewModel: MenuBarViewModel) {
        self.viewModel = viewModel
    }

    public func setup() {
        // Create status item in menu bar
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Store reference first
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self

            // Set initial icon based on state
            updateIcon(isEnabled: viewModel.state.isBridgeEnabled)

            print("✅ MenuBarCoordinator: Status bar icon set up with title: '\(button.title)'")
        } else {
            print("❌ MenuBarCoordinator: Failed to get status bar button")
        }

        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(viewModel: viewModel)
        )

        self.popover = popover

        // Observe state changes to update icon
        observeStateChanges()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeStateChanges() {
        // TODO: Phase 7 - Observe viewModel.state changes and update icon
        // For now, this is a placeholder
    }

    private func updateIcon(isEnabled: Bool) {
        guard let button = statusItem?.button else {
            print("❌ MenuBarCoordinator: No button available")
            return
        }

        // Use clear, visible text
        button.image = nil
        button.title = "LS"  // Liuli Server - simple and always visible
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        print("✅ MenuBarCoordinator: Set icon to 'LS' - isEnabled: \(isEnabled)")
        print("   Button frame: \(button.frame)")
        print("   Button isHidden: \(button.isHidden)")
    }
}
