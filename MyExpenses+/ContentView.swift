import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("appearancePreference") private var appearanceRawValue = AppearanceMode.system.rawValue
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false

    @State private var isUnlocked = true
    @State private var didGenerateRecurringExpenses = false
    @State private var showingSplash = true
    @State private var persistenceError: String?

    @Query private var expenses: [Expense]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceRawValue)?.colorScheme
    }

    var body: some View {

        ZStack {

            // Main App

            RootTabView()
                .opacity(showingSplash ? 0 : (isUnlocked ? 1 : 0))

            // Face ID Lock

            if !isUnlocked && !showingSplash {
                LockedView(
                    biometryName: BiometricAuthService.biometryTypeName,
                    onUnlock: authenticate
                )
            }

            // Splash

            if showingSplash {

                SplashView {

                    withAnimation(.easeInOut(duration: 0.35)) {
                        showingSplash = false
                    }

                }
                .transition(.opacity)
                .zIndex(100)

            }

        }
        .preferredColorScheme(preferredColorScheme)

        .onAppear {

            if faceIDEnabled {
                isUnlocked = false
            }

            if !didGenerateRecurringExpenses {

                didGenerateRecurringExpenses = true

                do {
                    try RecurrenceGenerationService.generateDueOccurrences(
                        from: expenses,
                        context: modelContext
                    )
                } catch {
                    persistenceError = "Could not generate recurring expenses. Please try again."
                }

            }

        }

        .onChange(of: showingSplash) { _, finished in

            if !finished && faceIDEnabled {
                authenticate()
            }

        }

        .onChange(of: scenePhase) { _, phase in

            if faceIDEnabled && phase != .active {
                isUnlocked = false
            }

        }

        .alert("MyExpenses+", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {

            Button("OK", role: .cancel) {}

        } message: {

            Text(persistenceError ?? "")

        }

    }

    private func authenticate() {

        Task {

            let success = await BiometricAuthService.authenticate(
                reason: "Unlock your expenses"
            )

            await MainActor.run {

                isUnlocked = success

            }

        }

    }

}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
        .environment(UserProfileViewModel())
}
