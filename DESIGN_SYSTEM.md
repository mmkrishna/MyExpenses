# Design System

The shared visual language for our SwiftUI apps (Event Planner, MyExpenses+, and
future projects). It is deliberately small: a violet brand, soft elevated cards,
the system font on a fixed type scale, and a handful of reusable components.

> **How to use this in a new project:** copy `Theme.swift` and `CardStyle.swift`
> (both reproduced in full below) into the project, set the `AccentColor` asset to
> the brand violet, then build screens out of the components and rules here.

---

## 1. Principles

1. **One weight per screen.** Elevation carries hierarchy, not decoration. A screen
   has at most one *prominent* card (the thing the screen is about); summaries are
   *raised*; list rows are *flat*. Using one shadow weight everywhere reads as clutter.
2. **The system font, at explicit sizes.** No custom fonts. Use `.system(size:weight:)`
   with the scale in §3 — not Dynamic Type text styles — so layouts stay predictable.
   Reserve `.primary / .secondary / .tertiary` for the text-colour hierarchy.
3. **Gradient is a spotlight.** The CTA gradient appears only on the hero card and
   primary call-to-action buttons. Everything else is a flat surface.
4. **Design both appearances from the start.** Every colour is adaptive. In dark mode
   shadows disappear, so a hairline border carries the card edge instead.
5. **Generous breathing room.** Space between sections does more for legibility than any
   card styling. Default to the `section` spacing between major blocks.
6. **Motion is subtle and consistent.** Springs for interaction, a short fade-and-rise
   for content appearing, `numericText` transitions for changing figures.

---

## 2. Colour

All colours are defined once in `Theme` and resolve per appearance. The brand violet
also lives in the asset catalog as `AccentColor` so system-tinted controls (tab bar,
switches, pickers, `Charts`) match without extra work.

### Brand
| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#7B61FF` | Brand violet — accents, selected states, ring/bar fills |
| `accent` | `#A78BFA` | Lighter violet — the second stop in the CTA gradient |
| `success` | `#22C55E` | Positive / confirmed |
| `warning` | `#F59E0B` | Caution / nearing a limit |
| `danger` | `#EF4444` | Destructive / over budget / declined |

### Surfaces (light / dark)
| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `background` | `#F6F5FB` | `#0B0B0F` | Screen background (violet-tinted, not neutral grey) |
| `card` | `#FFFFFF` | `#1C1C1E` | Card and row surfaces |
| `cardInset` | `#F3F1FA` | `#2A2A2E` | Inset wells inside a card |
| `separator` | `#ECECF1` | `#2C2C31` | Divider lines, unfilled progress track |
| `hairline` | black @ 5% | white @ 8% | 0.5pt card border (carries the edge in dark) |

### Gradient
`ctaGradient`: `#7B61FF → #9D7BFF`, `topLeading → bottomTrailing`. Hero card, primary
CTA buttons, and the floating add button only.

### `AccentColor` asset values (sRGB components)
- Light: R `0.482` G `0.380` B `1.000`  (`#7B61FF`)
- Dark:  R `0.616` G `0.482` B `1.000`  (`#9D7BFF`)

---

## 3. Typography

System font (SF Pro). Pick from this scale; don't invent sizes.

| Role | Size / weight | Colour |
|------|---------------|--------|
| Screen title | `.largeTitle` via `navigationTitle` (`.large`) | primary |
| Hero figure | `40 bold`, `design: .rounded` | white on gradient |
| Metric / card value | `22 bold` | primary |
| Amount (row) | `18 bold`, `monospacedDigit()` | primary |
| Row title | `16 semibold` | primary |
| Section header | `17 semibold` (`.headline`) | primary |
| Body / field | `16 regular–medium` | primary |
| Label | `13 medium` | secondary |
| Caption | `12 medium` | secondary / tertiary |
| Small caption | `11 medium` or `semibold` | secondary / tertiary |
| Badge / pill | `9 black`, `tracking(0.4)`, uppercased | tinted |

Rules of thumb: prominent numbers use `.rounded`; any tabular figure gets
`.monospacedDigit()`; changing numbers animate with `.contentTransition(.numericText())`.

