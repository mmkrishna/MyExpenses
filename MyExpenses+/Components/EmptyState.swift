// EmptyState.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftUI

struct EmptyState: View {
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyState(message: "No data available.", systemImage: "tray")
}
