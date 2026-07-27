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
        let totalsByCurrency = Dictionary(grouping: sorted, by: \.currency)
            .mapValues { $0.reduce(into: Decimal.zero) { $0 += $1.amount } }
            .sorted { $0.key < $1.key }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("expenses-\(UUID().uuidString).pdf")

        do {
            try renderer.writePDF(to: url) { context in
                let columns: [(String, CGFloat)] = [("Date", 70), ("Category", 90), ("Merchant", 140), ("Amount", 80), ("Payment", 90)]
                func drawHeader(page: Int) -> CGFloat {
                    context.beginPage()
                    var y = margin
                    "Expense Report".draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont])
                    if page > 1 {
                        "Page \(page)".draw(
                            at: CGPoint(x: pageWidth - margin - 42, y: y + 6),
                            withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
                        )
                    }
                    y += 32
                    "Generated \(dateFormatter.string(from: Date()))".draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: [.font: rowFont, .foregroundColor: UIColor.secondaryLabel]
                    )
                    y += 28
                    var x = margin
                    for (title, width) in columns {
                        title.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: headerFont])
                        x += width
                    }
                    return y + 18
                }
                var page = 1
                var y = drawHeader(page: page)

                for expense in sorted {
                    if y > pageHeight - margin - 36 {
                        page += 1
                        y = drawHeader(page: page)
                    }
                    let values = [
                        dateFormatter.string(from: expense.date),
                        expense.categoryName,
                        expense.merchant.isEmpty ? expense.categoryName : expense.merchant,
                        CurrencyFormatter.string(from: expense.amount, currencyCode: expense.currency),
                        expense.paymentMethod,
                    ]
                    var x = margin
                    for (index, value) in values.enumerated() {
                        let width = columns[index].1 - 6
                        (value as NSString).draw(
                            in: CGRect(x: x, y: y, width: width, height: 14),
                            withAttributes: [.font: rowFont, .foregroundColor: UIColor.label]
                        )
                        x += columns[index].1
                    }
                    y += 16
                }

                let totals = totalsByCurrency.map { currency, total in
                    "Total (\(currency)): \(CurrencyFormatter.string(from: total, currencyCode: currency))"
                }
                if y + CGFloat(totals.count * 18) > pageHeight - margin {
                    page += 1
                    y = drawHeader(page: page)
                }
                y += 12
                for total in totals {
                    total.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: totalFont])
                    y += 18
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
