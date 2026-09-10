import SwiftUI

// MARK: - Adaptive layout
//
// The app is one design, drawn for a phone, and it should read the same on an
// iPad: the same cards, the same large titles, the same tab bar along the
// bottom. What an iPad actually changes is how much room there is — and simply
// stretching a phone layout across 1000pt makes cards go letterbox-thin and
// runs text into long, hard-to-scan lines.
//
// So the layout never changes shape by device. It is laid out in a centred
// column of roughly phone width wherever the screen is wider than that, and is
// left exactly as-is on iPhone.

enum Layout {
    /// The one content width. Everything — screens, forms, the tab bar — uses
    /// it, so nothing is wider or narrower than anything else on an iPad.
    static let column: CGFloat = 700
    /// Ceiling for artwork sized as a fraction of the screen.
    static let artworkStage: CGFloat = 430
}

/// Sizes for `BottomTabBar`. The bar keeps the same shape on both devices, but
/// an iPad is held further away and has room to spare, so the targets and
/// labels step up rather than staying at phone size on a much bigger screen.
struct TabBarMetrics {
    /// True only where there is room in *both* directions. Width alone is not
    /// enough: a Pro Max in landscape reports regular width on a 440pt-tall
    /// screen, and an 86pt bar there would eat the display.
    let isRegular: Bool

    init(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) {
        isRegular = horizontal == .regular && vertical == .regular
    }

    /// Height the bar occupies above the safe area. Fixed rather than measured,
    /// because screens have to reserve exactly this much room.
    var height: CGFloat { isRegular ? 86 : 64 }
    var iconPointSize: CGFloat { isRegular ? 24 : 18 }
    var labelPointSize: CGFloat { isRegular ? 14 : 11 }
    var itemWidth: CGFloat { isRegular ? 68 : 46 }
    var itemHeight: CGFloat { isRegular ? 42 : 30 }
    var itemCornerRadius: CGFloat { isRegular ? 21 : 15 }
    var bottomInset: CGFloat { isRegular ? 10 : 8 }
}

private struct TabBarClearanceModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        // Must resolve to the same metrics the bar itself uses, or the room
        // reserved here and the room the bar takes drift apart.
        let metrics = TabBarMetrics(horizontal: horizontalSizeClass,
                                    vertical: verticalSizeClass)
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: metrics.height)
        }
    }
}

extension View {
    /// Keeps a screen's content clear of the tab bar.
    ///
    /// Applied by each screen to its own scrolling content, inside its
    /// NavigationStack. Insetting from the container that draws the bar does
    /// not work: neither TabView nor a plain container carries the inset down
    /// into a NavigationStack's scroll view, so the last rows of a list and
    /// anything anchored to the bottom end up beneath the bar.
    func tabBarClearance() -> some View {
        modifier(TabBarClearanceModifier())
    }
}

private struct ContentColumnModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Caps and centres the view on regular-width screens. A no-op on iPhone,
    /// so applying it cannot change the layout the design was drawn for.
    func contentColumn(_ maxWidth: CGFloat = Layout.column) -> some View {
        modifier(ContentColumnModifier(maxWidth: maxWidth))
    }
}
