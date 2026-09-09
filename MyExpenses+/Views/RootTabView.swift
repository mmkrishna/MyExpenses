// RootTabView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, expenses, income, reports, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .expenses: "Expenses"
        case .income: "Income"
        case .reports: "Reports"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.3.group.bubble.left"
        case .expenses: "list.bullet.rectangle"
        case .income: "arrow.down.left.circle"
        case .reports: "chart.pie"
        case .settings: "gear"
        }
    }
}

struct RootTabView: View {
    @State private var selection: AppTab = .dashboard
    /// Screens are built on first visit and then kept, the way a TabView does
    /// it, so switching back to a tab returns it as it was left.
    @State private var visited: Set<AppTab> = [.dashboard]

    var body: some View {
        // Not a TabView. iPadOS 18 and later draw a TabView's bar across the
        // *top* of the screen and nothing moves it back down — SwiftUI's
        // `tabBarPlacement` is read-only and `UITabBarController.Mode` only
        // picks between a tab bar and a sidebar. Hiding it with
        // `.toolbar(.hidden, for: .tabBar)` and insetting our own bar does not
        // work either: TabView re-establishes its children's safe area from the
        // window, so the inset never reaches the screens and anything anchored
        // to the bottom — the floating add buttons, the last rows of a list —
        // ends up underneath the bar.
        //
        // Switching the screens here instead keeps the safe area honest, and is
        // what gives an iPad the same bottom bar as an iPhone.
        // The GeometryReader is only here to measure the bottom safe area for
        // the bar's scroll edge effect.
        GeometryReader { proxy in
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    if visited.contains(tab) {
                        content(for: tab)
                            .opacity(tab == selection ? 1 : 0)
                            .allowsHitTesting(tab == selection)
                            .accessibilityHidden(tab != selection)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                BottomTabBar(
                    selection: $selection,
                    bottomSafeArea: proxy.safeAreaInsets.bottom
                )
            }
            .onChange(of: selection) { _, tab in
                visited.insert(tab)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .expenses: ExpensesView()
        case .income: IncomeView()
        case .reports: ReportsView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.previewContainer)
        .environment(UserProfileViewModel())
        .preferredColorScheme(.light)
    RootTabView()
        .modelContainer(SampleData.previewContainer)
        .environment(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
