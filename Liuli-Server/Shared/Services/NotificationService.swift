import Foundation
import UserNotifications

/// Notification service for user notifications (FR-029, FR-037)
@MainActor
public final class NotificationService {
    public static let shared = NotificationService()

    private init() {}

    /// Request notification authorization
    public func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()

        let granted = try await center.requestAuthorization(options: [.alert, .sound])

        if !granted {
            Logger.ui.warning("User denied notification authorization")
        }
    }

    /// Show notification
    public func show(title: String, body: String, identifier: String = UUID().uuidString) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Show immediately
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    /// Show service started notification (FR-029)
    public func showServiceStarted() async {
        do {
            try await show(
                title: "notification.serviceStarted".localized(),
                body: "notification.serviceStartedBody".localized(),
                identifier: "service.started"
            )
        } catch {
            Logger.ui.error("Failed to show notification: \(error.localizedDescription)")
        }
    }

    /// Show service stopped notification (FR-029)
    public func showServiceStopped() async {
        do {
            try await show(
                title: "notification.serviceStopped".localized(),
                body: "notification.serviceStoppedBody".localized(),
                identifier: "service.stopped"
            )
        } catch {
            Logger.ui.error("Failed to show notification: \(error.localizedDescription)")
        }
    }

    /// Show Charles not detected warning (FR-037)
    public func showCharlesNotDetected() async {
        do {
            try await show(
                title: "notification.charlesNotDetected".localized(),
                body: "notification.charlesNotDetectedBody".localized(),
                identifier: "charles.notDetected"
            )
        } catch {
            Logger.ui.error("Failed to show notification: \(error.localizedDescription)")
        }
    }

    /// Show device connected notification (FR-029)
    public func showDeviceConnected(deviceName: String) async {
        do {
            try await show(
                title: "notification.deviceConnected".localized(),
                body: "notification.deviceConnectedBody".localized(args: deviceName),
                identifier: "device.connected.\(deviceName)"
            )
        } catch {
            Logger.ui.error("Failed to show notification: \(error.localizedDescription)")
        }
    }
}
