import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static let previewContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        populate(container.mainContext)
        return container
    }()

    /// Seeds categories, then sample expenses that reference them.
    @discardableResult
    static func populate(_ context: ModelContext) -> [Expense] {
        CategoryStore.seedBuiltInsIfNeeded(in: context)
        let expenses = makeExpenses(in: context)
        for expense in expenses { context.insert(expense) }
        try? context.save()
        return expenses
    }

    static func makeExpenses(in context: ModelContext) -> [Expense] {
        // Categories are rows now, so resolve each built-in to its stored row.
        func cat(_ builtIn: BuiltInCategory) -> ExpenseCategory {
            CategoryStore.resolve(builtIn, in: context)
        }
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        return [
            Expense(amount: 4.75, category: cat(.coffee), date: daysAgo(0), notes: "", paymentMethod: PaymentMethod.creditCard.rawValue, merchant: "Blue Bottle Coffee"),
            Expense(amount: 68.20, category: cat(.grocery), date: daysAgo(1), notes: "Weekly groceries", paymentMethod: PaymentMethod.debitCard.rawValue, merchant: "Whole Foods"),
            Expense(amount: 42.50, category: cat(.shopping), date: daysAgo(1), notes: "", paymentMethod: PaymentMethod.creditCard.rawValue, merchant: "Uniqlo"),
            Expense(amount: 55.00, category: cat(.fuel), date: daysAgo(2), notes: "", paymentMethod: PaymentMethod.debitCard.rawValue, merchant: "Shell"),
            Expense(amount: 120.00, category: cat(.bills), date: daysAgo(3), notes: "Electricity", paymentMethod: PaymentMethod.bankTransfer.rawValue, merchant: "DEWA"),
            Expense(amount: 15.99, category: cat(.entertainment), date: daysAgo(4), notes: "Movie night", paymentMethod: PaymentMethod.digitalWallet.rawValue, merchant: "Cinema"),
            Expense(amount: 32.40, category: cat(.food), date: daysAgo(5), notes: "", paymentMethod: PaymentMethod.cash.rawValue, merchant: "Shake Shack"),
            Expense(amount: 9.99, category: cat(.subscription), date: daysAgo(6), notes: "Monthly plan", paymentMethod: PaymentMethod.creditCard.rawValue, merchant: "Spotify"),
            Expense(amount: 220.00, category: cat(.travel), date: daysAgo(8), notes: "Weekend trip", paymentMethod: PaymentMethod.creditCard.rawValue, merchant: "Emirates"),
            Expense(amount: 18.25, category: cat(.transport), date: daysAgo(9), notes: "", paymentMethod: PaymentMethod.digitalWallet.rawValue, merchant: "Careem"),
            Expense(amount: 75.00, category: cat(.health), date: daysAgo(11), notes: "Checkup", paymentMethod: PaymentMethod.cash.rawValue, merchant: "Pharmacy"),
            Expense(amount: 3.50, category: cat(.coffee), date: daysAgo(12), notes: "", paymentMethod: PaymentMethod.cash.rawValue, merchant: "Starbucks"),
            Expense(amount: 89.00, category: cat(.grocery), date: daysAgo(15), notes: "", paymentMethod: PaymentMethod.debitCard.rawValue, merchant: "Carrefour"),
            Expense(amount: 12.00, category: cat(.other), date: daysAgo(20), notes: "", paymentMethod: PaymentMethod.cash.rawValue, merchant: "Misc"),
            Expense(amount: 60.00, category: cat(.shopping), date: daysAgo(35), notes: "", paymentMethod: PaymentMethod.creditCard.rawValue, merchant: "Amazon"),
            Expense(amount: 45.00, category: cat(.fuel), date: daysAgo(40), notes: "", paymentMethod: PaymentMethod.debitCard.rawValue, merchant: "Adnoc"),
        ] + makeRecurringExpenses(calendar: calendar, now: now, cat: cat)
    }

    /// Recurring series at each cadence — monthly rent, quarterly parking, yearly
    /// insurance — so previews exercise the monthly-equivalent breakdown.
    private static func makeRecurringExpenses(calendar: Calendar, now: Date, cat: (BuiltInCategory) -> ExpenseCategory) -> [Expense] {
        func monthsAgo(_ months: Int) -> Date {
            calendar.date(byAdding: .month, value: -months, to: now) ?? now
        }

        // Rent: monthly, anchor plus one past occurrence.
        let rentSeries = UUID()
        let rentAnchor = Expense(
            amount: 4500.00,
            category: cat(.rent),
            date: monthsAgo(2),
            notes: "Apartment rent",
            paymentMethod: PaymentMethod.check.rawValue,
            merchant: "Landlord",
            recurrenceFrequency: .monthly,
            seriesID: rentSeries
        )
        let rentOccurrence = Expense(
            amount: 4500.00, category: cat(.rent), date: monthsAgo(1), notes: "Apartment rent",
            paymentMethod: PaymentMethod.check.rawValue, merchant: "Landlord", seriesID: rentSeries
        )

        // Parking: quarterly -> 900 every 3 months is 300 a month.
        let parkingSeries = UUID()
        let parking = Expense(
            amount: 900.00,
            category: cat(.parkingSubscription),
            date: monthsAgo(2),
            notes: "Quarterly parking permit",
            paymentMethod: PaymentMethod.debitCard.rawValue,
            merchant: "Parkin",
            recurrenceFrequency: .quarterly,
            seriesID: parkingSeries
        )

        // Insurance: yearly -> 2,400 once a year is 200 a month.
        let insuranceSeries = UUID()
        let insurance = Expense(
            amount: 2400.00,
            category: cat(.insurance),
            date: monthsAgo(4),
            notes: "Car insurance",
            paymentMethod: PaymentMethod.creditCard.rawValue,
            merchant: "Insurance Co",
            recurrenceFrequency: .yearly,
            seriesID: insuranceSeries
        )

        return [rentAnchor, rentOccurrence, parking, insurance]
    }
}
