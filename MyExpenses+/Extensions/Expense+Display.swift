import SwiftUI

/// An expense's category is optional (deleting a category uncategorises rather
/// than deletes), so presentation falls back to the built-in "Other" look.
extension Expense {
    var categoryName: String {
        category?.name ?? BuiltInCategory.fallback.rawValue
    }

    var categorySymbol: String {
        category?.symbolName ?? BuiltInCategory.fallback.systemImage
    }

    var categoryColor: Color {
        category?.color ?? Color(hex: BuiltInCategory.fallback.colorHex)
    }
}
