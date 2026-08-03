import Foundation
import SwiftData

@Model
final class Income {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var sourceName: String = "Salary"
    var payer: String = ""
    var date: Date = Date.now
    var notes: String = ""
    var paymentMethod: String = "Bank Transfer"
    var currency: String = "USD"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var recurrenceFrequency: RecurrenceFrequency?
    var recurrenceEndDate: Date?
    var seriesID: UUID?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        sourceName: String = "Salary",
        payer: String = "",
        date: Date = Date(),
        notes: String = "",
        paymentMethod: String = "Bank Transfer",
        currency: String = CurrencyFormatter.preferredCurrencyCode,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        recurrenceFrequency: RecurrenceFrequency? = nil,
        recurrenceEndDate: Date? = nil,
        seriesID: UUID? = nil
    ) {
        self.id = id
        self.amount = amount
        self.sourceName = sourceName
        self.payer = payer
        self.date = date
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceEndDate = recurrenceEndDate
        self.seriesID = seriesID
    }

    var source: IncomeSource {
        IncomeSource(rawValue: sourceName) ?? .custom
    }

    var displayPayer: String {
        payer.isEmpty ? sourceName : payer
    }
}
