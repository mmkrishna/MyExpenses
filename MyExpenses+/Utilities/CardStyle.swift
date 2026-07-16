import SwiftUI

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.background.secondary)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

struct GlassCardBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, padding: padding))
    }

    func glassCardStyle(cornerRadius: CGFloat = 20, padding: CGFloat = 18) -> some View {
        modifier(GlassCardBackground(cornerRadius: cornerRadius, padding: padding))
    }
}
