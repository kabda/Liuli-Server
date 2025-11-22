import SwiftUI
import AppKit

/// Error alert view with recovery actions (FR-047)
public struct ErrorAlertView: View {
    let error: BridgeServiceError
    let onAction: (BridgeServiceError.RecoveryAction) -> Void
    let onDismiss: () -> Void

    public init(
        error: BridgeServiceError,
        onAction: @escaping (BridgeServiceError.RecoveryAction) -> Void,
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

            // Error message
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Recovery action button
            let action = error.recoveryAction
            if action != .none {
                Button(action: {
                    onAction(action)
                    onDismiss()
                }) {
                    Text(action.localizedTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
        "exclamationmark.triangle.fill"
    }

    private var errorColor: Color {
        .orange
    }
}

/// Error recovery action extensions
extension BridgeServiceError.RecoveryAction {
    var localizedTitle: String {
        switch self {
        case .changePort:
            return "error.action.changePort".localized()
        case .launchCharles:
            return "error.action.launchCharles".localized()
        case .restartService:
            return "error.action.restartService".localized()
        case .none:
            return ""
        }
    }
}

#Preview {
    ErrorAlertView(
        error: .charlesUnreachable(host: "localhost", port: 8888),
        onAction: { action in
            print("Recovery action: \(action)")
        },
        onDismiss: {}
    )
}
