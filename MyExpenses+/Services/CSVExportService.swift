import Foundation

enum CSVExportService {
    static func export(_ expenses: [Expense]) -> URL? {
        var lines = ["Date,Category,Merchant,Amount,Currency,Payment Method,Notes"]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let fields = [
                dateFormatter.string(from: expense.date),
                expense.categoryName,
                expense.merchant,
                NSDecimalNumber(decimal: expense.amount).stringValue,
                expense.currency,
                expense.paymentMethod,
                expense.notes,
            ]
            lines.append(fields.map { csvField($0) }.joined(separator: ","))
        }

        let csvString = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("expenses-\(UUID().uuidString).csv")

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func exportMonthlyCategoryReport(
        month: Date,
        incomeTotal: Decimal,
        expenseTotal: Decimal,
        categoryTotals: [CategorySpending],
        incomeSourceTotals: [IncomeSourceTotal]
    ) -> URL? {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        var lines = [
            "Monthly Report,\(csvField(monthFormatter.string(from: month)))",
            "Total Income,\(NSDecimalNumber(decimal: incomeTotal).stringValue)",
            "Total Expenses,\(NSDecimalNumber(decimal: expenseTotal).stringValue)",
            "Net,\(NSDecimalNumber(decimal: incomeTotal - expenseTotal).stringValue)",
            "",
            "Income by Category,Amount,% of Income",
        ]

        let sortedIncome = incomeSourceTotals.sorted { $0.total > $1.total }
        for entry in sortedIncome {
            let percent = incomeTotal > 0 ? NSDecimalNumber(decimal: entry.total / incomeTotal * 100).doubleValue : 0
            let fields = [
                entry.name,
                NSDecimalNumber(decimal: entry.total).stringValue,
                String(format: "%.1f%%", percent),
            ]
            lines.append(fields.map { csvField($0) }.joined(separator: ","))
        }

        lines.append("")
        lines.append("Spending by Category,Amount,% of Expenses")

        let sortedExpenses = categoryTotals.sorted { $0.total > $1.total }
        for entry in sortedExpenses {
            let percent = expenseTotal > 0 ? NSDecimalNumber(decimal: entry.total / expenseTotal * 100).doubleValue : 0
            let fields = [
                entry.name,
                NSDecimalNumber(decimal: entry.total).stringValue,
                String(format: "%.1f%%", percent),
            ]
            lines.append(fields.map { csvField($0) }.joined(separator: ","))
        }

        let csvString = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monthly-report-\(UUID().uuidString).csv")

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
