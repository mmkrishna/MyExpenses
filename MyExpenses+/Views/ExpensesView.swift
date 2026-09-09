// ExpensesView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftData
import SwiftUI

struct ExpensesView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ExpensesViewModel()
    @State private var errorMessage: String?

    private var visibleExpenses: [Expense] {
        viewModel.filteredAndSorted(expenses)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if expenses.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            EmptyState(message: "No expenses yet.", systemImage: "tray")
                            PrimaryButton(title: "Add Expense", systemImage: "plus") {
                                viewModel.showingAddExpense = true
                            }
                            Spacer()
                        }
                    } else if visibleExpenses.isEmpty {
                        VStack {
                            Spacer()
                            EmptyState(message: "No expenses match your search.", systemImage: "magnifyingglass")
                            Spacer()
                        }
                    } else {
                        List(selection: $viewModel.selection) {
                            Section {
                                ForEach(visibleExpenses) { expense in
                                    ExpenseRow(expense: expense)
                                        .tag(expense.id)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                do {
                                                    try viewModel.delete(expense, context: modelContext)
                                                } catch {
                                                    errorMessage = error.localizedDescription
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                viewModel.expenseToEdit = expense
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                            .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Theme.background)
                        .animation(.spring(duration: 0.35), value: visibleExpenses)
                        .environment(\.editMode, .constant(viewModel.isSelecting ? .active : .inactive))
                    }
                }

                // The empty state has its own "Add Expense" button, and the floating
                // one would sit on top of the selection toolbar, so it stays hidden
                // while picking rows.
                if !expenses.isEmpty && !viewModel.isSelecting {
                    addButton
                }
            }
            .tabBarClearance()
            .contentColumn()
            .background(Theme.background)
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search merchant, notes, category")
            .toolbar {
                if viewModel.isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Delete\(viewModel.selection.isEmpty ? "" : " (\(viewModel.selection.count))")", role: .destructive) {
                            viewModel.confirmingBulkDelete = true
                        }
                        .tint(.red)
                        .disabled(viewModel.selection.isEmpty)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation { viewModel.endSelecting() }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        monthFilterMenu
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.tap()
                            viewModel.smsImportPayload = SMSImportPayload(text: UIPasteboard.general.string ?? "")
                        } label: {
                            Image(systemName: "envelope.badge")
                        }
                        .accessibilityLabel("Import from SMS")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                    // Nothing to pick from until there are rows.
                    if !visibleExpenses.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Select") {
                                withAnimation { viewModel.isSelecting = true }
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete \(viewModel.selection.count) expense\(viewModel.selection.count == 1 ? "" : "s")?",
                isPresented: $viewModel.confirmingBulkDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    do {
                        try viewModel.deleteSelected(from: expenses, context: modelContext)
                        withAnimation { viewModel.endSelecting() }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $viewModel.showingAddExpense) {
                AddExpenseView()
            }
            .sheet(item: $viewModel.smsImportPayload) { payload in
                ImportSMSView(prefilledText: payload.text)
            }
            .sheet(item: $viewModel.expenseToEdit) { expense in
                AddExpenseView(editing: expense)
            }
            .alert("Could not delete expense", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var addButton: some View {
        Button {
            Haptics.tap()
            viewModel.showingAddExpense = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.ctaGradient))
                .shadow(color: Theme.primary.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.trailing, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
        .accessibilityLabel("Add Expense")
    }

    private var monthFilterMenu: some View {
        Menu {
            Button {
                viewModel.selectedMonth = nil
            } label: {
                if viewModel.selectedMonth == nil {
                    Label("All Months", systemImage: "checkmark")
                } else {
                    Text("All Months")
                }
            }
            ForEach(viewModel.availableMonths(in: expenses), id: \.self) { month in
                Button {
                    viewModel.selectedMonth = month
                } label: {
                    let isSelected = viewModel.selectedMonth.map { Calendar.current.isDate($0, equalTo: month, toGranularity: .month) } ?? false
                    let title = month.formatted(.dateTime.month(.wide).year())
                    if isSelected {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            Image(systemName: "calendar")
        }
        .accessibilityLabel("Filter by month")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOption) {
                ForEach(ExpenseSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("Sort expenses")
    }
}

#Preview {
    ExpensesView()
        .modelContainer(SampleData.previewContainer)
}
