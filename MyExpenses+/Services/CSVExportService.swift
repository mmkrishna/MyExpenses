import Foundation

enum CSVExportService {
    static func export(_ expenses: [Expense]) -> URL? {
        var lines = ["Date,Category,Merchant,Amount,Currency,Payment Method,Notes"]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let fields = [
                dateFormatter.string(from: expense.date),
                expense.category.displayName,
                expense.merchant,
                NSDecimalNumber(decimal: expense.amount).stringValue,
                expense.currency,
                expense.paymentMethod,
                expense.notes,
            ]
            lines.append(fields.map { csvField($0) }.joined(separator: ","))
        }

        let csvString = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expenses.csv")

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
