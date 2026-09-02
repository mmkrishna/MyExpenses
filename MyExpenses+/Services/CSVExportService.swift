import Foundation

enum CSVExportService {
    static func exportCategoryReport(
        reportTitle: String,
        periodLabel: String,
        incomeTotal: Decimal,
        expenseTotal: Decimal,
        categoryTotals: [CategorySpending],
        incomeSourceTotals: [IncomeSourceTotal]
    ) -> URL? {
        var lines = [
            "\(csvField(reportTitle)),\(csvField(periodLabel))",
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
            .appendingPathComponent("report-\(UUID().uuidString).csv")

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
