import SwiftData
import SwiftUI

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @FocusState private var amountFieldFocused: Bool
    @State private var errorMessage: String?

    let editingIncome: Income?

    @State private var amountText: String = ""
    @State private var selectedSource: IncomeSource = .salary
    @State private var customSourceName: String = ""
    @State private var payer: String = ""
    @State private var date: Date = Date()
    @State private var paymentMethod: PaymentMethod = .bankTransfer
    @State private var notes: String = ""

    init(editing income: Income? = nil) {
        self.editingIncome = income
        if let income {
            _amountText = State(initialValue: "\(income.amount)")
            _selectedSource = State(initialValue: income.source)
            _customSourceName = State(initialValue: income.source == .custom ? income.sourceName : "")
            _payer = State(initialValue: income.payer)
            _date = State(initialValue: income.date)
            _paymentMethod = State(initialValue: PaymentMethod(rawValue: income.paymentMethod) ?? .bankTransfer)
            _notes = State(initialValue: income.notes)
        }
    }

    private var sourceName: String {
        selectedSource == .custom ? (customSourceName.isEmpty ? "Custom" : customSourceName) : selectedSource.rawValue
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        if selectedSource == .custom && customSourceName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AmountInputField(title: "Income Amount", text: $amountText, isFocused: $amountFieldFocused)

                    sourceSelector

                    if selectedSource == .custom {
                        VStack(spacing: 0) {
                            detailRow(icon: "tag", tint: .purple) {
                                TextField("Custom Source Name", text: $customSourceName)
                            }
                        }
                        .cardStyle(padding: 0)
                    }

                    VStack(spacing: 0) {
                        detailRow(icon: "person.text.rectangle", tint: .green) {
                            TextField("Payer / Source (e.g. Company, Bank)", text: $payer)
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "calendar", tint: .blue) {
                            DatePicker("Date Received", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "creditcard", tint: .indigo) {
                            Picker("Payment Method", selection: $paymentMethod) {
                                ForEach(PaymentMethod.allCases) { method in
                                    Label(method.rawValue, systemImage: method.systemImage)
                                        .tag(method)
                                }
                            }
                            .labelsHidden()
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "note.text", tint: .gray) {
                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(1...4)
                        }
                    }
                    .cardStyle(padding: 0)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(editingIncome == nil ? "Add Income" : "Edit Income")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    amountFieldFocused = true
                }
            }
            .alert("Could not save income", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Income Source")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(IncomeSource.allCases) { source in
                        IncomeSourceChip(
                            sourceName: source.rawValue,
                            symbolName: source.systemImage,
                            color: source.color,
                            isSelected: selectedSource == source
                        ) {
                            selectedSource = source
                        }
                    }
                }
            }
        }
    }

    private func detailRow<Content: View>(
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            content()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func save() {
        guard let amount = parsedAmount else { return }

        if let income = editingIncome {
            income.amount = amount
            income.sourceName = sourceName
            income.payer = payer
            income.date = date
            income.paymentMethod = paymentMethod.rawValue
            income.notes = notes
            income.updatedAt = Date()
        } else {
            let newIncome = Income(
                amount: amount,
                sourceName: sourceName,
                payer: payer,
                date: date,
                notes: notes,
                paymentMethod: paymentMethod.rawValue
            )
            modelContext.insert(newIncome)
        }

        do {
            try modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = "Please try saving again."
        }
    }
}

#Preview {
    AddIncomeView()
}
