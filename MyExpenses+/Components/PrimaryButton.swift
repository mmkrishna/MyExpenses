// PrimaryButton.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    /// Stretches the button to fill its container, for use as a standalone call to action.
    var fullWidth: Bool = false
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
            .padding(.vertical, fullWidth ? 14 : 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        // Still scales with Dynamic Type, but capped so a compact control can't
        // wrap or dominate its row at accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .fixedSize(horizontal: !fullWidth, vertical: false)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Button", systemImage: "plus") {}
        PrimaryButton(title: "Quick Add", systemImage: "plus", fullWidth: true) {}
    }
    .padding()
}
