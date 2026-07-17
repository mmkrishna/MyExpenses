//
//  DashboardMetricTests.swift
//  MyExpenses+Tests
//

import Foundation
import Testing
import UIKit
@testable import MyExpenses_

@MainActor
struct DashboardMetricTests {

    private let calendar = Calendar.current
    private var now: Date { Date(timeIntervalSince1970: 1_750_000_000) } // 2025-06-15

    private func monthsAgo(_ months: Int) -> Date {
        calendar.date(byAdding: .month, value: -months, to: now) ?? now
    }

    @Test func tappingCyclesThroughEveryMetricAndWrapsAround() {
        let viewModel = DashboardViewModel()
        #expect(viewModel.metric == .currentMonth)

        viewModel.advanceMetric()
        #expect(viewModel.metric == .commitments)

        viewModel.advanceMetric()
        #expect(viewModel.metric == .average)

        viewModel.advanceMetric()
        #expect(viewModel.metric == .currentMonth) // wraps
    }

    @Test func eachMetricReportsItsOwnFigure() {
        // 4,500 rent this month (recurring, monthly) + a 100 one-off this month,
        // plus a 300 one-off in a previous month.
        let rent = Expense(amount: 4500, category: .rent, date: now,
                           merchant: "Landlord", recurrenceFrequency: .monthly, seriesID: UUID())
        let coffeeThisMonth = Expense(amount: 100, category: .coffee, date: now, merchant: "Cafe")
        let oldExpense = Expense(amount: 300, category: .food, date: monthsAgo(1), merchant: "Diner")
        let expenses = [rent, coffeeThisMonth, oldExpense]

        let viewModel = DashboardViewModel()

        // Current month: what actually landed this month.
        #expect(viewModel.value(for: .currentMonth, expenses: expenses, calendar: calendar, now: now) == 4600)

        // Commitments: the recurring series' monthly equivalent only.
        #expect(viewModel.value(for: .commitments, expenses: expenses, calendar: calendar, now: now) == 4500)

        // Average: 4,900 across the two months that have expenses.
        #expect(viewModel.value(for: .average, expenses: expenses, calendar: calendar, now: now) == 2450)
    }

    @Test func monthlyAverageIsZeroWithNoExpenses() {
        #expect(DashboardViewModel().value(for: .average, expenses: [], calendar: calendar, now: now) == 0)
    }

    @Test func monthlyAverageOnlyCountsMonthsThatHaveExpenses() {
        // Two expenses six months apart: average over 2 months, not 6.
        let a = Expense(amount: 100, category: .food, date: now, merchant: "A")
        let b = Expense(amount: 300, category: .food, date: monthsAgo(6), merchant: "B")
        #expect(ExpenseSummary.monthlyAverage(for: [a, b], calendar: calendar) == 200)
    }

    @Test func everyMetricIconIsARealSFSymbol() {
        for metric in DashboardMetric.allCases {
            #expect(UIImage(systemName: metric.systemImage) != nil, "bad symbol: \(metric.systemImage)")
        }
    }
}