---

## 4. Spacing

A single scale (`Theme.Spacing`):

| Name | Value | Typical use |
|------|-------|-------------|
| `xs` | 6 | Icon-to-label, tight stacks |
| `sm` | 10 | Chip internals |
| `md` | 16 | Card padding (compact), grid gutters |
| `lg` | 20 | Card padding (standard), CTA insets |
| `screen` | 22 | Screen-edge horizontal padding |
| `xl` | 28 | Roomy card padding |
| `section` | 32 | Between major sections |

---

## 5. Radius & elevation

- **Corner radius:** cards `22` (`Theme.cardRadius`), icon tiles `~0.31 × size`
  (≈ 11 at 36pt), small pills use `Capsule`. Always `style: .continuous`.
- **Elevation tiers** (`CardElevation`):

| Tier | Shadow radius | Y | Opacity | Use |
|------|---------------|---|---------|-----|
| `flat` | 0 | 0 | 0 | List rows — border only, no lift |
| `raised` | 14 | 6 | 0.05 | Standard summary cards (default) |
| `prominent` | 26 | 12 | 0.10 | The one hero card / CTA a screen is about |

Every card also gets a 0.5pt `hairline` border so the edge survives in dark mode.

---

## 6. Core code (drop-in)

### `Theme.swift`

```swift
import SwiftUI
import UIKit

extension Color {
    /// A colour that resolves differently in light and dark appearance.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
    // Requires a `Color(hex:)` initialiser accepting "#RRGGBB".
}

enum Theme {
    static let primary = Color(hex: "#7B61FF")
    static let accent  = Color(hex: "#A78BFA")
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#F59E0B")
    static let danger  = Color(hex: "#EF4444")

    static let background = Color.dynamic(light: Color(hex: "#F6F5FB"), dark: Color(hex: "#0B0B0F"))
    static let card       = Color.dynamic(light: .white,               dark: Color(hex: "#1C1C1E"))
    static let cardInset  = Color.dynamic(light: Color(hex: "#F3F1FA"), dark: Color(hex: "#2A2A2E"))
    static let separator  = Color.dynamic(light: Color(hex: "#ECECF1"), dark: Color(hex: "#2C2C31"))
    static let hairline   = Color.dynamic(light: .black.opacity(0.05), dark: .white.opacity(0.08))

    static let ctaGradient = LinearGradient(
        colors: [Color(hex: "#7B61FF"), Color(hex: "#9D7BFF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    enum Spacing {
        static let xs: CGFloat = 6,  sm: CGFloat = 10, md: CGFloat = 16
        static let lg: CGFloat = 20, screen: CGFloat = 22
        static let xl: CGFloat = 28, section: CGFloat = 32
    }

    static let cardRadius: CGFloat = 22
}

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct AppearModifier: ViewModifier {
    var index: Double = 0
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear { withAnimation(.easeOut(duration: 0.5).delay(0.06 * index)) { shown = true } }
    }
}
extension View { func appear(_ index: Double = 0) -> some View { modifier(AppearModifier(index: index)) } }

struct IconTile: View {
    let systemName: String
    var tint: Color = Theme.primary
    var size: CGFloat = 36
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay(Image(systemName: systemName)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(tint))
    }
}
```

### `CardStyle.swift`

```swift
import SwiftUI

enum CardElevation {
    case flat, raised, prominent
    var shadowRadius: CGFloat { switch self { case .flat: 0; case .raised: 14; case .prominent: 26 } }
    var shadowY: CGFloat      { switch self { case .flat: 0; case .raised: 6;  case .prominent: 12 } }
    var shadowOpacity: Double { switch self { case .flat: 0; case .raised: 0.05; case .prominent: 0.10 } }
}

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.cardRadius
    var padding: CGFloat = Theme.Spacing.lg
    var elevation: CardElevation = .raised
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(elevation.shadowOpacity),
                    radius: elevation.shadowRadius, x: 0, y: elevation.shadowY)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = Theme.cardRadius,
                   padding: CGFloat = Theme.Spacing.lg,
                   elevation: CardElevation = .raised) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, padding: padding, elevation: elevation))
    }
}
```

