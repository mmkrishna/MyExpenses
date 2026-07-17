import Foundation

enum ExpenseSummary {
    static func total(for expenses: [Expense], where predicate: (Expense) -> Bool) -> Decimal {
        expenses.filter(predicate).reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    static func currentMonthTotal(for expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) -> Decimal {
        total(for: expenses) { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    static func todayTotal(for expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        total(for: expenses) { calendar.isDateInToday($0.date) }
    }

    static func remainingBudget(monthlyBudget: Decimal, monthSpending: Decimal) -> Decimal {
        max(monthlyBudget - monthSpending, .zero)
    }

    /// Average spend across the months that actually have expenses, so a gap in
    /// recording doesn't drag the average down.
    static func monthlyAverage(for expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        let months = Set(expenses.map { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        guard !months.isEmpty else { return .zero }
        let total = expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
        return total / Decimal(months.count)
    }
}
