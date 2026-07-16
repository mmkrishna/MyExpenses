import Foundation

enum ExpenseSummary {
    static func total(for expenses: [Expense], where predicate: (Expense) -> Bool) -> Decimal {
        expenses.filter(predicate).reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    static func currentMonthTotal(for expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        total(for: expenses) { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    static func todayTotal(for expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        total(for: expenses) { calendar.isDateInToday($0.date) }
    }

    static func remainingBudget(monthlyBudget: Decimal, monthSpending: Decimal) -> Decimal {
        max(monthlyBudget - monthSpending, .zero)
    }
}
