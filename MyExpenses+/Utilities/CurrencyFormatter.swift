import Foundation

enum CurrencyFormatter {
    static var preferredCurrencyCode: String {
        UserDefaults.standard.string(forKey: "preferredCurrencyCode")
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }

    /// The symbol for a currency code (e.g. "$" for USD, "AED" for AED), as the
    /// current locale writes it. Used where we show a bare symbol next to an
    /// amount the user is typing, so it must follow the app's chosen currency
    /// rather than the device locale's.
    static func symbol(for currencyCode: String = CurrencyFormatter.preferredCurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    static func string(from amount: Decimal, currencyCode: String = CurrencyFormatter.preferredCurrencyCode) -> String {
        let number = amount as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: number) ?? number.stringValue
    }
}
