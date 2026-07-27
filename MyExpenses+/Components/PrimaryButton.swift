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
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, fullWidth ? 15 : 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .foregroundStyle(.white)
            .background {
                if fullWidth {
                    Capsule().fill(Theme.ctaGradient)
                } else {
                    Capsule().fill(Color.accentColor)
                }
            }
            .shadow(color: Theme.primary.opacity(fullWidth ? 0.28 : 0),
                    radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
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
    .background(Theme.background)
}
