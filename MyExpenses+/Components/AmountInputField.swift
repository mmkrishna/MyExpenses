import SwiftUI

struct AmountInputField: View {
    let title: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    // Follow the currency chosen in Settings, not the device locale — otherwise
    // a US-locale phone shows "$" even after the user switches to AED. @AppStorage
    // so the symbol updates live when the setting changes.
    @AppStorage("preferredCurrencyCode") private var currencyCode = CurrencyFormatter.preferredCurrencyCode

    private var currencySymbol: String {
        CurrencyFormatter.symbol(for: currencyCode)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .focused(isFocused)
                    .accessibilityLabel("Amount")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
    }
}
