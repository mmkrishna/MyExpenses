import Foundation
import SwiftData

enum RecurrenceGenerationService {
    /// Safety cap on how many occurrences a single series can catch up in one pass.
    private static let maxOccurrencesPerSeries = 60

    @discardableResult
    static func generateDueOccurrences(
        from expenses: [Expense],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let seriesGroups = Dictionary(grouping: expenses.filter { $0.seriesID != nil }) { $0.seriesID! }
        var generatedCount = 0

        for (seriesID, members) in seriesGroups {
            guard let anchor = members.first(where: { $0.recurrenceFrequency != nil }),
                  let frequency = anchor.recurrenceFrequency,
                  let latestDate = members.map(\.date).max() else { continue }

            var nextDate = frequency.nextDate(after: latestDate, calendar: calendar)
            var iterations = 0

            while nextDate <= now, iterations < maxOccurrencesPerSeries {
                if let endDate = anchor.recurrenceEndDate, nextDate > endDate { break }

                let occurrence = Expense(
                    amount: anchor.amount,
                    category: anchor.category,
                    date: nextDate,
                    notes: anchor.notes,
                    paymentMethod: anchor.paymentMethod,
                    merchant: anchor.merchant,
                    currency: anchor.currency,
                    seriesID: seriesID
                )
                context.insert(occurrence)
                generatedCount += 1
                iterations += 1
                nextDate = frequency.nextDate(after: nextDate, calendar: calendar)
            }
        }

        if generatedCount > 0 {
            try? context.save()
        }
        return generatedCount
    }
}
