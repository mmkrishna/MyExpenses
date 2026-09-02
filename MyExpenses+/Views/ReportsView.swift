// ReportsView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import Charts
import SwiftData
import SwiftUI

struct ReportsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]
    @State private var viewModel = ReportsViewModel()
    // Collapsed by default: the total is what matters at a glance, and the rows
    // otherwise push the charts below the fold.
    @State private var commitmentsExpanded = false
    @State private var selectedReportMonth = Date()

    private var monthlySummary: [MonthlySummary] {
        viewModel.combinedMonthlySeries(mode: viewModel.chartMode, expenses: expenses, incomes: incomes)
    }

    private var commitments: [RecurringCommitment] {
        viewModel.commitments(expenses)
    }

    private var categoryTotals: [CategorySpending] {
        viewModel.categoryTotals(expenses, in: selectedReportMonth)
    }

    private var incomeSourceTotals: [IncomeSourceTotal] {
        viewModel.incomeSourceTotals(incomes, in: selectedReportMonth)
    }

    private var dailyTrend: [DailyTotal] {
        viewModel.dailyTrend(expenses, for: selectedReportMonth)
    }

    /// Trailing 12 months including the current one, newest first, for the month picker.
    private var recentMonths: [Date] {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start else { return [Date()] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: -$0, to: currentMonthStart) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty && incomes.isEmpty {
                    VStack {
                        Spacer()
                        EmptyState(message: "Add some expenses to see your reports.", systemImage: "chart.pie")
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            summaryRow

                            if !commitments.isEmpty {
                                commitmentsCard
                            }

                            monthlyChartCard
                            categoryChartCard
                            incomeSourceChartCard
                            dailyTrendCard
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    monthMenu
                }
            }
            .sheet(item: Binding(
                get: { viewModel.shareURL.map(ShareItem.init) },
                set: { viewModel.shareURL = $0?.url }
            )) { item in
                ShareSheet(items: [item.url])
            }
            .alert(
                "Export Failed",
                isPresented: Binding(
                    get: { viewModel.exportAlertMessage != nil },
                    set: { if !$0 { viewModel.exportAlertMessage = nil } }
                ),
                presenting: viewModel.exportAlertMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var monthMenu: some View {
        Menu {
            ForEach(recentMonths, id: \.self) { month in
                Button {
                    selectedReportMonth = month
                } label: {
                    if Calendar.current.isDate(month, equalTo: selectedReportMonth, toGranularity: .month) {
                        Label(month.formatted(.dateTime.month(.wide).year()), systemImage: "checkmark")
                    } else {
                        Text(month.formatted(.dateTime.month(.wide).year()))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedReportMonth.formatted(.dateTime.month(.abbreviated).year()))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
        .accessibilityLabel("Selected month: \(selectedReportMonth.formatted(.dateTime.month(.wide).year()))")
    }

    private var summaryRow: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                StatisticCard(
                    title: "Total Spent",
                    value: CurrencyFormatter.string(from: viewModel.totalExpenses(expenses)),
                    systemImage: "sum",
                    tint: .blue
                )
                StatisticCard(
                    title: "Monthly Avg",
                    value: CurrencyFormatter.string(from: viewModel.monthlyAverage(expenses)),
                    systemImage: "chart.bar.fill",
                    tint: .purple
                )
            }
            if let highest = viewModel.highestCategory(expenses, in: selectedReportMonth) {
                StatisticCard(
                    title: "Top Category",
                    value: "\(highest.name) · \(CurrencyFormatter.string(from: highest.total))",
                    systemImage: highest.symbolName,
                    tint: highest.color
                )
            }
        }
    }

    private var commitmentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    commitmentsExpanded.toggle()
                }
                Haptics.tap()
            } label: {
                HStack(spacing: 8) {
                    Text("Monthly Commitments")
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text(CurrencyFormatter.string(from: RecurringCommitments.totalMonthly(commitments)))
                        .font(.headline)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(commitmentsExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Monthly Commitments, \(CurrencyFormatter.string(from: RecurringCommitments.totalMonthly(commitments))) per month")
            .accessibilityValue(commitmentsExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Double tap to \(commitmentsExpanded ? "hide" : "show") the breakdown")

            if commitmentsExpanded {
                VStack(spacing: 14) {
                    ForEach(commitments) { commitment in
                        commitmentRow(commitment)
                    }
                }

                Text("What your recurring expenses work out to per month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func commitmentRow(_ commitment: RecurringCommitment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: commitment.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(commitment.color)
                .frame(width: 28, height: 28)
                .background(commitment.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(commitment.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                // Show the real charge too, so the monthly figure is explainable.
                Text("\(commitment.frequency.rawValue) · \(CurrencyFormatter.string(from: commitment.chargedAmount, currencyCode: commitment.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.string(from: commitment.monthlyEquivalent, currencyCode: commitment.currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("per month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(commitment.displayName), \(commitment.frequency.rawValue) \(CurrencyFormatter.string(from: commitment.chargedAmount, currencyCode: commitment.currency)), "
            + "\(CurrencyFormatter.string(from: commitment.monthlyEquivalent, currencyCode: commitment.currency)) per month"
        )
    }

    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Monthly Spending")
                    .font(.headline)

                Spacer(minLength: 8)

                Menu {
                    Button {
                        viewModel.exportMonthlyCategoryReportCSV(
                            month: selectedReportMonth,
                            incomeTotal: viewModel.totalIncome(incomes, in: selectedReportMonth),
                            expenseTotal: viewModel.totalExpenses(expenses, in: selectedReportMonth),
                            categoryTotals: categoryTotals,
                            incomeSourceTotals: incomeSourceTotals
                        )
                    } label: {
                        Label("Export as CSV", systemImage: "doc.text")
                    }
                    Button {
                        viewModel.exportMonthlyCategoryReportPDF(
                            month: selectedReportMonth,
                            incomeTotal: viewModel.totalIncome(incomes, in: selectedReportMonth),
                            expenseTotal: viewModel.totalExpenses(expenses, in: selectedReportMonth),
                            categoryTotals: categoryTotals,
                            incomeSourceTotals: incomeSourceTotals,
                            currencyCode: CurrencyFormatter.preferredCurrencyCode
                        )
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Export report for \(selectedReportMonth.formatted(.dateTime.month(.wide).year()))")
            }

            Picker("Chart mode", selection: $viewModel.chartMode) {
                ForEach(MonthlyChartMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Chart(monthlySummary) { summary in
                BarMark(
                    x: .value("Month", summary.month, unit: .month),
                    y: .value("Amount", NSDecimalNumber(decimal: summary.income).doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Income"))
                .position(by: .value("Type", "Income"))
                .annotation(position: .top) {
                    if summary.income > 0 {
                        Text(CurrencyFormatter.compactString(from: summary.income))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                BarMark(
                    x: .value("Month", summary.month, unit: .month),
                    y: .value("Amount", NSDecimalNumber(decimal: summary.expense).doubleValue)
                )
                .foregroundStyle(by: .value("Type", "Expenses"))
                .position(by: .value("Type", "Expenses"))
                .annotation(position: .top) {
                    if summary.expense > 0 {
                        Text(CurrencyFormatter.compactString(from: summary.expense))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartForegroundStyleScale(["Income": Theme.success, "Expenses": Theme.danger])
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .accessibilityLabel("Monthly income and spending chart for the last six months")

            Text(viewModel.chartMode == .actual
                 ? "What you actually paid each month."
                 : "Recurring charges spread evenly, so quarterly and yearly bills don't spike.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.25), value: viewModel.chartMode)
    }

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending by Category")
                .font(.headline)

            if categoryTotals.isEmpty {
                Text("No expenses this month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(categoryTotals) { entry in
                    SectorMark(
                        angle: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(entry.color)
                }
                .frame(height: 200)
                .accessibilityLabel("Category breakdown pie chart for the current month")

                VStack(spacing: 8) {
                    ForEach(categoryTotals.prefix(6)) { entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 8, height: 8)
                            Text(entry.name)
                                .font(.caption)
                            Spacer()
                            Text(CurrencyFormatter.string(from: entry.total))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    private var incomeSourceChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Income by Category")
                .font(.headline)

            if incomeSourceTotals.isEmpty {
                Text("No income this month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(incomeSourceTotals) { entry in
                    SectorMark(
                        angle: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(entry.color)
                }
                .frame(height: 200)
                .accessibilityLabel("Income breakdown pie chart for the current month")

                VStack(spacing: 8) {
                    ForEach(incomeSourceTotals.prefix(6)) { entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 8, height: 8)
                            Text(entry.name)
                                .font(.caption)
                            Spacer()
                            Text(CurrencyFormatter.string(from: entry.total))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    private var dailyTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Spending Trend")
                .font(.headline)

            Chart(dailyTrend) { entry in
                LineMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Day", entry.day, unit: .day),
                    y: .value("Total", NSDecimalNumber(decimal: entry.total).doubleValue)
                )
                .foregroundStyle(Color.accentColor.opacity(0.12))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .accessibilityLabel("Daily spending trend for the current month")
        }
        .cardStyle()
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

#Preview {
    ReportsView()
        .modelContainer(SampleData.previewContainer)
}
