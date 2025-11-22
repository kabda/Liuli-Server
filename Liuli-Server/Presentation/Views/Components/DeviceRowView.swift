import SwiftUI

/// Device row component for table
public struct DeviceRowView: View {
    let device: DeviceConnection

    public init(device: DeviceConnection) {
        self.device = device
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .foregroundStyle(.blue)
            Text(device.deviceName)
                .font(.body)
        }
    }
}
