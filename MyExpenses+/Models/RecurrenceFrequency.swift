import Foundation

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }

    /// What a single charge at this frequency works out to per month, so lumpy
    /// payments (quarterly parking, yearly insurance) can be compared monthly.
    /// Deliberately unrounded — callers format for display, and summing the exact
    /// values avoids rounding drift across many commitments.
    func monthlyEquivalent(of amount: Decimal) -> Decimal {
        switch self {
        case .weekly: amount * Decimal(52) / Decimal(12)
        case .monthly: amount
        case .quarterly: amount / Decimal(3)
        case .yearly: amount / Decimal(12)
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly:
            calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
