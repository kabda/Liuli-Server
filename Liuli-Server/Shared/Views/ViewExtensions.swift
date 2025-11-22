import SwiftUI

/// Hover effect for menu items
extension View {
    func hoverEffect() -> some View {
        self.background(
            GeometryReader { geometry in
                HoverEffectBackground()
            }
        )
    }
}

/// Hover effect background
private struct HoverEffectBackground: View {
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                case .ended:
                    isHovering = false
                }
            }
    }
}
