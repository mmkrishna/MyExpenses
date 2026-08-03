import SwiftUI

struct IncomeRow: View {
    let income: Income

    private var title: String {
        income.displayPayer
    }

    private var formattedAmount: String {
        "+ " + CurrencyFormatter.string(from: income.amount, currencyCode: income.currency)
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: income.source.systemImage, tint: income.source.color, size: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("• " + income.sourceName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Text(income.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(formattedAmount)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.green)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(income.sourceName), \(formattedAmount), \(income.date.formatted(date: .abbreviated, time: .omitted))")
    }
}

#Preview {
    List {
        IncomeRow(income: Income(amount: 4500.00, sourceName: "Salary", payer: "TechCorp Inc"))
        IncomeRow(income: Income(amount: 850.00, sourceName: "Rent", payer: "Apartment 4B"))
    }
    .padding()
}
