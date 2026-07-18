import Foundation
import SwiftData
import Observation

@Observable
final class AddEditExpenseViewModel {
    private let editingExpense: Expense?

    var amountText: String
    var category: ExpenseCategory?
    var merchant: String
    var date: Date
    var notes: String
    var paymentMethod: PaymentMethod

    /// nil means "Never" (not recurring).
    var recurrenceFrequency: RecurrenceFrequency?
    var recurrenceHasEndDate: Bool
    var recurrenceEndDate: Date

    init(editing expense: Expense? = nil) {
        editingExpense = expense
        amountText = expense.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? ""
        category = expense?.category
        merchant = expense?.merchant ?? ""
        date = expense?.date ?? Date()
        notes = expense?.notes ?? ""
        paymentMethod = expense.flatMap { PaymentMethod(rawValue: $0.paymentMethod) } ?? .cash

        recurrenceFrequency = expense?.recurrenceFrequency
        if let endDate = expense?.recurrenceEndDate {
            recurrenceHasEndDate = true
            recurrenceEndDate = endDate
        } else {
            recurrenceHasEndDate = false
            recurrenceEndDate = Date()
        }
    }

    var isEditing: Bool { editingExpense != nil }

    var navigationTitle: String { isEditing ? "Edit Expense" : "Add Expense" }

    var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    var canSave: Bool {
        guard let amount = parsedAmount else { return false }
        return amount > 0
    }

    @discardableResult
    func save(context: ModelContext) -> Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }

        let expense: Expense
        if let editingExpense {
            expense = editingExpense
            expense.amount = amount
            expense.category = category
            expense.date = date
            expense.notes = notes
            expense.merchant = merchant
            expense.paymentMethod = paymentMethod.rawValue
            expense.updatedAt = Date()
        } else {
            expense = Expense(
                amount: amount,
                category: category,
                date: date,
                notes: notes,
                paymentMethod: paymentMethod.rawValue,
                merchant: merchant,
                // Record the currency the user is entering in. Without this the
                // model default ("USD") sticks even after they switch to AED, so
                // the expense row would show "$".
                currency: CurrencyFormatter.preferredCurrencyCode
            )
            context.insert(expense)
        }

        if let recurrenceFrequency {
            if expense.seriesID == nil {
                expense.seriesID = expense.id
            }
            expense.recurrenceFrequency = recurrenceFrequency
            expense.recurrenceEndDate = recurrenceHasEndDate ? recurrenceEndDate : nil
        } else {
            expense.recurrenceFrequency = nil
            expense.recurrenceEndDate = nil
        }

        return true
    }
}
