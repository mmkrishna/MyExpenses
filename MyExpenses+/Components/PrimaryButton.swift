// PrimaryButton.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .fontWeight(.semibold)
                }
                Text(title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        // Keep this compact pill a sensible size: it still scales with Dynamic Type,
        // but is capped so it can't wrap or dominate the row at accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(title)
    }
}

#Preview {
    PrimaryButton(title: "Button", systemImage: "plus") {}
}
