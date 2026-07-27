import SwiftUI
import UIKit

// MARK: - Adaptive colour helper

extension Color {
    /// A colour that resolves differently in light and dark appearance.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Theme
//
// The app's design language, shared with our Event Planner app: a violet brand,
// soft elevated cards, and a generous spacing scale. `Color.accentColor` is the
// same violet (defined in the asset catalog) so system-tinted controls match.

enum Theme {
    // Brand palette — vivid enough to read the same in light and dark.
    static let primary = Color(hex: "#7B61FF")   // Violet
    static let accent  = Color(hex: "#A78BFA")   // Light violet, for CTA gradients
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#F59E0B")
    static let danger  = Color(hex: "#EF4444")

    // Adaptive surfaces.
    static let background = Color.dynamic(light: Color(hex: "#F6F5FB"), dark: Color(hex: "#0B0B0F"))
    static let card       = Color.dynamic(light: .white,               dark: Color(hex: "#1C1C1E"))
    static let cardInset  = Color.dynamic(light: Color(hex: "#F3F1FA"), dark: Color(hex: "#2A2A2E"))
    static let separator  = Color.dynamic(light: Color(hex: "#ECECF1"), dark: Color(hex: "#2C2C31"))
    /// Barely-there card border. Carries the edge in dark mode, where a shadow
    /// on a near-black background does nothing.
    static let hairline   = Color.dynamic(light: .black.opacity(0.05),
                                          dark: .white.opacity(0.08))

    /// The one gradient — reserved for CTAs and the hero card.
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "#7B61FF"), Color(hex: "#9D7BFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Spacing scale.
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let screen: CGFloat = 22   // screen-edge horizontal padding
        static let xl: CGFloat = 28
        static let section: CGFloat = 32  // between major sections
    }

    static let cardRadius: CGFloat = 22
}

// MARK: - Button style

/// Subtle press-scale used on tappable cards and buttons.
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Appear animation

/// Fades and slides content up on first appearance. `index` staggers items.
struct AppearModifier: ViewModifier {
    var index: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.06 * index)) {
                    shown = true
                }
            }
    }
}

extension View {
    func appear(_ index: Double = 0) -> some View {
        modifier(AppearModifier(index: index))
    }
}

// MARK: - Icon tile

/// Rounded, tinted icon tile used on cards and rows.
struct IconTile: View {
    let systemName: String
    var tint: Color = Theme.primary
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
            )
    }
}
