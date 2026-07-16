import Foundation

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }

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
