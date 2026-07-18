import UIKit

enum PDFExportService {
    static func export(_ expenses: [Expense]) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let headerFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let rowFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let totalFont = UIFont.systemFont(ofSize: 13, weight: .bold)

        let sorted = expenses.sorted { $0.date > $1.date }
        let total = sorted.reduce(into: Decimal.zero) { $0 += $1.amount }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("expenses.pdf")

        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = margin
                context.beginPage()

                "Expense Report".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
                y += 32

                "Generated \(dateFormatter.string(from: Date()))".draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
                )
                y += 28

                let columns: [(String, CGFloat)] = [("Date", 70), ("Category", 90), ("Merchant", 140), ("Amount", 80), ("Payment", 90)]
                var x = margin
                for (title, width) in columns {
                    title.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: headerFont])
                    x += width
                }
                y += 18

                for expense in sorted {
                    if y > pageHeight - margin - 20 {
                        context.beginPage()
                        y = margin
                    }
                    x = margin
                    let values = [
                        dateFormatter.string(from: expense.date),
                        expense.categoryName,
                        expense.merchant.isEmpty ? expense.categoryName : expense.merchant,
                        CurrencyFormatter.string(from: expense.amount, currencyCode: expense.currency),
                        expense.paymentMethod,
                    ]
                    for (index, value) in values.enumerated() {
                        value.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: rowFont])
                        x += columns[index].1
                    }
                    y += 16
                }

                y += 12
                "Total: \(CurrencyFormatter.string(from: total))".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: totalFont])
            }
            return url
        } catch {
            return nil
        }
    }
}
