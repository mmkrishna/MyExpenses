import Foundation

enum CurrencyFormatter {
    static var preferredCurrencyCode: String {
        UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    static func string(from amount: Decimal, currencyCode: String = CurrencyFormatter.preferredCurrencyCode) -> String {
        let number = amount as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: number) ?? number.stringValue
    }
}
