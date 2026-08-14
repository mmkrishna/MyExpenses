import Foundation
import SwiftData

struct ExpenseImportResult {
    var count: Int
    var total: Decimal
    var currency: String
}

/// Turns parsed SMS transactions into stored Expenses or Incomes.
enum ExpenseImporter {
    @discardableResult
    static func importExpenses(
        _ transactions: [ParsedSMSTransaction],
        into context: ModelContext
    ) throws -> ExpenseImportResult {
        var total = Decimal.zero
        var dbCounts = existingFingerprintCounts(in: context)
        var newTransactions: [ParsedSMSTransaction] = []

        // Transfers move money between the user's own accounts, so storing one
        // would count spending that is already recorded by the purchases it
        // settles. Dropped here rather than at the call site so every route into
        // the importer — the SMS sheet, the Shortcuts intent — is covered.
        let importable = transactions.filter { !$0.isTransfer }

        for transaction in importable {
            let fp = fingerprint(for: transaction)
            let existing = dbCounts[fp, default: 0]
            if existing > 0 {
                dbCounts[fp] = existing - 1
            } else {
                newTransactions.append(transaction)
            }
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
        let currency = importable.first?.currency ?? CurrencyFormatter.preferredCurrencyCode
        return ExpenseImportResult(count: newTransactions.count, total: total, currency: currency)
    }

    @discardableResult
    static func importExpenses(
        from text: String,
        into context: ModelContext,
        date: Date = Date()
    ) throws -> ExpenseImportResult {
        try importExpenses(SMSExpenseParser.parse(text, date: date), into: context)
    }

    private static func existingFingerprintCounts(in context: ModelContext) -> [String: Int] {
        var counts: [String: Int] = [:]

        let expenseDescriptor = FetchDescriptor<Expense>()
        let existingExpenses = (try? context.fetch(expenseDescriptor)) ?? []
        for expense in existingExpenses {
            let fp = fingerprint(for: expense)
            counts[fp, default: 0] += 1
        }

        let incomeDescriptor = FetchDescriptor<Income>()
        let existingIncomes = (try? context.fetch(incomeDescriptor)) ?? []
        for income in existingIncomes {
            let fp = fingerprint(for: income)
            counts[fp, default: 0] += 1
        }

        return counts
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

    private static func fingerprint(for income: Income) -> String {
        let day = Calendar.current.startOfDay(for: income.date).timeIntervalSince1970
        return [
            NSDecimalNumber(decimal: income.amount).stringValue,
            income.currency.uppercased(),
            income.payer.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            income.paymentMethod,
            String(day),
        ].joined(separator: "|")
    }
}
