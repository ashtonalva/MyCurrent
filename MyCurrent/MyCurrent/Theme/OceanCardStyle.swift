import SwiftUI

struct OceanCardModifier: ViewModifier {
    let contentPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(contentPadding)
            .background(.ultraThinMaterial)
            .overlay(AppTheme.cardOverlay.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cyan.opacity(0.14), lineWidth: 0.8)
            )
            .shadow(color: Color.blue.opacity(0.08), radius: 6, x: 0, y: 4)
    }
}

extension View {
    func oceanCard(contentPadding: CGFloat = 16) -> some View {
        modifier(OceanCardModifier(contentPadding: contentPadding))
    }
}
