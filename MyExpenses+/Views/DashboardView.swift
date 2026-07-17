// DashboardView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0
    @State private var viewModel = DashboardViewModel()
    @Environment(UserProfileViewModel.self) private var profile
    @State private var showingEditProfile = false

    private var monthSpending: Decimal {
        viewModel.monthSpending(expenses)
    }

    private var todaySpending: Decimal {
        viewModel.todaySpending(expenses)
    }

    private var remainingBudget: Decimal {
        viewModel.remainingBudget(monthlyBudget: Decimal(monthlyBudget), monthSpending: monthSpending)
    }

    private var recentExpenses: [Expense] {
        viewModel.recentExpenses(expenses)
    }

    private var categoryBreakdown: [CategorySpending] {
        viewModel.categoryBreakdown(expenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader

                    monthSpendingHero

                    HStack(spacing: 14) {
                        StatisticCard(
                            title: "Today",
                            value: CurrencyFormatter.string(from: todaySpending),
                            systemImage: "sun.max.fill",
                            tint: .orange
                        )
                        StatisticCard(
                            title: "Budget Left",
                            value: remainingBudgetText,
                            systemImage: "wallet.pass.fill",
                            tint: .green
                        )
                    }

                    PrimaryButton(title: "Quick Add", systemImage: "plus", fullWidth: true) {
                        viewModel.showingAddExpense = true
                    }

                    if !categoryBreakdown.isEmpty {
                        categoryBreakdownSection
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Expenses")
                            .font(.headline)

                        if recentExpenses.isEmpty {
                            EmptyState(message: "No recent expenses.", systemImage: "tray")
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { index, expense in
                                    ExpenseRow(expense: expense)
                                    if index < recentExpenses.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .cardStyle()
                }
                .padding()
                .animation(.spring(duration: 0.4), value: recentExpenses)
            }
            .background(Color(.systemGroupedBackground))
            // No nav title: the greeting header serves as the screen's heading.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $viewModel.showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 12) {
            Button {
                showingEditProfile = true
            } label: {
                ProfileAvatarView(photoData: profile.photoData, initials: profile.initials, size: 44)
            }
            .accessibilityLabel("Edit profile")

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.greeting)
                    .font(.title3.weight(.bold))
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var heroValue: Decimal {
        viewModel.value(for: viewModel.metric, expenses: expenses)
    }

    /// Tapping cycles through the figures rather than giving each its own card.
    private var monthSpendingHero: some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(duration: 0.3)) {
                viewModel.advanceMetric()
            }
        } label: {
            heroContent
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.metric.rawValue): \(CurrencyFormatter.string(from: heroValue)). \(viewModel.metric.caption)")
        .accessibilityHint("Tap to show the next figure")
        .accessibilityAddTraits(.isButton)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(viewModel.metric.rawValue, systemImage: viewModel.metric.systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 0)
                // Dots hint that there is more than one figure behind this card.
                HStack(spacing: 5) {
                    ForEach(DashboardMetric.allCases) { metric in
                        Circle()
                            .fill(.white.opacity(metric == viewModel.metric ? 0.95 : 0.35))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }

            Text(CurrencyFormatter.string(from: heroValue))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(viewModel.metric.caption)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Spending by Category")
                .font(.headline)

            VStack(spacing: 14) {
                ForEach(categoryBreakdown.prefix(5)) { entry in
                    categoryBreakdownRow(entry)
                }
            }
        }
        .cardStyle()
    }

    private func categoryBreakdownRow(_ entry: CategorySpending) -> some View {
        let fraction = monthSpending > 0 ? min(NSDecimalNumber(decimal: entry.total / monthSpending).doubleValue, 1) : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: entry.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.category.color)
                    .frame(width: 24, height: 24)
                    .background(entry.category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)

                Text(entry.category.displayName)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(CurrencyFormatter.string(from: entry.total))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(entry.category.color)
                            .frame(width: geometry.size.width * fraction)
                    }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.category.displayName): \(CurrencyFormatter.string(from: entry.total))")
    }

    private var remainingBudgetText: String {
        guard monthlyBudget > 0 else { return "Not set" }
        return CurrencyFormatter.string(from: remainingBudget)
    }
}

#Preview {
    DashboardView()
        .modelContainer(SampleData.previewContainer)
        .environment(UserProfileViewModel())
}
