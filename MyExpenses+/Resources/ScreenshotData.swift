#if DEBUG
import Foundation
import SwiftData

/// Seeds a rich, deterministic dataset for App Store screenshots.
///
/// Only runs when the app is launched with the `-seedScreenshotData` argument
/// (e.g. `xcrun simctl launch <udid> <bundle> -seedScreenshotData 1`), and the
/// whole file is compiled out of Release builds, so it can never touch a real
/// user's data or ship.
enum ScreenshotData {
    static let launchArgument = "-seedScreenshotData"

    @MainActor
    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }

        // Presentable defaults for the shots.
        let defaults = UserDefaults.standard
        defaults.set("AED", forKey: "preferredCurrencyCode")
        defaults.set(12000.0, forKey: "monthlyBudget")
        defaults.set("Alex Carter", forKey: "userProfileName")
        defaults.removeObject(forKey: "userProfilePhotoData")
        // Never block a screenshot behind the biometric lock.
        defaults.set(false, forKey: "faceIDEnabled")

        let context = AppModelContainer.shared.mainContext

        // Start from a clean, repeatable slate on every seeded launch.
        try? context.delete(model: Expense.self)
        CategoryStore.seedBuiltInsIfNeeded(in: context)
        for expense in makeExpenses(in: context) { context.insert(expense) }
        try? context.save()
    }

    // MARK: - Dataset

    private static let calendar = Calendar.current

    @MainActor
    private static func makeExpenses(in context: ModelContext) -> [Expense] {
        func cat(_ b: BuiltInCategory) -> ExpenseCategory { CategoryStore.resolve(b, in: context) }
        let now = Date()

        func daysAgo(_ d: Int) -> Date { calendar.date(byAdding: .day, value: -d, to: now) ?? now }
        /// A noon date in the month `m` months before now, on the given day.
        func monthDay(_ m: Int, _ day: Int) -> Date {
            let base = calendar.date(byAdding: .month, value: -m, to: now) ?? now
            var c = calendar.dateComponents([.year, .month], from: base)
            c.day = day; c.hour = 12
            return calendar.date(from: c) ?? base
        }

        func one(_ amount: Double, _ b: BuiltInCategory, _ merchant: String, _ pay: PaymentMethod, _ date: Date, _ note: String = "") -> Expense {
            Expense(amount: Decimal(amount), category: cat(b), date: date, notes: note,
                    paymentMethod: pay.rawValue, merchant: merchant)
        }

        /// A monthly recurring series with real occurrences on `day` for the last
        /// `months` months (current month included). Dating the newest occurrence
        /// in the current month means nothing new generates on launch.
        func monthly(_ amount: Double, _ b: BuiltInCategory, _ merchant: String, _ pay: PaymentMethod, day: Int, months: Int) -> [Expense] {
            let series = UUID()
            return (0..<months).reversed().map { m in
                Expense(amount: Decimal(amount), category: cat(b), date: monthDay(m, day), notes: "",
                        paymentMethod: pay.rawValue, merchant: merchant,
                        recurrenceFrequency: m == months - 1 ? .monthly : nil,
                        seriesID: series)
            }
        }

        var expenses: [Expense] = []

        // Today — small, believable.
        expenses += [
            one(22.00, .coffee, "% Arabica", .digitalWallet, daysAgo(0)),
            one(68.00, .food, "Shake Shack", .creditCard, daysAgo(0), "Lunch"),
        ]

        // Rest of the current month — a natural spread across categories.
        expenses += [
            one(246.30, .grocery, "Carrefour", .debitCard, daysAgo(1), "Weekly groceries"),
            one(34.00, .transport, "Careem", .digitalWallet, daysAgo(1)),
            one(180.00, .fuel, "ADNOC", .debitCard, daysAgo(2)),
            one(329.00, .shopping, "Noon", .creditCard, daysAgo(3)),
            one(19.50, .coffee, "Starbucks", .cash, daysAgo(3)),
            one(142.00, .food, "Zaroob", .creditCard, daysAgo(4)),
            one(90.00, .entertainment, "VOX Cinemas", .digitalWallet, daysAgo(5), "Movie night"),
            one(320.00, .bills, "DEWA", .bankTransfer, daysAgo(6), "Electricity & water"),
            one(188.40, .grocery, "Spinneys", .debitCard, daysAgo(8)),
            one(96.00, .health, "Aster Pharmacy", .cash, daysAgo(9)),
            one(410.00, .shopping, "IKEA", .creditCard, daysAgo(12), "Home"),
            one(45.00, .transport, "RTA Salik", .digitalWallet, daysAgo(14)),
            one(115.00, .food, "PF Chang's", .creditCard, daysAgo(17), "Dinner"),
            one(155.00, .fuel, "ENOC", .debitCard, daysAgo(21)),
            one(850.00, .travel, "Emirates", .creditCard, daysAgo(24), "Weekend trip"),
        ]

        // A few earlier months so the trend charts have history.
        expenses += [
            one(232.00, .grocery, "Carrefour", .debitCard, monthDay(1, 24)),
            one(178.00, .shopping, "Amazon.ae", .creditCard, monthDay(1, 18)),
            one(160.00, .fuel, "ADNOC", .debitCard, monthDay(1, 11)),
            one(88.00, .food, "Allo Beirut", .creditCard, monthDay(2, 22)),
            one(300.00, .shopping, "Uniqlo", .creditCard, monthDay(2, 14)),
            one(210.00, .grocery, "Lulu Hypermarket", .debitCard, monthDay(3, 20)),
            one(140.00, .health, "Mediclinic", .creditCard, monthDay(4, 9)),
        ]

        // Recurring commitments — a monthly rent, subscriptions, and a gym — so the
        // commitments card and monthly-equivalent breakdown are populated.
        expenses += monthly(4500.00, .rent, "Skyline Residences", .bankTransfer, day: 1, months: 6)
        expenses += monthly(55.99, .subscription, "Netflix", .creditCard, day: 5, months: 4)
        expenses += monthly(350.00, .health, "Fitness First", .creditCard, day: 3, months: 4)

        return expenses
    }
}
#endif