> `Color(hex:)` is assumed to exist (accepts `"#RRGGBB"`, falls back to grey on a bad
> value). If the project doesn't have one, add it alongside `Theme`.

---

## 7. Component catalogue

| Component | What it is | Notes |
|-----------|------------|-------|
| **Card** — `.cardStyle(elevation:)` | The base surface everything sits on | Pick the elevation tier by role (§5) |
| **IconTile** | Rounded, tinted icon tile | `tint.opacity(0.14)` fill, tinted glyph. Rows & cards |
| **Metric / stat card** | IconTile top-left, `22 bold` value, `13 medium` label below | `minHeight ≈ 104`, `padding: .md`, two-up in a grid |
| **Primary button** | Pill CTA | Full-width → `ctaGradient` + soft violet shadow; compact → `accentColor` fill. Always `ScaleButtonStyle` |
| **Hero card** | The screen's headline figure | `ctaGradient` background, white text, `prominent` shadow, radius 22 |
| **Row** | List item | IconTile + `16 semibold` title + `12 medium` subtitle + `18 bold` trailing amount |
| **Category / choice chip** | Selectable circular icon + caption | Filled when selected, `color.opacity(0.15)` when not |
| **Progress** | Capsule bar or ring | Track = `separator`, fill = `primary`; animate `easeOut 0.6–0.9` |
| **Badge / pill** | Tiny status tag | `9 black`, `tracking(0.4)`, uppercased, `tint.opacity(0.15)` capsule |

Selected-icon pattern (used in pickers): selected = white glyph on `accentColor`;
unselected = `accentColor` glyph on `accentColor.opacity(0.12)`.

---

## 8. Motion

| Situation | Animation |
|-----------|-----------|
| Press feedback | `ScaleButtonStyle` — spring `response 0.3, damping 0.65`, scale `0.97` |
| Content appearing | `.appear(index)` — `easeOut 0.5`, staggered `0.06 × index`, rise `14pt` |
| Element settling in place | spring `response 0.45–0.55, damping 0.70–0.72` |
| Changing figures | `.contentTransition(.numericText())` |
| Progress fill | `easeOut 0.6` (updates) / `0.9` (first appearance) |

Respect **Reduce Motion**: swap elaborate entrances for a plain fade.

---

## 9. Layout patterns

- **Screen:** `NavigationStack` → `ScrollView` (or `List`) with `.background(Theme.background)`,
  horizontal padding `Spacing.screen`, `Spacing.section` between blocks. `navigationTitle`
  in `.large` for top-level tabs, `.inline` for pushed/sheet screens.
- **`List` / `Form` screens:** hide the grey grouped background and adopt the system —
  `.scrollContentBackground(.hidden).background(Theme.background)`, and put rows on the
  card colour with `.listRowBackground(Theme.card)`. Keep native `List` for swipe actions.
- **Nav bar:** transparent at rest, blends into the background; a material blur appears once
  content scrolls under it (configure `UINavigationBarAppearance`: transparent
  `scrollEdgeAppearance`, default `standardAppearance`).
- **Tab bar:** default system chrome; the violet `AccentColor` tints the selected tab.
- **Grids:** two-up `LazyVGrid` for metric cards, gutter `Spacing.md`.

---

## 10. New-project checklist

- [ ] Add `Theme.swift` + `CardStyle.swift` and a `Color(hex:)` initialiser.
- [ ] Set the `AccentColor` asset to the brand violet (light + dark values in §2).
- [ ] Screen backgrounds use `Theme.background` (never `systemGroupedBackground`).
- [ ] Cards use `.cardStyle(elevation:)`; one `prominent` per screen, at most.
- [ ] Text uses the §3 scale + `.primary/.secondary/.tertiary`; numbers `monospacedDigit()`.
- [ ] Gradient only on hero + primary CTA.
- [ ] Buttons/cards that tap use `ScaleButtonStyle`; content uses `.appear()`.
- [ ] Verify every screen in **both** light and dark before shipping.

---

*Derived from the Event Planner and MyExpenses+ codebases. Update this file when the
system evolves so it stays the single source of truth.*
