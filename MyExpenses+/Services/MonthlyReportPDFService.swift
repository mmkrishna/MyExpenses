import Charts
import SwiftUI
import UIKit

/// Renders the same SwiftUI category charts and cards the Reports screen shows,
/// straight into a PDF page, so the export looks like the app rather than a
/// plain data dump. The page height is computed from the row counts rather
/// than measured by asking SwiftUI for an unbounded intrinsic size — Charts
/// doesn't resolve a `nil`-height layout pass reliably and can hang the main
/// thread (seen as a watchdog kill) instead of returning a size.
enum MonthlyReportPDFService {
    @MainActor
    static func export(
        month: Date,
        incomeTotal: Decimal,
        expenseTotal: Decimal,
        categoryTotals: [CategorySpending],
        incomeSourceTotals: [IncomeSourceTotal],
        currencyCode: String
    ) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight = estimatedPageHeight(
            incomeEntryCount: incomeSourceTotals.count,
            expenseEntryCount: categoryTotals.count
        )
        let pageSize = CGSize(width: pageWidth, height: pageHeight)

        let page = MonthlyReportPage(
            month: month,
            incomeTotal: incomeTotal,
            expenseTotal: expenseTotal,
            categoryTotals: categoryTotals,
            incomeSourceTotals: incomeSourceTotals,
            currencyCode: currencyCode
        )
        .frame(width: pageSize.width, height: pageSize.height, alignment: .top)
        .background(Color.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(pageSize)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("monthly-report-\(UUID().uuidString).pdf")

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try pdfRenderer.writePDF(to: url) { context in
                context.beginPage()
                let cgContext = context.cgContext
                // PDF context origin is bottom-left; SwiftUI draws top-left down, so
                // flip vertically or the whole page renders upside down.
                cgContext.translateBy(x: 0, y: pageSize.height)
                cgContext.scaleBy(x: 1, y: -1)
                renderer.render { _, renderInContext in
                    renderInContext(cgContext)
                }
            }
            return url
        } catch {
            return nil
        }
    }

    /// Sums the fixed-height chrome (header, summary row, section titles,
    /// footer, page padding) with a per-row estimate for each breakdown
    /// section, so the page is always tall enough without ever asking Charts
    /// to report its own intrinsic size.
    private static func estimatedPageHeight(incomeEntryCount: Int, expenseEntryCount: Int) -> CGFloat {
        // Generously overestimated on purpose: extra height just leaves blank
        // space at the bottom of the page, but an underestimate clips content.
        let chrome: CGFloat = 400 // header + summary row + two section titles + footer + padding + spacing
        let chartBlockHeight: CGFloat = 190 // fixed 148pt chart + its own padding
        let tableRowHeight: CGFloat = 32
        let tableChromeHeight: CGFloat = 60 // table header row + its own padding

        func sectionHeight(_ count: Int) -> CGFloat {
            guard count > 0 else { return 24 } // just the "no data" line
            return chartBlockHeight + tableChromeHeight + CGFloat(count) * tableRowHeight
        }

        return chrome + sectionHeight(incomeEntryCount) + sectionHeight(expenseEntryCount)
    }
}

/// A minimal shape both `CategorySpending` and `IncomeSourceTotal` map into, so
/// the same chart/table layout can render either breakdown.
private struct BreakdownEntry: Identifiable {
    let id: String
    let name: String
    let color: Color
    let total: Decimal
}

struct MonthlyReportPage: View {
    let month: Date
    let incomeTotal: Decimal
    let expenseTotal: Decimal
    let categoryTotals: [CategorySpending]
    let incomeSourceTotals: [IncomeSourceTotal]
    let currencyCode: String

    private var net: Decimal { incomeTotal - expenseTotal }

    private var sortedExpenseEntries: [BreakdownEntry] {
        categoryTotals
            .map { BreakdownEntry(id: $0.id, name: $0.name, color: $0.color, total: $0.total) }
            .sorted { $0.total > $1.total }
    }

    private var sortedIncomeEntries: [BreakdownEntry] {
        incomeSourceTotals
            .map { BreakdownEntry(id: $0.id, name: $0.name, color: $0.color, total: $0.total) }
            .sorted { $0.total > $1.total }
    }

    private static let brand = Color(hex: "#7B61FF")
    private static let success = Color(hex: "#22C55E")
    private static let danger = Color(hex: "#EF4444")
    private static let subtleBackground = Color(hex: "#F6F5FB")

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            summaryRow

            breakdownSection(title: "Income by Category", entries: sortedIncomeEntries, total: incomeTotal, emptyMessage: "No income recorded this month.")
            breakdownSection(title: "Spending by Category", entries: sortedExpenseEntries, total: expenseTotal, emptyMessage: "No expenses recorded this month.")

            Spacer(minLength: 0)
            footer
        }
        .padding(36)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Report")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Self.brand)
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            statBlock(title: "Income", value: incomeTotal, tint: Self.success)
            statBlock(title: "Expenses", value: expenseTotal, tint: Self.danger)
            statBlock(title: "Net", value: net, tint: net >= 0 ? Self.success : Self.danger)
        }
    }

    private func statBlock(title: String, value: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(from: value, currencyCode: currencyCode))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.09)))
    }

    @ViewBuilder
    private func breakdownSection(title: String, entries: [BreakdownEntry], total: Decimal, emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))

            if entries.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                chartRow(entries: entries, total: total)
                breakdownTable(entries: entries, total: total)
            }
        }
    }

    private func chartRow(entries: [BreakdownEntry], total: Decimal) -> some View {
        HStack(alignment: .center, spacing: 26) {
            Chart(entries) { entry in
                SectorMark(
                    angle: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(entry.color)
            }
            .frame(width: 148, height: 148)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(entries.prefix(7)) { entry in
                    HStack(spacing: 7) {
                        Circle().fill(entry.color).frame(width: 8, height: 8)
                        Text(entry.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(percentString(entry.total, of: total))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Self.subtleBackground))
    }

    private func breakdownTable(entries: [BreakdownEntry], total: Decimal) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("CATEGORY").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("AMOUNT").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Text("SHARE").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
            }
            .padding(.bottom, 8)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Circle().fill(entry.color).frame(width: 7, height: 7)
                    Text(entry.name).font(.system(size: 11.5))
                    Spacer()
                    Text(CurrencyFormatter.string(from: entry.total, currencyCode: currencyCode))
                        .font(.system(size: 11.5, weight: .medium))
                    Text(percentString(entry.total, of: total))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
                .padding(.vertical, 7)

                if index < entries.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Self.subtleBackground))
    }

    private func percentString(_ value: Decimal, of total: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let pct = NSDecimalNumber(decimal: value / total * 100).doubleValue
        return String(format: "%.0f%%", pct)
    }

    private var footer: some View {
        HStack {
            Text("MyExpenses+")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Self.brand)
            Spacer()
            Text("Generated \(Date().formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}
