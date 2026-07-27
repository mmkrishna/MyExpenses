import SwiftUI

/// How much a card asserts itself. Using one weight everywhere makes a screen
/// read as clutter — rows should recede so the summaries above them can lead.
enum CardElevation {
    case flat        // list rows: an outline, no lift
    case raised      // standard summary card
    case prominent   // the one card a screen is about

    var shadowRadius: CGFloat {
        switch self {
        case .flat: 0
        case .raised: 14
        case .prominent: 26
        }
    }
    var shadowY: CGFloat {
        switch self {
        case .flat: 0
        case .raised: 6
        case .prominent: 12
        }
    }
    var shadowOpacity: Double {
        switch self {
        case .flat: 0
        case .raised: 0.05
        case .prominent: 0.10
        }
    }
}

/// The surface every other component sits on: a soft, elevated card with a
/// hairline edge (which carries the border in dark mode, where shadows vanish).
struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.cardRadius
    var padding: CGFloat = Theme.Spacing.lg
    var elevation: CardElevation = .raised

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(elevation.shadowOpacity),
                    radius: elevation.shadowRadius, x: 0, y: elevation.shadowY)
    }
}

extension View {
    func cardStyle(
        cornerRadius: CGFloat = Theme.cardRadius,
        padding: CGFloat = Theme.Spacing.lg,
        elevation: CardElevation = .raised
    ) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, padding: padding, elevation: elevation))
    }
}
