import Foundation
import SwiftData

struct ExpenseImportResult {
    var count: Int
    var total: Decimal
    var currency: String
}

/// Turns parsed SMS transactions into stored Expenses. Shared by the in-app
/// Import from SMS screen and the "Add Expense from Text" App Intent.
enum ExpenseImporter {
    @discardableResult
    static func importExpenses(_ transactions: [ParsedSMSTransaction], into context: ModelContext) -> ExpenseImportResult {
        var total = Decimal.zero
        for transaction in transactions {
            // The parser only guesses a name; resolve it to a real category here,
            // which also honours a category the user picked during review.
            let expense = Expense(
                amount: transaction.amount,
                category: CategoryStore.findOrCreate(named: transaction.categoryName, in: context),
                date: Date(),
                notes: "",
                paymentMethod: transaction.paymentMethod.rawValue,
                merchant: transaction.merchant,
                currency: transaction.currency
            )
            context.insert(expense)
            total += transaction.amount
        }
        if !transactions.isEmpty {
            try? context.save()
        }
        let currency = transactions.first?.currency ?? CurrencyFormatter.preferredCurrencyCode
        return ExpenseImportResult(count: transactions.count, total: total, currency: currency)
    }

    @discardableResult
    static func importExpenses(from text: String, into context: ModelContext) -> ExpenseImportResult {
        importExpenses(SMSExpenseParser.parse(text), into: context)
    }
}
