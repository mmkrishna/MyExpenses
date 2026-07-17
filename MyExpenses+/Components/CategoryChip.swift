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
                // Fixed width with a top-aligned two-line label keeps every chip the
                // same size, so longer names ("Parking Subscription") wrap instead of
                // stretching the chip or knocking the row of circles out of line.
                Text(category.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(width: 68, height: 26, alignment: .top)
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
