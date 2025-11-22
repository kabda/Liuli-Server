import SwiftUI

/// Status panel showing network bridge and Charles proxy status
public struct StatusPanelView: View {
    let networkStatus: NetworkStatus
    let charlesStatus: CharlesStatus

    public init(networkStatus: NetworkStatus, charlesStatus: CharlesStatus) {
        self.networkStatus = networkStatus
        self.charlesStatus = charlesStatus
    }

    public var body: some View {
        HStack(spacing: 24) {
            // Network Bridge Status
            StatusIndicatorView(
                icon: "network",
                label: "Bridge",
                status: networkStatus.isListening ? "Active" : "Inactive",
                color: networkStatus.isListening ? .green : .gray,
                details: networkStatus.isListening ? "Port \(networkStatus.listeningPort ?? 0)" : "Not listening"
            )

            Divider()
                .frame(height: 40)

            // Charles Proxy Status
            StatusIndicatorView(
                icon: "arrow.left.arrow.right",
                label: "Charles Proxy",
                status: charlesStatus.availability.displayName,
                color: charlesStatus.availability.color,
                details: "\(charlesStatus.proxyHost):\(charlesStatus.proxyPort)"
            )

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Extensions

extension Availability {
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .available: return .green
        case .unavailable: return .red
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        StatusPanelView(
            networkStatus: NetworkStatus(isListening: true, listeningPort: 12345, activeConnectionCount: 2),
            charlesStatus: CharlesStatus(availability: .available, proxyHost: "localhost", proxyPort: 8888)
        )

        Divider()

        StatusPanelView(
            networkStatus: NetworkStatus(isListening: false),
            charlesStatus: CharlesStatus(availability: .unavailable, proxyHost: "localhost", proxyPort: 8888, errorMessage: "Connection refused")
        )
    }
}
