import SwiftUI

/// Empty state view when no devices are connected
public struct EmptyDeviceListView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No devices connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Connect an iOS device running Liuli-iOS to see it here")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
