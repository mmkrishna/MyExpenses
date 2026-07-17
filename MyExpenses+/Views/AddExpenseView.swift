import SwiftData
import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: AddEditExpenseViewModel
    @FocusState private var amountFieldFocused: Bool

    init(editing expense: Expense? = nil) {
        _viewModel = State(initialValue: AddEditExpenseViewModel(editing: expense))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AmountInputField(title: "Amount", text: $viewModel.amountText, isFocused: $amountFieldFocused)

                    categoryPicker

                    VStack(spacing: 0) {
                        detailRow(icon: "storefront", tint: .blue) {
                            TextField("Merchant", text: $viewModel.merchant)
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "calendar", tint: .red) {
                            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "creditcard", tint: .indigo) {
                            Picker("Payment Method", selection: $viewModel.paymentMethod) {
                                ForEach(PaymentMethod.allCases) { method in
                                    Label(method.rawValue, systemImage: method.systemImage)
                                        .tag(method)
                                }
                            }
                            .labelsHidden()
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "repeat", tint: .cyan) {
                            Picker("Repeat", selection: $viewModel.recurrenceFrequency) {
                                Text("Never").tag(Optional<RecurrenceFrequency>.none)
                                ForEach(RecurrenceFrequency.allCases) { frequency in
                                    Text(frequency.rawValue).tag(Optional(frequency))
                                }
                            }
                            .labelsHidden()
                        }
                        if viewModel.recurrenceFrequency != nil {
                            Divider().padding(.leading, 52)
                            detailRow(icon: "calendar.badge.exclamationmark", tint: .pink) {
                                Toggle("End Date", isOn: $viewModel.recurrenceHasEndDate)
                            }
                            if viewModel.recurrenceHasEndDate {
                                Divider().padding(.leading, 52)
                                detailRow(icon: "calendar", tint: .pink) {
                                    DatePicker("Ends", selection: $viewModel.recurrenceEndDate, displayedComponents: .date)
                                        .labelsHidden()
                                }
                            }
                        }
                        Divider().padding(.leading, 52)
                        detailRow(icon: "note.text", tint: .gray) {
                            TextField("Notes", text: $viewModel.notes, axis: .vertical)
                                .lineLimit(1...4)
                        }
                    }
                    .cardStyle(padding: 0)
                    .animation(.spring(duration: 0.25), value: viewModel.recurrenceFrequency)
                    .animation(.spring(duration: 0.25), value: viewModel.recurrenceHasEndDate)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            // Amount uses .decimalPad and Notes is multi-line, so neither keyboard
            // can dismiss itself; the keyboard also covers the fields below.
            .keyboardDoneButton()
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    amountFieldFocused = true
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExpenseCategory.allCases) { option in
                    CategoryChip(category: option, isSelected: option == viewModel.category) {
                        viewModel.category = option
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, tint: Color, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func save() {
        guard viewModel.save(context: modelContext) else { return }
        Haptics.success()
        dismiss()
    }
}

#Preview("Add") {
    AddExpenseView()
        .modelContainer(for: Expense.self, inMemory: true)
}
