import Foundation
import SwiftData

/// Erases everything the app holds about the user.
///
/// There is no server-side account behind this: sign-in is a local biometric
/// lock and CloudKit is prepared but not enabled, so every byte of the user's
/// data lives in the on-device store and in UserDefaults. Deleting all of it
/// locally *is* the whole of "delete my account".
///
/// Preferences are not cleared here — `UserProfileViewModel` and
/// `SettingsViewModel` own their keys and reset themselves, so there is one
/// place per setting rather than a second list here that could drift.
enum AccountEraser {

    /// Removes every stored transaction and category, then puts the shipped
    /// categories back. Re-seeding matters: the app cannot file an expense
    /// without categories, so a bare wipe would leave it broken rather than
    /// looking freshly installed.
    static func eraseStoredData(in context: ModelContext) throws {
        try context.delete(model: Expense.self)
        try context.delete(model: Income.self)
        try context.delete(model: ExpenseCategory.self)
        try context.save()

        _ = CategoryStore.seedBuiltInsIfNeeded(in: context)
    }
}
