import SwiftData
import SwiftUI

struct ImportSMSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var text: String
    @State private var transactions: [ParsedSMSTransaction] = []

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
                    Text("Amounts, merchants, and cards are detected automatically. All imported expenses use today's date.")
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
                transactions = SMSExpenseParser.parse(newValue)
            }
            .onAppear {
                if !text.isEmpty { transactions = SMSExpenseParser.parse(text) }
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
            Image(systemName: transaction.wrappedValue.category.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(transaction.wrappedValue.category.color)
                .frame(width: 38, height: 38)
                .background(transaction.wrappedValue.category.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.wrappedValue.merchant)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Picker("Category", selection: transaction.category) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.systemImage).tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.caption)
            }

            Spacer(minLength: 8)

            Text(CurrencyFormatter.string(from: transaction.wrappedValue.amount, currencyCode: transaction.wrappedValue.currency))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
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
