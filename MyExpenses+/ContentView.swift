import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("appearancePreference") private var appearanceRawValue = AppearanceMode.system.rawValue
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @State private var isUnlocked = true
    @State private var didGenerateRecurringExpenses = false
    @State private var showingSplash = true

    @Query private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceRawValue)?.colorScheme
    }

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(isUnlocked ? 1 : 0)

            if !isUnlocked {
                LockedView(biometryName: BiometricAuthService.biometryTypeName, onUnlock: authenticate)
            }

            if showingSplash {
                SplashScreenView {
                    showingSplash = false
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            if faceIDEnabled {
                isUnlocked = false
                authenticate()
            }
            if !didGenerateRecurringExpenses {
                didGenerateRecurringExpenses = true
                RecurrenceGenerationService.generateDueOccurrences(from: expenses, context: modelContext)
            }
        }
    }

    private func authenticate() {
        Task {
            let success = await BiometricAuthService.authenticate(reason: "Unlock your expenses")
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
