// StatisticCard.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftUI

struct StatisticCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    StatisticCard(title: "Sample Stat", value: "$123.45", systemImage: "star")
}
