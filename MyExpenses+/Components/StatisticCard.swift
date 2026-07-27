// StatisticCard.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftUI

struct StatisticCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconTile(systemName: systemImage, tint: tint, size: 34)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack(spacing: 14) {
        StatisticCard(title: "Today", value: "$123.45", systemImage: "sun.max.fill", tint: Theme.warning)
        StatisticCard(title: "Budget Left", value: "$540.00", systemImage: "wallet.pass.fill", tint: Theme.success)
    }
    .padding()
    .background(Theme.background)
}
