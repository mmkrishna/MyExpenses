import SwiftData
import SwiftUI

struct IncomeView: View {
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var selectedSourceFilter: IncomeSource? = nil
    @State private var showingAddIncome: Bool = false
    @State private var incomeToEdit: Income? = nil
    @State private var errorMessage: String? = nil

    /// Rows ticked while the list is in selection mode.
    @State private var selection: Set<UUID> = []
    @State private var isSelecting = false
    @State private var confirmingBulkDelete = false

    private var calendar: Calendar { Calendar.current }

    private var monthIncomeTotal: Decimal {
        let now = Date()
        return incomes
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var visibleIncomes: [Income] {
        incomes.filter { income in
            if let selectedSourceFilter {
                guard income.source == selectedSourceFilter else { return false }
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesPayer = income.payer.lowercased().contains(query)
                let matchesSource = income.sourceName.lowercased().contains(query)
                let matchesNotes = income.notes.lowercased().contains(query)
                guard matchesPayer || matchesSource || matchesNotes else { return false }
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    summaryHeroCard

                    sourceFilterChips
                        .padding(.vertical, 8)

                    if incomes.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            EmptyState(message: "No income recorded yet.", systemImage: "tray")
                            PrimaryButton(title: "Add Income", systemImage: "plus") {
                                showingAddIncome = true
                            }
                            Spacer()
                        }
                    } else if visibleIncomes.isEmpty {
                        VStack {
                            Spacer()
                            EmptyState(message: "No income matches your search.", systemImage: "magnifyingglass")
                            Spacer()
                        }
                    } else {
                        List(selection: $selection) {
                            Section {
                                ForEach(visibleIncomes) { income in
                                    IncomeRow(income: income)
                                        .tag(income.id)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                delete(income)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                incomeToEdit = income
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
                        .animation(.spring(duration: 0.35), value: visibleIncomes)
                        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
                    }
                }

                // Hidden while picking rows so it cannot sit on top of the
                // selection toolbar.
                if !incomes.isEmpty && !isSelecting {
                    floatingAddButton
                }
            }
            .tabBarClearance()
            .contentColumn()
            .background(Theme.background)
            .onTabReselect(.income) {
                guard let first = visibleIncomes.first else { return }
                withAnimation { scroll.scrollTo(first.id, anchor: .top) }
            }
            .navigationTitle("Income")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search payer, source, notes")
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Delete\(selection.isEmpty ? "" : " (\(selection.count))")", role: .destructive) {
                            confirmingBulkDelete = true
                        }
                        .tint(.red)
                        .disabled(selection.isEmpty)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation { endSelecting() }
                        }
                        .fontWeight(.semibold)
                    }
                } else if !visibleIncomes.isEmpty {
                    // Nothing to pick from until there are rows.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Select") {
                            withAnimation { isSelecting = true }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete \(selection.count) income record\(selection.count == 1 ? "" : "s")?",
                isPresented: $confirmingBulkDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showingAddIncome) {
                AddIncomeView()
            }
            .sheet(item: $incomeToEdit) { income in
                AddIncomeView(editing: income)
            }
            .alert("Income Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            }
        }
    }

    private var summaryHeroCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.left.circle.fill")
                        .foregroundStyle(.green)
                    Text("THIS MONTH'S CREDIT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text("+ " + CurrencyFormatter.string(from: monthIncomeTotal))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var sourceFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                IncomeSourceChip(
                    sourceName: "All",
                    symbolName: "square.grid.2x2",
                    color: Theme.primary,
                    isSelected: selectedSourceFilter == nil
                ) {
                    selectedSourceFilter = nil
                }

                ForEach(IncomeSource.allCases) { source in
                    IncomeSourceChip(
                        sourceName: source.rawValue,
                        symbolName: source.systemImage,
                        color: source.color,
                        isSelected: selectedSourceFilter == source
                    ) {
                        selectedSourceFilter = source
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var floatingAddButton: some View {
        Button {
            Haptics.tap()
            showingAddIncome = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.green)
                .clipShape(Circle())
                .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Add Income")
    }

    private func delete(_ income: Income) {
        modelContext.delete(income)
        do {
            try modelContext.save()
            Haptics.success()
        } catch {
            errorMessage = "Could not delete income record."
        }
    }

    /// Leaves selection mode and drops any ticks, so re-entering starts clean.
    private func endSelecting() {
        isSelecting = false
        selection.removeAll()
    }

    /// Deletes every selected record in one save, so a failure part-way cannot
    /// leave some rows gone and others not.
    private func deleteSelected() {
        let doomed = incomes.filter { selection.contains($0.id) }
        guard !doomed.isEmpty else { return }
        for income in doomed {
            modelContext.delete(income)
        }
        do {
            try modelContext.save()
            Haptics.success()
            withAnimation { endSelecting() }
        } catch {
            errorMessage = "Could not delete the selected income records."
        }
    }
}

#Preview {
    IncomeView()
        .modelContainer(SampleData.previewContainer)
}
