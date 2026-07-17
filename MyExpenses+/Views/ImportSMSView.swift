import SwiftData
import SwiftUI

struct ImportSMSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]
    @State private var text: String
    @State private var transactions: [ParsedSMSTransaction] = []
    /// Bank messages carry no date, so the user picks the one to file them under.
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
                    Text("Bank messages don't include a date, so pick when these were spent. Applies to everything in this paste.")
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
            let resolved = category(named: transaction.wrappedValue.categoryName)
            Image(systemName: resolved?.symbolName ?? BuiltInCategory.fallback.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(resolved?.color ?? .gray)
                .frame(width: 38, height: 38)
                .background((resolved?.color ?? .gray).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.wrappedValue.merchant)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Picker("ExpenseCategory", selection: transaction.categoryName) {
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.symbolName).tag(category.name)
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

    private func category(named name: String) -> ExpenseCategory? {
        categories.first { $0.name.lowercased() == name.lowercased() }
    }

    private func addAll() {
        ExpenseImporter.importExpenses(transactions, into: modelContext, date: date)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    ImportSMSView(prefilledText: "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30.")
        .modelContainer(for: Expense.self, inMemory: true)
}
