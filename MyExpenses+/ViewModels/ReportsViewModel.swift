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

@Observable
final class ReportsViewModel {
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
        guard !expenses.isEmpty else { return .zero }
        let months = Set(expenses.map { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        guard !months.isEmpty else { return .zero }
        let total = expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
        return total / Decimal(months.count)
    }

    func totalExpenses(_ expenses: [Expense]) -> Decimal {
        expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
    }
}
