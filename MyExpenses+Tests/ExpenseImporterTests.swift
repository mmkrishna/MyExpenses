//
//  ExpenseImporterTests.swift
//  MyExpenses+Tests
//

import Foundation
import SwiftData
import Testing
@testable import MyExpenses_

@MainActor
struct ExpenseImporterTests {

    // Uses a single in-memory container: creating multiple SwiftData containers for the
    // same model in one test process crashes, so all scenarios share one store here.
    @Test func importsExpenses() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext

        // Non-purchase text imports nothing.
        let none = ExpenseImporter.importExpenses(from: "Your OTP is 123456.", into: context)
        #expect(none.count == 0)
        #expect(try context.fetch(FetchDescriptor<Expense>()).isEmpty)

        // Two purchases parsed and stored from one blob.
        let sms = """
        Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30. \
        Purchase of AED 14.00 with Debit Card ending 0807 at AL JEERAN REST LLC, SHARJAH. Avl Balance is AED 3,032.10.
        """
        let result = ExpenseImporter.importExpenses(from: sms, into: context)
        #expect(result.count == 2)
        #expect(result.total == Decimal(string: "56.93"))
        #expect(result.currency == "AED")

        var stored = try context.fetch(FetchDescriptor<Expense>())
        #expect(stored.count == 2)
        #expect(stored.contains { $0.merchant == "Noon" && $0.categoryName == "Shopping" })
        #expect(stored.contains { $0.merchant == "AL JEERAN REST LLC" && $0.categoryName == "Food" })

        // Pre-parsed transactions keep a user's edited category.
        var parsed = SMSExpenseParser.parse(
            "Purchase of AED 20.00 with Debit Card ending 0807 at SOCIAL HUB FZCO, DUBAI. Avl Balance is AED 2,832.34."
        )
        parsed[0].categoryName = "Entertainment"
        ExpenseImporter.importExpenses(parsed, into: context)

        stored = try context.fetch(FetchDescriptor<Expense>())
        #expect(stored.count == 3)
        #expect(stored.contains { $0.merchant == "SOCIAL HUB FZCO" && $0.categoryName == "Entertainment" })

        // Everything so far had no date passed, so it defaults to today — which is
        // what the Shortcuts intent relies on.
        #expect(stored.allSatisfy { Calendar.current.isDateInToday($0.date) })

        // Bank messages carry no date, so an old message must be filed under the
        // date the user picks rather than today.
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        ExpenseImporter.importExpenses(
            from: "Purchase of AED 55.00 with Debit Card ending 0807 at Shell, DUBAI. Avl Balance is AED 1,000.00.",
            into: context,
            date: lastMonth
        )

        stored = try context.fetch(FetchDescriptor<Expense>())
        let backdated = try #require(stored.first { $0.merchant == "Shell" })
        #expect(calendar.isDate(backdated.date, inSameDayAs: lastMonth))
        #expect(!calendar.isDateInToday(backdated.date))

        // One paste can span several days: each transaction keeps its own date,
        // so catching up on a week of messages doesn't collapse them onto one day.
        var mixed = SMSExpenseParser.parse(
            """
            Purchase of AED 11.00 with Debit Card ending 0807 at ADNOC, DUBAI. Avl Balance is AED 900.00. \
            Purchase of AED 12.00 with Debit Card ending 0807 at Carrefour, DUBAI. Avl Balance is AED 800.00.
            """,
            date: lastMonth
        )
        #expect(mixed.allSatisfy { calendar.isDate($0.date, inSameDayAs: lastMonth) })

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        mixed[1].date = yesterday
        ExpenseImporter.importExpenses(mixed, into: context)

        stored = try context.fetch(FetchDescriptor<Expense>())
        let adnoc = try #require(stored.first { $0.merchant == "ADNOC" })
        let carrefour = try #require(stored.first { $0.merchant == "Carrefour" })
        #expect(calendar.isDate(adnoc.date, inSameDayAs: lastMonth))
        #expect(calendar.isDate(carrefour.date, inSameDayAs: yesterday))
    }
}
