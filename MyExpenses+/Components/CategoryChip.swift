import SwiftUI

struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : category.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: category.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : category.color)
                }
                Text(category.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack {
        CategoryChip(category: .food, isSelected: true) {}
        CategoryChip(category: .travel, isSelected: false) {}
    }
    .padding()
}
