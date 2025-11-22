import SwiftUI

/// Statistics window view (FR-027)
public struct StatisticsView: View {
    @Bindable var viewModel: StatisticsViewModel

    public init(viewModel: StatisticsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(
                title: "statistics.title".localized(),
                onClose: { viewModel.send(.close) }
            )

            // Overview section
            OverviewSection(state: viewModel.state)

            Divider()

            // Connection list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.state.connections) { connection in
                        ConnectionRow(connection: connection)
                        Divider()
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .task {
            viewModel.send(.onAppear)
        }
    }
}

/// Overview section showing aggregate statistics
struct OverviewSection: View {
    let state: StatisticsViewState

    var body: some View {
        HStack(spacing: 32) {
            StatisticCard(
                title: "statistics.totalConnections".localized(),
                value: "\(state.statistics.totalConnectionCount)"
            )

            StatisticCard(
                title: "statistics.activeConnections".localized(),
                value: "\(state.statistics.activeConnectionCount)"
            )

            StatisticCard(
                title: "statistics.totalBytes".localized(),
                value: formatBytes(state.statistics.totalBytesTransferred)
            )

            StatisticCard(
                title: "statistics.uptime".localized(),
                value: formatUptime(state.statistics.uptimeSeconds)
            )
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .binary
        )
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

/// Single statistic card
struct StatisticCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Connection row component (FR-027)
struct ConnectionRow: View {
    let connection: SOCKS5Connection

    var body: some View {
        HStack(spacing: 12) {
            // State indicator
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            // Source info
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.sourceAddress)
                    .font(.system(.body, design: .monospaced))

                Text("statistics.connectedAt".localized(args: formatTime(connection.connectedAt)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Arrow
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)

            // Destination info
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.destinationAddress)
                    .font(.system(.body, design: .monospaced))

                Text("statistics.bytesSent".localized(args: formatBytes(connection.bytesSent)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Bytes received
            Text(formatBytes(connection.bytesReceived))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var stateColor: Color {
        switch connection.state {
        case .connected:
            return .green
        case .negotiating:
            return .blue
        case .forwarding:
            return .green
        case .closed:
            return .gray
        case .error:
            return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: bytes,
            countStyle: .binary
        )
    }
}

/// Header view with close button
struct HeaderView: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    StatisticsView(
        viewModel: StatisticsViewModel(
            trackStatisticsUseCase: TrackStatisticsUseCase(
                connectionRepository: InMemoryConnectionRepository()
            )
        )
    )
}
