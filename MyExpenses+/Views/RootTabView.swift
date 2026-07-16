// RootTabView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftData
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "rectangle.3.group.bubble.left") {
                DashboardView()
            }
            Tab("Expenses", systemImage: "list.bullet.rectangle") {
                ExpensesView()
            }
            Tab("Reports", systemImage: "chart.pie") {
                ReportsView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
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
