import SwiftUI

/// Reusable status indicator with icon, label, status text, and color
public struct StatusIndicatorView: View {
    let icon: String  // SF Symbol name
    let label: String
    let status: String
    let color: Color
    let details: String

    public init(
        icon: String,
        label: String,
        status: String,
        color: Color,
        details: String
    ) {
        self.icon = icon
        self.label = label
        self.status = status
        self.color = color
        self.details = details
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Status indicator dot
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(color)
                }

                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        StatusIndicatorView(
            icon: "network",
            label: "Bridge",
            status: "Active",
            color: .green,
            details: "Port 12345"
        )

        StatusIndicatorView(
            icon: "arrow.left.arrow.right",
            label: "Charles Proxy",
            status: "Available",
            color: .green,
            details: "localhost:8888"
        )

        StatusIndicatorView(
            icon: "arrow.left.arrow.right",
            label: "Charles Proxy",
            status: "Unavailable",
            color: .red,
            details: "Connection refused"
        )
    }
    .padding()
}
