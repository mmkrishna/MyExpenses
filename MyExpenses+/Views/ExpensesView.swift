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
                        List {
                            Section {
                                ForEach(visibleExpenses) { expense in
                                    ExpenseRow(expense: expense)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                viewModel.delete(expense, context: modelContext)
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
                        .background(Color(.systemGroupedBackground))
                        .animation(.spring(duration: 0.35), value: visibleExpenses)
                    }
                }

                addButton
            }
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search merchant, notes, category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    monthFilterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        viewModel.showingImportSMS = true
                    } label: {
                        Image(systemName: "envelope.badge")
                    }
                    .accessibilityLabel("Import from SMS")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .sheet(isPresented: $viewModel.showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $viewModel.showingImportSMS) {
                ImportSMSView()
            }
            .sheet(item: $viewModel.expenseToEdit) { expense in
                AddExpenseView(editing: expense)
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
                .background(Circle().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 10, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
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
