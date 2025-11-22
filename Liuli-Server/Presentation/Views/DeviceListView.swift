import SwiftUI

/// View displaying list of connected devices
public struct DeviceListView: View {
    let devices: [DeviceConnection]

    public init(devices: [DeviceConnection]) {
        self.devices = devices
    }

    public var body: some View {
        if devices.isEmpty {
            EmptyDeviceListView()
        } else {
            Table(devices) {
                TableColumn("Device Name") { device in
                    DeviceRowView(device: device)
                }
                TableColumn("Connected At") { device in
                    Text(device.connectedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
                TableColumn("Status") { device in
                    StatusBadge(status: device.status)
                }
                TableColumn("Traffic") { device in
                    TrafficView(bytesSent: device.bytesSent, bytesReceived: device.bytesReceived)
                }
            }
        }
    }
}

/// Status badge for device connection status
private struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status == .active ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Traffic statistics view
private struct TrafficView: View {
    let bytesSent: Int64
    let bytesReceived: Int64

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("↑ \(formatBytes(bytesSent))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("↓ \(formatBytes(bytesReceived))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.formatTraffic(bytes)
    }
}
