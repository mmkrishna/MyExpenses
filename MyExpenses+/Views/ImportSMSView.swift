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
    @State private var errorMessage: String?
    /// Runs instead of `dismiss()` after a successful import, letting a presenter
    /// that is itself a sheet close the whole stack. Quick Add uses it to drop the
    /// user back on the Dashboard rather than the form they were passing through.
    /// Presenting from a tab root wants the plain dismiss, so this stays nil there.
    private let onImported: (() -> Void)?

    init(prefilledText: String = "", onImported: (() -> Void)? = nil) {
        _text = State(initialValue: prefilledText)
        self.onImported = onImported
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
            .scrollContentBackground(.hidden)
            .background(Theme.background)
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
                    // Counts what will actually be stored, so the button never
                    // promises to add a transfer it is going to skip.
                    Button("Add \(importableCount)") { addAll() }
                        .fontWeight(.semibold)
                        .disabled(importableCount == 0)
                }
            }
            .alert("Could not import expenses", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func transactionRow(_ transaction: Binding<ParsedSMSTransaction>) -> some View {
        HStack(spacing: 12) {
            let isCredit = transaction.wrappedValue.isCredit
            let isTransfer = transaction.wrappedValue.isTransfer
            let resolved = category(named: transaction.wrappedValue.categoryName)
            let iconName = isTransfer
                ? "arrow.left.arrow.right.circle.fill"
                : (isCredit ? "arrow.down.left.circle.fill" : (resolved?.symbolName ?? BuiltInCategory.fallback.systemImage))
            let iconColor = isTransfer ? Color.secondary : (isCredit ? Color.green : (resolved?.color ?? .gray))

            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 38, height: 38)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(transaction.wrappedValue.merchant)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if isCredit {
                            Text("• Income")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                        }
                        if isTransfer {
                            Text("• Not added")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    let amountStr = CurrencyFormatter.string(from: transaction.wrappedValue.amount, currencyCode: transaction.wrappedValue.currency)
                    Text(isCredit ? "+ " + amountStr : amountStr)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isCredit ? .green : .primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                }

                if isTransfer {
                    // Nothing on a transfer row is editable, because none of it
                    // gets stored — so it explains itself instead.
                    Text("Paying off a card moves your own money, so it isn't counted as spending. The purchases on that card are.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        if !isCredit {
                            Picker("Category", selection: transaction.categoryName) {
                                ForEach(categories) { category in
                                    Label(category.name, systemImage: category.symbolName).tag(category.name)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize()
                        }

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
        }
        .padding(.vertical, 4)
    }

    /// Transfers are shown but never stored, so the count the user acts on has to
    /// exclude them.
    private var importableCount: Int {
        transactions.count { !$0.isTransfer }
    }

    private func category(named name: String) -> ExpenseCategory? {
        categories.first { $0.name.lowercased() == name.lowercased() }
    }

    private func addAll() {
        do {
            let result = try ExpenseImporter.importExpenses(transactions, into: modelContext)
            if result.count == 0 {
                errorMessage = "These transactions were already imported."
                return
            }
            Haptics.success()
            // Dismissing here as well as in the handler would race: the presenter's
            // own dismissal already takes this sheet down with it, and the second
            // request lands mid-animation and is dropped.
            if let onImported {
                onImported()
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ImportSMSView(prefilledText: "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30.")
        .modelContainer(for: Expense.self, inMemory: true)
}
