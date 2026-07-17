import SwiftData

/// The app's single SwiftData container, shared by the SwiftUI app and by App Intents
/// (e.g. the "Add Expense from Text" Shortcut) so both read and write the same store.
enum AppModelContainer {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        // CloudKit is prepared but not enabled: flipping this to `.automatic`
        // (with the iCloud capability re-added) turns on sync.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: MyExpensesMigrationPlan.self,
                configurations: [configuration]
            )
            CategoryStore.seedBuiltInsIfNeeded(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
