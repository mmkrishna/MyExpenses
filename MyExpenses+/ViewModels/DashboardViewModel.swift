import Foundation
import Observation

struct CategorySpending: Identifiable {
    let category: ExpenseCategory
    let total: Decimal

    var id: String { category.id }
}

@Observable
final class DashboardViewModel {
    var showingAddExpense = false

    func monthSpending(_ expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        ExpenseSummary.currentMonthTotal(for: expenses, calendar: calendar)
    }

    func todaySpending(_ expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        ExpenseSummary.todayTotal(for: expenses, calendar: calendar)
    }

    func remainingBudget(monthlyBudget: Decimal, monthSpending: Decimal) -> Decimal {
        ExpenseSummary.remainingBudget(monthlyBudget: monthlyBudget, monthSpending: monthSpending)
    }

    func recentExpenses(_ expenses: [Expense], limit: Int = 5) -> [Expense] {
        Array(expenses.prefix(limit))
    }

    func categoryBreakdown(_ expenses: [Expense], calendar: Calendar = .current) -> [CategorySpending] {
        let currentMonthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }
        let grouped = Dictionary(grouping: currentMonthExpenses, by: \.category)
        return grouped
            .map { CategorySpending(category: $0.key, total: $0.value.reduce(into: Decimal.zero) { $0 += $1.amount }) }
            .sorted { $0.total > $1.total }
    }
}
