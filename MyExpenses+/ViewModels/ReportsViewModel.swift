import Foundation
import Observation

struct MonthlyTotal: Identifiable {
    let month: Date
    let total: Decimal
    var id: Date { month }
}

struct DailyTotal: Identifiable {
    let day: Date
    let total: Decimal
    var id: Date { day }
}

enum MonthlyChartMode: String, CaseIterable, Identifiable {
    /// What was actually paid each month, matching the bank statement.
    case actual = "Actual"
    /// Recurring charges spread evenly, so quarterly/yearly bills don't spike.
    case monthly = "Monthly"

    var id: String { rawValue }
}

@Observable
final class ReportsViewModel {
    var chartMode: MonthlyChartMode = .actual

    func series(for mode: MonthlyChartMode, expenses: [Expense], monthsBack: Int = 6, calendar: Calendar = .current, now: Date = Date()) -> [MonthlyTotal] {
        switch mode {
        case .actual:
            monthlySeries(expenses, monthsBack: monthsBack, calendar: calendar, now: now)
        case .monthly:
            amortizedMonthlySeries(expenses, monthsBack: monthsBack, calendar: calendar, now: now)
        }
    }

    /// Recurring charges replaced by their monthly equivalent, spread across
    /// every month the series runs. The real occurrences are excluded so a
    /// quarterly charge isn't counted both as a lump and as an equivalent.
    func amortizedMonthlySeries(_ expenses: [Expense], monthsBack: Int = 6, calendar: Calendar = .current, now: Date = Date()) -> [MonthlyTotal] {
        let commitments = RecurringCommitments.all(in: expenses)
        let oneOff = expenses.filter { $0.seriesID == nil }

        return months(monthsBack: monthsBack, calendar: calendar, now: now).map { month in
            var total = oneOff
                .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(into: Decimal.zero) { $0 += $1.amount }

            for commitment in commitments
            where RecurringCommitments.isActive(commitment, inMonthOf: month, calendar: calendar) {
                total += commitment.monthlyEquivalent
            }
            return MonthlyTotal(month: month, total: total)
        }
    }

    func commitments(_ expenses: [Expense], now: Date = Date()) -> [RecurringCommitment] {
        RecurringCommitments.active(in: expenses, on: now)
    }

    func totalMonthlyCommitment(_ expenses: [Expense], now: Date = Date()) -> Decimal {
        RecurringCommitments.totalMonthly(commitments(expenses, now: now))
    }

    private func months(monthsBack: Int, calendar: Calendar, now: Date) -> [Date] {
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<monthsBack).reversed().compactMap {
            calendar.date(byAdding: .month, value: -$0, to: currentMonthStart)
        }
    }

    func monthlySeries(_ expenses: [Expense], monthsBack: Int = 6, calendar: Calendar = .current, now: Date = Date()) -> [MonthlyTotal] {
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else { return [] }

        let months: [Date] = (0..<monthsBack).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: currentMonthStart)
        }

        return months.map { month in
            let total = expenses
                .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(into: Decimal.zero) { $0 += $1.amount }
            return MonthlyTotal(month: month, total: total)
        }
    }

    func categoryTotals(_ expenses: [Expense], in month: Date = Date(), calendar: Calendar = .current) -> [CategorySpending] {
        let monthExpenses = expenses.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        let grouped = Dictionary(grouping: monthExpenses, by: \.category)
        return grouped
            .map { CategorySpending(category: $0.key, total: $0.value.reduce(into: Decimal.zero) { $0 += $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func dailyTrend(_ expenses: [Expense], for month: Date = Date(), calendar: Calendar = .current) -> [DailyTotal] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let monthExpenses = expenses.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        let grouped = Dictionary(grouping: monthExpenses) { calendar.startOfDay(for: $0.date) }

        var days: [Date] = []
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return days.map { day in
            let total = grouped[day]?.reduce(into: Decimal.zero) { $0 += $1.amount } ?? .zero
            return DailyTotal(day: day, total: total)
        }
    }

    func highestCategory(_ expenses: [Expense], in month: Date = Date(), calendar: Calendar = .current) -> CategorySpending? {
        categoryTotals(expenses, in: month, calendar: calendar).first
    }

    func monthlyAverage(_ expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        ExpenseSummary.monthlyAverage(for: expenses, calendar: calendar)
    }

    func totalExpenses(_ expenses: [Expense]) -> Decimal {
        expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
    }
}
