import SwiftData
import SwiftUI

/// A spending category. Built-ins are seeded on first launch; users can add
/// their own, which is why this is a model rather than an enum.
///
/// CloudKit-compatible by construction: every attribute has a default and the
/// relationship is optional.
@Model
final class ExpenseCategory {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "tag.fill"
    var colorHex: String = "#8E8E93"
    /// Built-ins can be renamed/recoloured but not deleted, so an expense always
    /// has somewhere sensible to live.
    var isBuiltIn: Bool = false
    var sortOrder: Int = 0

    /// Nullify rather than cascade: deleting a category must never delete the
    /// user's expenses, only uncategorise them.
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        colorHex: String,
        isBuiltIn: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }

    var color: Color { Color(hex: colorHex) }
}

extension ExpenseCategory {
    /// Sorted the way the pickers and lists should present them.
    static var displayOrder: [SortDescriptor<ExpenseCategory>] {
        [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
    }
}
