import SwiftUI

/// Animated splash shown at launch, on top of the app content.
/// It starts visually identical to LaunchScreen.storyboard (the "$" ring on the
/// brand blue), so the static launch screen hands off seamlessly, then the
/// expense category icons burst outward from the center and the splash fades
/// away to reveal the app.
struct SplashScreenView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconsFlyOut = false
    @State private var logoScale: CGFloat = 1.0
    @State private var overlayOpacity: Double = 1.0

    private static let flightDuration: Double = 0.9
    private static let fadeDuration: Double = 0.35

    private var categories: [BuiltInCategory] { BuiltInCategory.allCases }

    var body: some View {
        ZStack {
            // Must match LaunchScreen.storyboard exactly, or the handoff from the
            // static launch screen to this animated one is a visible jump.
            Color(.systemIndigo)
                .ignoresSafeArea()

            // ExpenseCategory icons bursting away from the center
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                let angle = Double(index) / Double(categories.count) * 2 * .pi - .pi / 2
                let radius: CGFloat = iconsFlyOut ? 700 : 92

                Image(systemName: category.systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.18), in: Circle())
                    .rotationEffect(.degrees(iconsFlyOut ? 40 : 0))
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
                    .opacity(iconsFlyOut ? 0 : 1)
                    .animation(
                        .easeIn(duration: Self.flightDuration)
                        .delay(Double(index) * 0.03),
                        value: iconsFlyOut
                    )
            }

            // Same artwork and size as the launch screen's image view.
            Image("My Icons")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(logoScale)
        }
        .opacity(overlayOpacity)
        .accessibilityHidden(true)
        .onAppear(perform: run)
    }

    private func run() {
        guard !reduceMotion else {
            // Respect Reduce Motion: a simple fade, no flying icons.
            withAnimation(.easeInOut(duration: Self.fadeDuration).delay(0.4)) {
                overlayOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Self.fadeDuration) {
                onFinished()
            }
            return
        }

        iconsFlyOut = true

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flightDuration * 0.75) {
            withAnimation(.easeInOut(duration: Self.fadeDuration)) {
                logoScale = 1.6
                overlayOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flightDuration * 0.75 + Self.fadeDuration) {
            onFinished()
        }
    }
}

#Preview {
    SplashScreenView {}
}
