import SwiftUI
import AppKit

/// Error alert view with recovery actions (FR-047)
public struct ErrorAlertView: View {
    let error: BridgeServiceError
    let onAction: (ErrorRecoveryAction) -> Void
    let onDismiss: () -> Void

    public init(
        error: BridgeServiceError,
        onAction: @escaping (ErrorRecoveryAction) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.error = error
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 48))
                .foregroundColor(errorColor)

            // Error title
            Text(error.title)
                .font(.headline)

            // Error message
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Recovery actions
            if !error.recoveryActions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(error.recoveryActions, id: \.self) { action in
                        Button(action: {
                            onAction(action)
                            onDismiss()
                        }) {
                            Text(action.localizedTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            // Dismiss button
            Button("error.dismiss".localized()) {
                onDismiss()
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 350)
    }

    private var errorIcon: String {
        switch error.severity {
        case .critical:
            return "xmark.octagon.fill"
        case .recoverable:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        }
    }

    private var errorColor: Color {
        switch error.severity {
        case .critical:
            return .red
        case .recoverable:
            return .orange
        case .warning:
            return .yellow
        }
    }
}

/// Error recovery action extensions
extension ErrorRecoveryAction {
    var localizedTitle: String {
        switch self {
        case .retry:
            return "error.action.retry".localized()
        case .restartService:
            return "error.action.restartService".localized()
        case .checkCharlesProxy:
            return "error.action.checkCharles".localized()
        case .openPreferences:
            return "error.action.openPreferences".localized()
        case .viewLogs:
            return "error.action.viewLogs".localized()
        case .contactSupport:
            return "error.action.contactSupport".localized()
        }
    }
}

/// Helper function to show error alert (FR-047)
@MainActor
public func showErrorAlert(
    error: BridgeServiceError,
    onAction: @escaping (ErrorRecoveryAction) -> Void
) {
    let alert = NSAlert()
    alert.alertStyle = error.severity == .critical ? .critical : .warning
    alert.messageText = error.title
    alert.informativeText = error.message

    // Add recovery actions as buttons
    for action in error.recoveryActions {
        alert.addButton(withTitle: action.localizedTitle)
    }

    // Add dismiss button
    alert.addButton(withTitle: "error.dismiss".localized())

    let response = alert.runModal()

    // Handle button response
    if response != .alertThirdButtonReturn {
        let actionIndex = Int(response.rawValue) - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if actionIndex < error.recoveryActions.count {
            onAction(error.recoveryActions[actionIndex])
        }
    }
}

#Preview {
    ErrorAlertView(
        error: BridgeServiceError(
            code: .charlesProxyNotReachable,
            severity: .recoverable,
            message: "Charles Proxy is not reachable at localhost:8888",
            underlyingError: nil,
            recoveryActions: [.checkCharlesProxy, .openPreferences]
        ),
        onAction: { action in
            print("Recovery action: \(action)")
        },
        onDismiss: {}
    )
}
