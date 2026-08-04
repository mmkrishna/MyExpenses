import SwiftData
import SwiftUI

enum QuickAddMode: String, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"

    var id: String { rawValue }
}

struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]

    @FocusState private var amountFieldFocused: Bool
    @State private var errorMessage: String?
    @State private var pasteStatusMessage: String?
    @State private var smsImportPayload: SMSImportPayload?

    // Mode Selector (Default: Expense)
    @State private var mode: QuickAddMode = .expense

    // Common fields
    @State private var amountText: String = ""
    @State private var merchantOrPayer: String = ""
    @State private var date: Date = Date()
    @State private var paymentMethod: PaymentMethod = .cash
    @State private var notes: String = ""

    // Expense fields
    @State private var selectedCategory: ExpenseCategory?
    @State private var recurrenceFrequency: RecurrenceFrequency?
    @State private var recurrenceHasEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Date()

    // Income fields
    @State private var selectedIncomeSource: IncomeSource = .salary
    @State private var customSourceName: String = ""

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount = parsedAmount, amount > 0 else { return false }
        if mode == .income && selectedIncomeSource == .custom && customSourceName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    modePickerHeader

                    pasteFromClipboardButton

                    if let pasteStatusMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(pasteStatusMessage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                    }

                    AmountInputField(
                        title: mode == .expense ? "Expense Amount" : "Income Amount",
                        text: $amountText,
                        isFocused: $amountFieldFocused
                    )

                    if mode == .expense {
                        expenseCategoryPicker
                    } else {
                        incomeSourcePicker
                    }

                    detailFormRows
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Quick Add")
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
                if selectedCategory == nil {
                    selectedCategory = categories.first { $0.name == BuiltInCategory.fallback.rawValue } ?? categories.first
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    amountFieldFocused = true
                }
            }
            .alert("Could not save transaction", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            // Quick Add is only a waypoint on the paste route, so a completed
            // import closes it too and lands the user back on the Dashboard.
            .sheet(item: $smsImportPayload) { payload in
                ImportSMSView(prefilledText: payload.text) { dismiss() }
            }
        }
    }

    private var modePickerHeader: some View {
        Picker("Mode", selection: $mode) {
            ForEach(QuickAddMode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            Haptics.selection()
        }
    }

    private var pasteFromClipboardButton: some View {
        Button {
            pasteFromClipboard()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.subheadline.weight(.semibold))
                Text("Paste from Clipboard")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var expenseCategoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var incomeSourcePicker: some View {
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
                            isSelected: selectedIncomeSource == source
                        ) {
                            selectedIncomeSource = source
                        }
                    }
                }
            }
        }
    }

    private var detailFormRows: some View {
        VStack(spacing: 0) {
            if mode == .income && selectedIncomeSource == .custom {
                detailRow(icon: "tag", tint: .purple) {
                    TextField("Custom Source Name", text: $customSourceName)
                }
                Divider().padding(.leading, 52)
            }

            detailRow(icon: mode == .expense ? "storefront" : "person.text.rectangle", tint: mode == .expense ? .blue : .green) {
                TextField(mode == .expense ? "Merchant" : "Payer / Source Name", text: $merchantOrPayer)
            }
            Divider().padding(.leading, 52)

            detailRow(icon: "calendar", tint: .red) {
                DatePicker("Date", selection: $date, displayedComponents: .date)
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

            if mode == .expense {
                Divider().padding(.leading, 52)
                detailRow(icon: "repeat", tint: .cyan) {
                    Picker("Repeat", selection: $recurrenceFrequency) {
                        Text("Never").tag(Optional<RecurrenceFrequency>.none)
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(Optional(frequency))
                        }
                    }
                    .labelsHidden()
                }
                if recurrenceFrequency != nil {
                    Divider().padding(.leading, 52)
                    detailRow(icon: "calendar.badge.exclamationmark", tint: .pink) {
                        Toggle("End Date", isOn: $recurrenceHasEndDate)
                    }
                    if recurrenceHasEndDate {
                        Divider().padding(.leading, 52)
                        detailRow(icon: "calendar", tint: .pink) {
                            DatePicker("Ends", selection: $recurrenceEndDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
            }

            Divider().padding(.leading, 52)
            detailRow(icon: "note.text", tint: .gray) {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .cardStyle(padding: 0)
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

    private func pasteFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation {
                pasteStatusMessage = "Clipboard is empty"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    pasteStatusMessage = nil
                }
            }
            return
        }

        Haptics.tap()
        smsImportPayload = SMSImportPayload(text: clipboardText)
    }

    private func save() {
        guard let amount = parsedAmount else { return }

        if mode == .expense {
            let expense = Expense(
                amount: amount,
                category: selectedCategory ?? CategoryStore.fallback(in: modelContext),
                date: date,
                notes: notes,
                paymentMethod: paymentMethod.rawValue,
                merchant: merchantOrPayer,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceEndDate: recurrenceHasEndDate ? recurrenceEndDate : nil,
                seriesID: recurrenceFrequency != nil ? UUID() : nil
            )
            modelContext.insert(expense)
        } else {
            let srcName = selectedIncomeSource == .custom ? (customSourceName.isEmpty ? "Custom" : customSourceName) : selectedIncomeSource.rawValue
            let income = Income(
                amount: amount,
                sourceName: srcName,
                payer: merchantOrPayer,
                date: date,
                notes: notes,
                paymentMethod: paymentMethod.rawValue
            )
            modelContext.insert(income)
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
    QuickAddView()
        .modelContainer(SampleData.previewContainer)
}
