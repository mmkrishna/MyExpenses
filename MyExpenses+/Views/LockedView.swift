import SwiftUI

struct LockedView: View {
    let biometryName: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text("MyExpenses+ Locked")
                .font(.title2.weight(.semibold))
            Text("Use \(biometryName) to unlock your expenses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            PrimaryButton(title: "Unlock with \(biometryName)", systemImage: "faceid") {
                onUnlock()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
