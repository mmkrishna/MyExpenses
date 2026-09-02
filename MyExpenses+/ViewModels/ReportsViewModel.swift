import Foundation
import Observation
import SwiftUI

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

struct MonthlySummary: Identifiable {
    let month: Date
    let income: Decimal
    let expense: Decimal
    var net: Decimal { income - expense }
    var id: Date { month }
}

struct IncomeSourceTotal: Identifiable {
    let source: IncomeSource
    let total: Decimal
    var id: String { source.id }
    var name: String { source.rawValue }
    var symbolName: String { source.systemImage }
    var color: Color { source.color }
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
    var shareURL: URL?
    var exportAlertMessage: String?

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

    func incomeSourceTotals(_ incomes: [Income], in month: Date = Date(), calendar: Calendar = .current) -> [IncomeSourceTotal] {
        let monthIncomes = incomes.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        let grouped = Dictionary(grouping: monthIncomes, by: \.source)
        return grouped
            .map { IncomeSourceTotal(source: $0.key, total: $0.value.reduce(into: Decimal.zero) { $0 += $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func monthlyAverage(_ expenses: [Expense], calendar: Calendar = .current) -> Decimal {
        ExpenseSummary.monthlyAverage(for: expenses, calendar: calendar)
    }

    func totalExpenses(_ expenses: [Expense]) -> Decimal {
        expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    func totalExpenses(_ expenses: [Expense], in month: Date, calendar: Calendar = .current) -> Decimal {
        expenses
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    func totalIncome(_ incomes: [Income], in month: Date, calendar: Calendar = .current) -> Decimal {
        incomes
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    /// Income and expense side by side for the same trailing window used by
    /// `series(for:expenses:...)`, so the two bars line up month for month.
    func combinedMonthlySeries(mode: MonthlyChartMode, expenses: [Expense], incomes: [Income], monthsBack: Int = 6, calendar: Calendar = .current, now: Date = Date()) -> [MonthlySummary] {
        let expenseSeries = series(for: mode, expenses: expenses, monthsBack: monthsBack, calendar: calendar, now: now)
        return expenseSeries.map { entry in
            let income = incomes
                .filter { calendar.isDate($0.date, equalTo: entry.month, toGranularity: .month) }
                .reduce(into: Decimal.zero) { $0 += $1.amount }
            return MonthlySummary(month: entry.month, income: income, expense: entry.total)
        }
    }

    func exportMonthlyCategoryReportCSV(
        month: Date,
        incomeTotal: Decimal,
        expenseTotal: Decimal,
        categoryTotals: [CategorySpending],
        incomeSourceTotals: [IncomeSourceTotal]
    ) {
        guard let url = CSVExportService.exportMonthlyCategoryReport(
            month: month,
            incomeTotal: incomeTotal,
            expenseTotal: expenseTotal,
            categoryTotals: categoryTotals,
            incomeSourceTotals: incomeSourceTotals
        ) else {
            exportAlertMessage = "Could not export CSV."
            return
        }
        shareURL = url
    }

    func exportMonthlyCategoryReportPDF(
        month: Date,
        incomeTotal: Decimal,
        expenseTotal: Decimal,
        categoryTotals: [CategorySpending],
        incomeSourceTotals: [IncomeSourceTotal],
        currencyCode: String
    ) {
        guard let url = MonthlyReportPDFService.export(
            month: month,
            incomeTotal: incomeTotal,
            expenseTotal: expenseTotal,
            categoryTotals: categoryTotals,
            incomeSourceTotals: incomeSourceTotals,
            currencyCode: currencyCode
        ) else {
            exportAlertMessage = "Could not export PDF."
            return
        }
        shareURL = url
    }
}
