import Foundation
import Observation

struct CategorySpending: Identifiable {
    let category: ExpenseCategory
    let total: Decimal

    var id: String { category.id }
}

/// The figures the hero card cycles through when tapped.
enum DashboardMetric: String, CaseIterable, Identifiable {
    case currentMonth = "Current Month"
    case commitments = "Monthly Commitments"
    case average = "Monthly Average"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .currentMonth: "calendar"
        case .commitments: "repeat"
        case .average: "chart.bar.fill"
        }
    }

    var caption: String {
        switch self {
        case .currentMonth: "Spent so far this month"
        case .commitments: "Recurring expenses, per month"
        case .average: "Average across recorded months"
        }
    }
}

@Observable
final class DashboardViewModel {
    var showingAddExpense = false
    var metric: DashboardMetric = .currentMonth

    func advanceMetric() {
        let all = DashboardMetric.allCases
        guard let index = all.firstIndex(of: metric) else { return }
        metric = all[(index + 1) % all.count]
    }

    func value(for metric: DashboardMetric, expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) -> Decimal {
        switch metric {
        case .currentMonth: monthSpending(expenses, calendar: calendar, now: now)
        case .commitments: totalMonthlyCommitment(expenses, now: now)
        case .average: monthlyAverage(expenses, calendar: calendar)
        }
    }

    func monthlyAverage(_ expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        ExpenseSummary.monthlyAverage(for: expenses, calendar: calendar)
    }

    func monthSpending(_ expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) -> Decimal {
        ExpenseSummary.currentMonthTotal(for: expenses, calendar: calendar, now: now)
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

    func commitments(_ expenses: [Expense], now: Date = Date()) -> [RecurringCommitment] {
        RecurringCommitments.active(in: expenses, on: now)
    }

    func totalMonthlyCommitment(_ expenses: [Expense], now: Date = Date()) -> Decimal {
        RecurringCommitments.totalMonthly(commitments(expenses, now: now))
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
