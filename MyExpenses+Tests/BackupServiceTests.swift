import Foundation
import SwiftData
import Testing
@testable import MyExpenses_

@MainActor
struct BackupServiceTests {
    @Test func backupRecordRoundTripsRecurringMetadata() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let seriesID = UUID()
        let endDate = Date(timeIntervalSince1970: 1_800_000_000)
        let original = Expense(
            amount: 120,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            recurrenceFrequency: .monthly,
            recurrenceEndDate: endDate,
            seriesID: seriesID
        )

        let encoded = try JSONEncoder().encode(ExpenseBackupRecord(expense: original))
        let decoded = try JSONDecoder().decode(ExpenseBackupRecord.self, from: encoded)
        let restored = decoded.makeExpense(in: context)

        #expect(restored.recurrenceFrequency == .monthly)
        #expect(restored.recurrenceEndDate == endDate)
        #expect(restored.seriesID == seriesID)
    }

    @Test func amountParserAcceptsThousandsSeparators() {
        // Compare against an exact Decimal: a `Decimal` written as the float
        // literal 1234.56 is stored as 1234.5599999999997952 (it round-trips
        // through Double), so `== 1234.56` would be false against an exactly
        // parsed value.
        let expected = Decimal(string: "1234.56")
        #expect(CurrencyFormatter.decimal(from: "1,234.56", locale: Locale(identifier: "en_US")) == expected)
        #expect(CurrencyFormatter.decimal(from: "1.234,56", locale: Locale(identifier: "de_DE")) == expected)
    }
}
