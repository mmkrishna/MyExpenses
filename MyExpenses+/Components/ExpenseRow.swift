import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    private var title: String {
        expense.merchant.isEmpty ? expense.category.displayName : expense.merchant
    }

    private var formattedAmount: String {
        CurrencyFormatter.string(from: expense.amount, currencyCode: expense.currency)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: expense.category.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(expense.category.color)
                .frame(width: 40, height: 40)
                .background(expense.category.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if expense.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                Text(expense.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(formattedAmount)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(formattedAmount), \(expense.date.formatted(date: .abbreviated, time: .omitted))\(expense.isRecurring ? ", recurring" : "")")
    }
}

#Preview {
    List {
        ExpenseRow(expense: Expense(amount: 24.99, category: .food, merchant: "Coffee Shop"))
        ExpenseRow(expense: Expense(amount: 85.00, category: .transport, merchant: "Uber"))
    }
}
