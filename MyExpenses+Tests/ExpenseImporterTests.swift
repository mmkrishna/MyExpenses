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
            for: Expense.self,
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
        #expect(stored.contains { $0.merchant == "Noon" && $0.category == .shopping })
        #expect(stored.contains { $0.merchant == "AL JEERAN REST LLC" && $0.category == .food })

        // Pre-parsed transactions keep a user's edited category.
        var parsed = SMSExpenseParser.parse(
            "Purchase of AED 20.00 with Debit Card ending 0807 at SOCIAL HUB FZCO, DUBAI. Avl Balance is AED 2,832.34."
        )
        parsed[0].category = .entertainment
        ExpenseImporter.importExpenses(parsed, into: context)

        stored = try context.fetch(FetchDescriptor<Expense>())
        #expect(stored.count == 3)
        #expect(stored.contains { $0.merchant == "SOCIAL HUB FZCO" && $0.category == .entertainment })
    }
}
