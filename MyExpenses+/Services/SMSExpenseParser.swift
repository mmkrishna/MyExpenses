import Foundation

/// A transaction extracted from a bank SMS, ready to become an Expense after review.
struct ParsedSMSTransaction: Identifiable {
    let id = UUID()
    var amount: Decimal
    var currency: String
    var merchant: String
    var category: ExpenseCategory
    var paymentMethod: PaymentMethod
    var cardLast4: String?
    var rawText: String
}

/// Parses bank purchase SMS into expense transactions.
///
/// Tuned for the common UAE bank format, e.g.:
/// "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30."
/// A single string may contain several such messages; all are returned.
enum SMSExpenseParser {
    // currency, amount, card type, last4 (optional), merchant (up to ". Avl"/". Available" or end)
    private static let pattern =
        #"Purchase of\s+([A-Za-z]{3})\s+([\d,]+(?:\.\d{1,2})?)\s+with\s+(Debit|Credit)\s+Card(?:\s+ending\s+(\d{3,4}))?\s+at\s+(.+?)(?:\.\s*Avl\b|\.\s*Available\b|$)"#

    private static let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

    static func parse(_ text: String) -> [ParsedSMSTransaction] {
        guard let regex else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let currency = capture(match, 1, in: text),
                  let amountString = capture(match, 2, in: text),
                  let amount = decimal(from: amountString), amount > 0,
                  let cardType = capture(match, 3, in: text),
                  let merchantRaw = capture(match, 5, in: text)
            else { return nil }

            let merchant = cleanMerchant(merchantRaw)

            return ParsedSMSTransaction(
                amount: amount,
                currency: currency.uppercased(),
                merchant: merchant,
                category: guessCategory(for: merchant),
                paymentMethod: cardType.lowercased() == "credit" ? .creditCard : .debitCard,
                cardLast4: capture(match, 4, in: text),
                rawText: fullMatch(match, in: text)
            )
        }
    }

    // MARK: - Helpers

    private static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func fullMatch(_ match: NSTextCheckingResult, in text: String) -> String {
        guard let range = Range(match.range, in: text) else { return "" }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decimal(from string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ",", with: ""))
    }

    /// Take the merchant name before the first comma (drops trailing location/phone).
    private static func cleanMerchant(_ raw: String) -> String {
        let name = raw.split(separator: ",").first.map(String.init) ?? raw
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let categoryKeywords: [(ExpenseCategory, [String])] = [
        (.coffee, ["COFFEE", "STARBUCKS", "COSTA", "TIM HORTON", "CAFFE", "ARABICA", "BLUE BOTTLE"]),
        (.food, ["REST", "RESTAURANT", "CAFE", "GRILL", "KITCHEN", "SHAWARMA", "BURGER", "PIZZA", "MCDONALD", "KFC", "SUBWAY", "DINING"]),
        (.grocery, ["CARREFOUR", "LULU", "SUPERMARKET", "GROCERY", "SPINNEYS", "UNION COOP", "WAITROSE", "AL MAYA", "MART", "HYPERMARKET"]),
        (.fuel, ["ADNOC", "ENOC", "EPPCO", "PETROL", "FUEL"]),
        (.transport, ["CAREEM", "UBER", "RTA", "METRO", "TAXI", "SALIK", "PARKING"]),
        (.health, ["PHARMACY", "ASTER", "MEDCARE", "CLINIC", "HOSPITAL", "MEDICAL"]),
        (.subscription, ["NETFLIX", "SPOTIFY", "OSN", "ANGHAMI", "SUBSCRIPTION", "APPLE.COM", "GOOGLE", "YOUTUBE"]),
        (.travel, ["EMIRATES", "FLYDUBAI", "AIR ARABIA", "BOOKING", "AGODA", "HOTEL", "AIRLINE", "AIRWAYS"]),
        (.bills, ["DEWA", "SEWA", "ETISALAT", "UTILITY"]),
        (.shopping, ["NOON", "AMAZON", "NAMSHI", "IKEA", "MALL", "CENTREPOINT", "UNIQLO", "SHARAF", "H&M", "STORE"]),
    ]

    static func guessCategory(for merchant: String) -> ExpenseCategory {
        let upper = merchant.uppercased()
        for (category, keywords) in categoryKeywords where keywords.contains(where: upper.contains) {
            return category
        }
        return .other
    }
}
