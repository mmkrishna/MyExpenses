import SwiftUI

struct IncomeSourceChip: View {
    let sourceName: String
    let symbolName: String
    let color: Color
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
                        .fill(isSelected ? color : color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : color)
                }
                Text(sourceName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(width: 68, height: 26, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sourceName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
