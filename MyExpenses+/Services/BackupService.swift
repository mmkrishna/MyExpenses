import Foundation
import SwiftData

struct ExpenseBackupRecord: Codable {
    var id: UUID
    var amount: Decimal
    var category: String
    var date: Date
    var notes: String
    var paymentMethod: String
    var merchant: String
    var currency: String
    var createdAt: Date
    var updatedAt: Date

    init(expense: Expense) {
        id = expense.id
        amount = expense.amount
        // Stored by name rather than by reference, so a backup stays readable
        // and restores even if categories change.
        category = expense.categoryName
        date = expense.date
        notes = expense.notes
        paymentMethod = expense.paymentMethod
        merchant = expense.merchant
        currency = expense.currency
        createdAt = expense.createdAt
        updatedAt = expense.updatedAt
    }

    /// Recreates the expense, resolving its category by name and recreating the
    /// category if it no longer exists, so nothing is lost on restore.
    func makeExpense(in context: ModelContext) -> Expense {
        Expense(
            id: id,
            amount: amount,
            category: CategoryStore.findOrCreate(named: category, in: context),
            date: date,
            notes: notes,
            paymentMethod: paymentMethod,
            merchant: merchant,
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

enum BackupService {
    static func backup(_ expenses: [Expense]) -> URL? {
        let records = expenses.map { ExpenseBackupRecord(expense: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(records) else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expenses-backup.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func restore(from url: URL, context: ModelContext, existing: [Expense]) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([ExpenseBackupRecord].self, from: data)

        let existingIDs = Set(existing.map(\.id))
        var restoredCount = 0
        for record in records where !existingIDs.contains(record.id) {
            context.insert(record.makeExpense(in: context))
            restoredCount += 1
        }
        return restoredCount
    }
}
