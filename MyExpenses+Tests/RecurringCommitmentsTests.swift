//
//  RecurringCommitmentsTests.swift
//  MyExpenses+Tests
//

import Foundation
import Testing
@testable import MyExpenses_

@MainActor
struct RecurringCommitmentsTests {

    private let calendar = Calendar.current
    /// Fixed "now" so month arithmetic in the tests is stable.
    private var now: Date { Date(timeIntervalSince1970: 1_750_000_000) } // 2025-06-15

    private func monthsAgo(_ months: Int) -> Date {
        calendar.date(byAdding: .month, value: -months, to: now) ?? now
    }

    /// Categories are rows now; tests use unmanaged instances from the real seed
    /// factory, which needs no container.
    private func cat(_ builtIn: BuiltInCategory) -> ExpenseCategory {
        builtIn.makeCategory(sortOrder: 0)
    }

    private func approx(_ value: Decimal, _ expected: Double, tolerance: Double = 0.01) -> Bool {
        abs(NSDecimalNumber(decimal: value).doubleValue - expected) < tolerance
    }

    // MARK: - Monthly equivalent maths

    @Test func monthlyEquivalentSpreadsEachFrequency() {
        #expect(RecurrenceFrequency.monthly.monthlyEquivalent(of: 4500) == 4500)
        #expect(RecurrenceFrequency.quarterly.monthlyEquivalent(of: 900) == 300)
        #expect(RecurrenceFrequency.yearly.monthlyEquivalent(of: 2400) == 200)
        // 100 a week is 5,200 a year, i.e. ~433.33 a month.
        #expect(approx(RecurrenceFrequency.weekly.monthlyEquivalent(of: 100), 433.33))
    }

    // MARK: - Building commitments

    @Test func activeCommitmentsComeFromSeriesAnchorsOnly() {
        let series = UUID()
        let anchor = Expense(
            amount: 900, category: cat(.parkingSubscription), date: monthsAgo(2),
            merchant: "Parkin", recurrenceFrequency: .quarterly, seriesID: series
        )
        // A generated occurrence carries the seriesID but no frequency.
        let occurrence = Expense(
            amount: 900, category: cat(.parkingSubscription), date: now,
            merchant: "Parkin", seriesID: series
        )
        let oneOff = Expense(amount: 25, category: cat(.coffee), date: now, merchant: "Starbucks")

        let commitments = RecurringCommitments.active(in: [anchor, occurrence, oneOff], on: now)

        #expect(commitments.count == 1) // not one per occurrence
        #expect(commitments.first?.monthlyEquivalent == 300)
        #expect(commitments.first?.chargedAmount == 900)
    }

    @Test func endedSeriesIsNotAnActiveCommitment() {
        let ended = Expense(
            amount: 1200, category: cat(.subscription), date: monthsAgo(6),
            merchant: "Old Gym", recurrenceFrequency: .yearly,
            recurrenceEndDate: monthsAgo(3), seriesID: UUID()
        )
        #expect(RecurringCommitments.active(in: [ended], on: now).isEmpty)
        // ...but it is still known about, for historical months.
        #expect(RecurringCommitments.all(in: [ended]).count == 1)
    }

    @Test func totalMonthlySumsEveryCommitment() {
        let rent = Expense(amount: 4500, category: cat(.rent), date: monthsAgo(2),
                           merchant: "Landlord", recurrenceFrequency: .monthly, seriesID: UUID())
        let parking = Expense(amount: 900, category: cat(.parkingSubscription), date: monthsAgo(2),
                              merchant: "Parkin", recurrenceFrequency: .quarterly, seriesID: UUID())
        let insurance = Expense(amount: 2400, category: cat(.bills), date: monthsAgo(4),
                                merchant: "Insurance Co", recurrenceFrequency: .yearly, seriesID: UUID())

        let total = RecurringCommitments.totalMonthly(
            RecurringCommitments.active(in: [rent, parking, insurance], on: now)
        )
        #expect(total == 5000) // 4500 + 300 + 200
    }

    @Test func commitmentIsNotChargedToMonthsBeforeItStarted() {
        let insurance = Expense(amount: 2400, category: cat(.bills), date: monthsAgo(2),
                                merchant: "Insurance Co", recurrenceFrequency: .yearly, seriesID: UUID())
        let commitment = try! #require(RecurringCommitments.all(in: [insurance]).first)

        #expect(RecurringCommitments.isActive(commitment, inMonthOf: now, calendar: calendar))
        #expect(RecurringCommitments.isActive(commitment, inMonthOf: monthsAgo(2), calendar: calendar))
        #expect(!RecurringCommitments.isActive(commitment, inMonthOf: monthsAgo(3), calendar: calendar))
    }

    // MARK: - Amortized chart series

    @Test func amortizedSeriesSpreadsYearlyChargeInsteadOfSpiking() {
        // Paid 2,400 once, 2 months ago.
        let insurance = Expense(amount: 2400, category: cat(.bills), date: monthsAgo(2),
                                merchant: "Insurance Co", recurrenceFrequency: .yearly, seriesID: UUID())
        let viewModel = ReportsViewModel()

        let actual = viewModel.monthlySeries([insurance], monthsBack: 3, calendar: calendar, now: now)
        // Actual: the whole 2,400 lands in one month and the others are empty.
        #expect(actual.first(where: { calendar.isDate($0.month, equalTo: monthsAgo(2), toGranularity: .month) })?.total == 2400)
        #expect(actual.first(where: { calendar.isDate($0.month, equalTo: now, toGranularity: .month) })?.total == 0)

        let amortized = viewModel.amortizedMonthlySeries([insurance], monthsBack: 3, calendar: calendar, now: now)
        // Amortized: 200 in every month it runs, including the month it was paid.
        #expect(amortized.allSatisfy { $0.total == 200 })
    }

    @Test func amortizedSeriesDoesNotDoubleCountRecurringCharges() {
        // A monthly rent series: anchor plus a real occurrence in the current month.
        let series = UUID()
        let anchor = Expense(amount: 4500, category: cat(.rent), date: monthsAgo(1),
                             merchant: "Landlord", recurrenceFrequency: .monthly, seriesID: series)
        let occurrence = Expense(amount: 4500, category: cat(.rent), date: now,
                                 merchant: "Landlord", seriesID: series)

        let amortized = ReportsViewModel()
            .amortizedMonthlySeries([anchor, occurrence], monthsBack: 2, calendar: calendar, now: now)

        // The current month must be 4,500 (the equivalent), not 9,000.
        let thisMonth = amortized.first { calendar.isDate($0.month, equalTo: now, toGranularity: .month) }
        #expect(thisMonth?.total == 4500)
    }

    @Test func amortizedSeriesKeepsOneOffExpenses() {
        let coffee = Expense(amount: 25, category: cat(.coffee), date: now, merchant: "Starbucks")
        let rent = Expense(amount: 4500, category: cat(.rent), date: now,
                           merchant: "Landlord", recurrenceFrequency: .monthly, seriesID: UUID())

        let amortized = ReportsViewModel()
            .amortizedMonthlySeries([coffee, rent], monthsBack: 1, calendar: calendar, now: now)

        #expect(amortized.first?.total == 4525) // 25 one-off + 4,500 equivalent
    }
}
