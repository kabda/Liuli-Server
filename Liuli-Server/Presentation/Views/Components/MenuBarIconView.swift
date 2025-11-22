import SwiftUI

/// Menu bar icon that changes color based on bridge state
public struct MenuBarIconView: View {
    let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var body: some View {
        Image(systemName: "network")
            .foregroundStyle(isEnabled ? .green : .gray)
            .font(.system(size: 14, weight: .medium))
    }
}

#Preview {
    HStack(spacing: 20) {
        MenuBarIconView(isEnabled: true)
        MenuBarIconView(isEnabled: false)
    }
    .padding()
}
