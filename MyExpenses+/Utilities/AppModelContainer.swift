import SwiftData

/// The app's single SwiftData container, shared by the SwiftUI app and by App Intents
/// (e.g. the "Add Expense from Text" Shortcut) so both read and write the same store.
enum AppModelContainer {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([Expense.self])
        // Keep in sync with MyExpenses_App: CloudKit is prepared but not enabled.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
