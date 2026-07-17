import Foundation

/// A recurring expense series expressed as what it costs per month.
///
/// This is a derived, display-only view of the data: stored expenses keep their
/// real dates and amounts so they still reconcile against a bank statement.
struct RecurringCommitment: Identifiable {
    let id: UUID
    let merchant: String
    let category: ExpenseCategory
    let frequency: RecurrenceFrequency
    /// The amount actually charged each time (e.g. 2,400 once a year).
    let chargedAmount: Decimal
    let currency: String
    let startDate: Date
    let endDate: Date?

    /// The charge spread over a month (e.g. 2,400 yearly -> 200 a month).
    var monthlyEquivalent: Decimal {
        frequency.monthlyEquivalent(of: chargedAmount)
    }

    var displayName: String {
        merchant.isEmpty ? category.displayName : merchant
    }
}

enum RecurringCommitments {
    /// Every recurring series, past or present. Only the anchor of a series
    /// carries the frequency, so this yields one commitment per series.
    static func all(in expenses: [Expense]) -> [RecurringCommitment] {
        expenses
            .compactMap { expense in
                guard let frequency = expense.recurrenceFrequency,
                      let seriesID = expense.seriesID else { return nil }
                return RecurringCommitment(
                    id: seriesID,
                    merchant: expense.merchant,
                    category: expense.category,
                    frequency: frequency,
                    chargedAmount: expense.amount,
                    currency: expense.currency,
                    startDate: expense.date,
                    endDate: expense.recurrenceEndDate
                )
            }
            .sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
    }

    /// Series running in the month containing `date`.
    static func active(in expenses: [Expense], on date: Date = Date(), calendar: Calendar = .current) -> [RecurringCommitment] {
        all(in: expenses).filter { isActive($0, inMonthOf: date, calendar: calendar) }
    }

    static func totalMonthly(_ commitments: [RecurringCommitment]) -> Decimal {
        commitments.reduce(into: Decimal.zero) { $0 += $1.monthlyEquivalent }
    }

    /// Whether a series is running during the month containing `month`, so that a
    /// commitment isn't charged to months before it started or after it ended.
    static func isActive(_ commitment: RecurringCommitment, inMonthOf month: Date, calendar: Calendar = .current) -> Bool {
        guard let target = calendar.dateInterval(of: .month, for: month)?.start,
              let start = calendar.dateInterval(of: .month, for: commitment.startDate)?.start
        else { return false }

        if target < start { return false }
        if let endDate = commitment.endDate,
           let end = calendar.dateInterval(of: .month, for: endDate)?.start,
           target > end {
            return false
        }
        return true
    }
}
