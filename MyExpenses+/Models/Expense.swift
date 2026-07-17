import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Decimal = 0
    /// Optional so that deleting a category uncategorises its expenses rather
    /// than destroying them (and because CloudKit requires optional relationships).
    var category: ExpenseCategory?
    var date: Date = Date.now
    var notes: String = ""
    var paymentMethod: String = "Cash"
    var merchant: String = ""
    var currency: String = "USD"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Non-nil only on the expense that anchors a recurring series; generated occurrences leave this nil.
    var recurrenceFrequency: RecurrenceFrequency?
    var recurrenceEndDate: Date?
    /// Shared by the anchor and every expense generated from it; nil for one-off expenses.
    var seriesID: UUID?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        category: ExpenseCategory? = nil,
        date: Date = Date(),
        notes: String = "",
        paymentMethod: String = "Cash",
        merchant: String = "",
        currency: String = CurrencyFormatter.preferredCurrencyCode,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurrenceFrequency: RecurrenceFrequency? = nil,
        recurrenceEndDate: Date? = nil,
        seriesID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.merchant = merchant
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceEndDate = recurrenceEndDate
        self.seriesID = seriesID
    }

    var isRecurring: Bool { seriesID != nil }
}
