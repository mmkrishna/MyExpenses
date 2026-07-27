import SwiftUI

struct SplashView: View {

    var onFinished: (() -> Void)? = nil

    // MARK: Animation States

    @State private var walletScale: CGFloat = 0.88
    @State private var walletOpacity = 0.0

    @State private var receiptOffset: CGFloat = 120
    @State private var receiptOpacity = 0.0
    @State private var receiptScale: CGFloat = 0.9
    @State private var receiptRotation: Double = -12

    @State private var moneyFrontOffset: CGFloat = 170
    @State private var moneyFrontOpacity = 0.0
    @State private var moneyFrontRotation: Double = -16

    @State private var moneyBackOffset: CGFloat = 120
    @State private var moneyBackOpacity = 0.0
    @State private var moneyBackRotation: Double = 15

    @State private var coinOffset: CGFloat = 80
    @State private var coinOpacity = 0.0
    @State private var coinScale: CGFloat = 0.6
    @State private var coinRotation = -45.0

    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 20

    @State private var float = false

    var body: some View {

        GeometryReader { geo in

            ZStack {

                // Background

                Image("LaunchGradient")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack {

                    Spacer()

                    ZStack {

                        // MARK: Wallet Back

                        Image("WalletBody")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.62)
                            .offset(x: -10, y: 0)
                            .scaleEffect(walletScale)
                            .opacity(walletOpacity)
                            .shadow(color: .black.opacity(0.18),
                                    radius: 12,
                                    x: 0,
                                    y: 8)


                        // MARK: Money Back

                        Image("Money")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.9)
                            .rotationEffect(.degrees(moneyBackRotation))
                            .offset(x: 38, y: moneyBackOffset)
                            .opacity(moneyBackOpacity)

                        // MARK: Money Front

                        Image("Money")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.9)
                            .rotationEffect(.degrees(moneyFrontRotation))
                            .offset(x: 32, y: -80)
                            .opacity(moneyFrontOpacity)

                        // MARK: Coin

                        Image("Coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 1)
                            .offset(x: 90, y: coinOffset)
                            .scaleEffect(coinScale)
                            .rotationEffect(.degrees(coinRotation))
                            .opacity(coinOpacity)
                        
                        
                        // MARK: Receipt

                        Image("Receipt")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.8)
                            .scaleEffect(receiptScale)
                            .rotationEffect(.degrees(receiptRotation))
                            .offset(x: -35, y: -95)
                            .opacity(receiptOpacity)

                        // MARK: Wallet Front

                        Image("WalletFlap")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.62)
                            .offset(x: -10, y: 0)

                    }
                    .offset(y: float ? -1 : 3)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: float
                    )

                    Spacer()

                    VStack(spacing: 8) {

                        //Text("My Expenses")
                            //.font(.system(size: 34,
                                         // weight: .bold))
                           // .foregroundColor(.white)

                        //Text("Smart Expense Tracker")
                           // .font(.headline)
                           // .foregroundColor(.white.opacity(0.9))

                    }
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)

                    Spacer()
                        .frame(height: 70)

                }

            }

        }
        .onAppear {

            startAnimation()

        }

    }

    // MARK: Animation

    func startAnimation() {

        float = true

        withAnimation(
            .spring(response: 0.45,
                    dampingFraction: 0.72)
        ) {

            walletScale = 1
            walletOpacity = 1

        }

        Task {

            try? await Task.sleep(for: .milliseconds(350))

            withAnimation(
                .interpolatingSpring(
                    stiffness: 170,
                    damping: 12
                )
            ) {

                receiptOffset = -75
                receiptOpacity = 1
                receiptScale = 1
                receiptRotation = 0

            }
            try? await Task.sleep(for: .milliseconds(180))

            withAnimation(.easeOut(duration: 0.15)) {
                receiptOffset = -70
            }

            try? await Task.sleep(for: .milliseconds(120))

            withAnimation(.easeIn(duration: 0.12)) {
                receiptOffset = -75
            }

            try? await Task.sleep(for: .milliseconds(250))

            withAnimation(
                .spring(response: 0.50,
                        dampingFraction: 0.72)
            ) {
                moneyBackOffset = -62
                moneyBackOpacity = 0.85
                moneyBackRotation = 8
            }

            try? await Task.sleep(for: .milliseconds(80))

            withAnimation(
                .spring(response: 0.45,
                        dampingFraction: 0.70)
            ) {
                moneyFrontOffset = -48
                moneyFrontOpacity = 1
                moneyFrontRotation = -4
            }
            try? await Task.sleep(for: .milliseconds(250))

            withAnimation(
                .spring(response: 0.45,
                        dampingFraction: 0.70)
            ) {

                coinOffset = -15
                coinOpacity = 1
                coinScale = 1
                coinRotation = 360

            }

            try? await Task.sleep(for: .milliseconds(350))

            withAnimation(.easeOut(duration: 0.4)) {

                titleOpacity = 1
                titleOffset = 0

            }

            try? await Task.sleep(for: .seconds(1))

            await MainActor.run {

                onFinished?()

            }

        }

    }

}

#Preview {

    SplashView()

}
