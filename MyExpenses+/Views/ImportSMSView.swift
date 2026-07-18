import SwiftData
import SwiftUI

struct ImportSMSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @State private var text: String
    @State private var transactions: [ParsedSMSTransaction] = []
    /// Bank messages carry no date, so the user picks one. This stamps every
    /// message in the paste; each row can then be adjusted on its own, so a
    /// batch spanning several days still files correctly.
    @State private var date = Date()

    init(prefilledText: String = "") {
        _text = State(initialValue: prefilledText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(height: 110)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Purchase of AED 42.93 with Debit Card…")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            text = clipboard
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Paste your bank SMS")
                } footer: {
                    Text("Amounts, merchants, and cards are detected automatically.")
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } footer: {
                    Text(transactions.count > 1
                         ? "Bank messages don't include a date. This sets all \(transactions.count) — change any one below if they're from different days."
                         : "Bank messages don't include a date, so pick when this was spent.")
                }

                if !transactions.isEmpty {
                    Section("Detected \(transactions.count) transaction\(transactions.count == 1 ? "" : "s")") {
                        ForEach($transactions) { $transaction in
                            transactionRow($transaction)
                        }
                    }
                } else if !text.isEmpty {
                    Section {
                        Text("No transactions found in this text.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import from SMS")
            .navigationBarTitleDisplayMode(.inline)
            // Return inserts a newline in the TextEditor, so it needs an explicit
            // way to dismiss.
            .keyboardDoneButton()
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: text) { _, newValue in
                transactions = SMSExpenseParser.parse(newValue, date: date)
            }
            // The shared picker acts as "set all": moving it restamps every row,
            // discarding per-row edits, which is what asking for a new date means.
            .onChange(of: date) { _, newDate in
                for index in transactions.indices {
                    transactions[index].date = newDate
                }
            }
            .onAppear {
                if !text.isEmpty { transactions = SMSExpenseParser.parse(text, date: date) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(transactions.count)") { addAll() }
                        .fontWeight(.semibold)
                        .disabled(transactions.isEmpty)
                }
            }
        }
    }

    private func transactionRow(_ transaction: Binding<ParsedSMSTransaction>) -> some View {
        HStack(spacing: 12) {
            let resolved = category(named: transaction.wrappedValue.categoryName)
            Image(systemName: resolved?.symbolName ?? BuiltInCategory.fallback.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(resolved?.color ?? .gray)
                .frame(width: 38, height: 38)
                .background((resolved?.color ?? .gray).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Merchant and amount share the top line; the two controls get a line
            // of their own. Fitting all four across one line squeezes the picker
            // until its title wraps a letter per line.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(transaction.wrappedValue.merchant)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Text(CurrencyFormatter.string(from: transaction.wrappedValue.amount, currencyCode: transaction.wrappedValue.currency))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                HStack(spacing: 8) {
                    Picker("Category", selection: transaction.categoryName) {
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName).tag(category.name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()

                    Spacer(minLength: 4)

                    DatePicker(
                        "Date",
                        selection: transaction.date,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel("Date for \(transaction.wrappedValue.merchant)")
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func category(named name: String) -> ExpenseCategory? {
        categories.first { $0.name.lowercased() == name.lowercased() }
    }

    private func addAll() {
        ExpenseImporter.importExpenses(transactions, into: modelContext)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    ImportSMSView(prefilledText: "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30.")
        .modelContainer(for: Expense.self, inMemory: true)
}
