import SwiftData
import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    private var title: String {
        expense.merchant.isEmpty ? expense.categoryName : expense.merchant
    }

    private var formattedAmount: String {
        CurrencyFormatter.string(from: expense.amount, currencyCode: expense.currency)
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: expense.categorySymbol, tint: expense.categoryColor, size: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if expense.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .accessibilityHidden(true)
                    }
                }
                Text(expense.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(formattedAmount)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(formattedAmount), \(expense.date.formatted(date: .abbreviated, time: .omitted))\(expense.isRecurring ? ", recurring" : "")")
    }
}

#Preview {
    List {
        ExpenseRow(expense: Expense(amount: 24.99, merchant: "Coffee Shop"))
        ExpenseRow(expense: Expense(amount: 85.00, merchant: "Uber"))
    }
    .modelContainer(SampleData.previewContainer)
}
