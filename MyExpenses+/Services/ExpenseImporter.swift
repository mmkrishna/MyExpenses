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
    /// Each transaction carries its own date, so one paste can span several days.
    @discardableResult
    static func importExpenses(
        _ transactions: [ParsedSMSTransaction],
        into context: ModelContext
    ) throws -> ExpenseImportResult {
        var total = Decimal.zero
        var fingerprints = existingFingerprints(in: context)
        let newTransactions = transactions.filter { transaction in
            let fingerprint = fingerprint(for: transaction)
            return fingerprints.insert(fingerprint).inserted
        }
        for transaction in newTransactions {
            if transaction.isCredit {
                let income = Income(
                    amount: transaction.amount,
                    sourceName: IncomeSource.allCases.contains(where: { $0.rawValue.lowercased() == transaction.categoryName.lowercased() }) ? transaction.categoryName : "Salary",
                    payer: transaction.merchant,
                    date: transaction.date,
                    notes: "Imported from Bank SMS",
                    paymentMethod: transaction.paymentMethod.rawValue,
                    currency: transaction.currency
                )
                context.insert(income)
            } else {
                let expense = Expense(
                    amount: transaction.amount,
                    category: CategoryStore.findOrCreate(named: transaction.categoryName, in: context),
                    date: transaction.date,
                    notes: "",
                    paymentMethod: transaction.paymentMethod.rawValue,
                    merchant: transaction.merchant,
                    currency: transaction.currency
                )
                context.insert(expense)
            }
            total += transaction.amount
        }
        if !newTransactions.isEmpty {
            try context.save()
        }
        let currency = transactions.first?.currency ?? CurrencyFormatter.preferredCurrencyCode
        return ExpenseImportResult(count: newTransactions.count, total: total, currency: currency)
    }

    /// - Parameter date: stamped on every message found. Defaults to now for
    ///   callers with no better information (e.g. the Shortcuts intent).
    @discardableResult
    static func importExpenses(
        from text: String,
        into context: ModelContext,
        date: Date = Date()
    ) throws -> ExpenseImportResult {
        try importExpenses(SMSExpenseParser.parse(text, date: date), into: context)
    }

    /// SMS messages can be delivered or pasted more than once. Matching on the
    /// stable transaction details avoids recording the same message twice while
    /// still allowing the user to review every newly parsed transaction.
    private static func existingFingerprints(in context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<Expense>()
        let existing = (try? context.fetch(descriptor)) ?? []
        return Set(existing.map { fingerprint(for: $0) })
    }

    private static func fingerprint(for transaction: ParsedSMSTransaction) -> String {
        let day = Calendar.current.startOfDay(for: transaction.date).timeIntervalSince1970
        return [
            NSDecimalNumber(decimal: transaction.amount).stringValue,
            transaction.currency.uppercased(),
            transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            transaction.paymentMethod.rawValue,
            String(day),
        ].joined(separator: "|")
    }

    private static func fingerprint(for expense: Expense) -> String {
        let day = Calendar.current.startOfDay(for: expense.date).timeIntervalSince1970
        return [
            NSDecimalNumber(decimal: expense.amount).stringValue,
            expense.currency.uppercased(),
            expense.merchant.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            expense.paymentMethod,
            String(day),
        ].joined(separator: "|")
    }
}
