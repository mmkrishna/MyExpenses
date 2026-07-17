import Foundation
import SwiftData

/// Seeding and lookup for categories.
enum CategoryStore {
    /// Inserts the built-in categories the first time the app runs.
    /// Idempotent: it only seeds when the table is empty, so it can be called
    /// on every launch without duplicating rows.
    @discardableResult
    static func seedBuiltInsIfNeeded(in context: ModelContext) -> Bool {
        let existing = (try? context.fetchCount(FetchDescriptor<ExpenseCategory>())) ?? 0
        guard existing == 0 else { return false }

        for (index, builtIn) in BuiltInCategory.allCases.enumerated() {
            context.insert(builtIn.makeCategory(sortOrder: index))
        }
        try? context.save()
        return true
    }

    static func all(in context: ModelContext) -> [ExpenseCategory] {
        let descriptor = FetchDescriptor<ExpenseCategory>(sortBy: ExpenseCategory.displayOrder)
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Finds a category by name, case-insensitively.
    static func find(named name: String, in context: ModelContext) -> ExpenseCategory? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all(in: context).first { $0.name.lowercased() == target }
    }

    /// Finds a category by name, creating a custom one if it doesn't exist.
    /// Used when restoring a backup that references a category the user has since
    /// deleted, so no expense loses its category on the way back in.
    static func findOrCreate(named name: String, in context: ModelContext) -> ExpenseCategory {
        if let existing = find(named: name, in: context) { return existing }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextOrder = (all(in: context).map(\.sortOrder).max() ?? 0) + 1
        let category = ExpenseCategory(
            name: trimmed.isEmpty ? BuiltInCategory.fallback.rawValue : trimmed,
            symbolName: "tag.fill",
            colorHex: "#8E8E93",
            isBuiltIn: false,
            sortOrder: nextOrder
        )
        context.insert(category)
        return category
    }

    /// The category to fall back to when nothing else matches.
    static func fallback(in context: ModelContext) -> ExpenseCategory {
        findOrCreate(named: BuiltInCategory.fallback.rawValue, in: context)
    }

    static func resolve(_ builtIn: BuiltInCategory, in context: ModelContext) -> ExpenseCategory {
        findOrCreate(named: builtIn.rawValue, in: context)
    }
}
