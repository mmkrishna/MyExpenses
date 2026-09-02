//
//  ReportsViewModelMonthlySummaryTests.swift
//  MyExpenses+Tests
//

import Foundation
import Testing
@testable import MyExpenses_

@MainActor
struct ReportsViewModelMonthlySummaryTests {

    private let calendar = Calendar.current
    private let viewModel = ReportsViewModel()

    private func date(_ year: Int, _ month: Int, _ day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    /// "Now" fixed to mid-2026 so the trailing six-month window is stable.
    private var now: Date { date(2026, 6) }

    @Test func combinedMonthlySeriesSumsIncomeAndExpensePerMonth() {
        let expenses = [
            Expense(amount: 100, date: date(2026, 4)),
            Expense(amount: 50, date: date(2026, 4)),
            Expense(amount: 200, date: date(2026, 6)),
        ]
        let incomes = [
            Income(amount: 1000, date: date(2026, 4)),
            Income(amount: 500, date: date(2026, 5)),
        ]

        let summaries = viewModel.combinedMonthlySeries(mode: .actual, expenses: expenses, incomes: incomes, monthsBack: 6, calendar: calendar, now: now)

        #expect(summaries.count == 6)

        let april = summaries[3]
        #expect(calendar.isDate(april.month, equalTo: date(2026, 4), toGranularity: .month))
        #expect(april.income == 1000)
        #expect(april.expense == 150)
        #expect(april.net == 850)

        let may = summaries[4]
        #expect(may.income == 500)
        #expect(may.expense == 0)
        #expect(may.net == 500)

        let june = summaries[5]
        #expect(june.income == 0)
        #expect(june.expense == 200)
        #expect(june.net == -200)
    }

    @Test func combinedMonthlySeriesReturnsZeroForMonthsWithNoData() {
        let summaries = viewModel.combinedMonthlySeries(mode: .actual, expenses: [], incomes: [], monthsBack: 6, calendar: calendar, now: now)

        #expect(summaries.count == 6)
        #expect(summaries.allSatisfy { $0.income == 0 && $0.expense == 0 && $0.net == 0 })
    }
}
