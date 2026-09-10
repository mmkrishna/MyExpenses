import SwiftUI

/// The app's tab bar.
///
/// iPadOS 18 and later put the system tab bar along the *top* of the screen,
/// and neither SwiftUI nor UIKit exposes a way to move it back down — the
/// `tabBarPlacement` environment value is read-only, and `UITabBarController`
/// only chooses between a tab bar and a sidebar. So the bar is drawn here
/// instead, which is what keeps the same chrome on an iPhone and an iPad.
struct BottomTabBar: View {
    @Binding var selection: AppTab
    /// The screen's bottom safe area, measured by the container. Passed in
    /// rather than escaped with `.ignoresSafeArea()`, which does not bleed out
    /// of an overlay — the blur has to reach the very bottom of the display or
    /// content shows through sharp in the home indicator strip.
    var bottomSafeArea: CGFloat = 0
    /// Called when the item for the tab already showing is tapped again.
    var onReselect: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Ties the highlight to whichever item is selected, so it travels between
    /// them instead of fading out in one place and in at another.
    @Namespace private var highlight

    private var metrics: TabBarMetrics {
        TabBarMetrics(horizontal: horizontalSizeClass, vertical: verticalSizeClass)
    }

    var body: some View {
        // The capsule alone is not the whole effect. Content scrolls behind the
        // floating bar and stays sharp beside and below it, which is what makes
        // the bar look stuck on rather than sitting over the page. The system
        // bars pair the glass with a scroll edge effect — a full-width blur that
        // ramps up towards the screen edge — so the scrim sits behind the
        // capsule as a sibling, where it can bleed into the home indicator area.
        ZStack(alignment: .bottom) {
            scrollEdgeEffect
            capsule
        }
    }

    /// Full-width blur under the bar, fading out upwards so there is no hard
    /// line where it begins, and running to the very bottom of the screen.
    private var scrollEdgeEffect: some View {
        Rectangle()
            .fill(.bar)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.55), location: 0.3),
                        .init(color: .black, location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: metrics.height + 44 + bottomSafeArea)
            .frame(maxWidth: .infinity)
            // Negative padding pulls the scrim down past the capsule, over the
            // home indicator, since the stack aligns their bottoms.
            .padding(.bottom, -bottomSafeArea)
            .allowsHitTesting(false)
    }

    private var capsule: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: tab == selection,
                    metrics: metrics,
                    highlight: highlight,
                    reduceMotion: reduceMotion
                ) {
                    guard tab != selection else {
                        onReselect()
                        return
                    }
                    Haptics.selection()
                    // Sliding the highlight across the bar is exactly the kind
                    // of movement Reduce Motion asks apps to drop.
                    withAnimation(reduceMotion
                                  ? nil
                                  : .spring(response: 0.35, dampingFraction: 0.78)) {
                        selection = tab
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: metrics.height - metrics.bottomInset)
        // The system bar material, not a flat fill: content scrolls underneath
        // the bar, and a solid capsule leaves it sharp right up to the edge and
        // makes the bar look pasted on. `.bar` blurs what passes behind it, the
        // way the tab bar this replaces did.
        .background(
            Capsule(style: .continuous)
                .fill(.bar)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 6)
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, metrics.bottomInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tabs")
        // Lines up with the content column, so on an iPad the bar sits under
        // the screen above it rather than running the full width of the display.
        .contentColumn()
    }
}

private struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let metrics: TabBarMetrics
    let highlight: Namespace.ID
    let reduceMotion: Bool
    let action: () -> Void

    /// Cmd-1 through Cmd-5, the shortcuts a TabView would have given us. Worth
    /// keeping now the app ships for iPad, where a keyboard is common.
    private var shortcut: KeyboardShortcut? {
        guard let index = AppTab.allCases.firstIndex(of: tab), index < 9 else { return nil }
        return KeyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
    }

    /// Bumped on every tap so the symbol bounces for the item that was actually
    /// pressed — including a re-tap of the current tab — and not for the one
    /// being left behind.
    @State private var bounce = 0

    var body: some View {
        Button {
            if !reduceMotion { bounce += 1 }
            action()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: metrics.itemCornerRadius,
                                         style: .continuous)
                            .fill(Theme.primary.opacity(0.15))
                            .matchedGeometryEffect(id: "selectedTab", in: highlight)
                    }

                    Image(systemName: tab.systemImage)
                        .font(.system(size: metrics.iconPointSize, weight: .semibold))
                        .symbolEffect(.bounce, value: bounce)
                }
                .frame(width: metrics.itemWidth, height: metrics.itemHeight)

                Text(tab.title)
                    .font(.system(size: metrics.labelPointSize,
                                  weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? Theme.primary : Color.primary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Labels are already tight; let them scale but not to the point of
        // wrapping the bar into something unusable.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        // The bar caps its own Dynamic Type, because five items cannot grow
        // without breaking the row. That is exactly the case the large content
        // viewer exists for: at accessibility sizes, a long press puts the item
        // up as a full-screen HUD instead.
        .accessibilityShowsLargeContentViewer {
            Label(tab.title, systemImage: tab.systemImage)
        }
        .keyboardShortcut(shortcut)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .dashboard

    return VStack {
        Spacer()
        BottomTabBar(selection: $selection, bottomSafeArea: 34)
    }
    .background(Theme.background)
}
