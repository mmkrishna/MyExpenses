import Foundation

/// A transaction extracted from a bank SMS, ready to become an Expense or Income after review.
struct ParsedSMSTransaction: Identifiable {
    let id = UUID()
    var amount: Decimal
    var currency: String
    var merchant: String
    /// The guessed category's name. Resolved to an `ExpenseCategory` or `IncomeSource`
    /// where a context is available.
    var categoryName: String
    /// When the purchase or credit happened.
    var date: Date
    var paymentMethod: PaymentMethod
    var cardLast4: String?
    var rawText: String
    var isCredit: Bool = false
}

/// Parses bank purchase and credit SMS messages into transaction objects.
enum SMSExpenseParser {
    // 1. UAE / Standard Purchase:
    // "Purchase of AED 42.93 with Debit Card ending 0807 at Noon..."
    private static let uaePattern =
        #"Purchase of\s+([A-Za-z]{3})\s+([\d,]+(?:\.\d{1,2})?)\s+with\s+(Debit|Credit)\s+Card(?:\s+ending\s+(\d{3,4}))?\s+at\s+(.+?)(?:\.\s*Avl\b|\.\s*Available\b|$)"#

    // 2. Indian Bank Credit:
    // "Dear Customer, Acct XX051 is credited with Rs 2480.00 on 01-Aug-26 from SHYAM SUNDER KU. UPI:490897397234-ICICI Bank."
    // "Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank"
    private static let indianCreditPattern =
        #"(?:Acct|A/c)\s+([A-Za-z0-9_]+)?\s*(?:is\s+)?credited\s+with\s+(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)(?:\s+on\s+([^\s;\.,]+))?\s+from\s+([^;\.\r\n]+)"#

    // 3. Indian Bank Txn / Debit:
    // "Txn Rs.149.00\nOn HDFC Bank Card 5865\nAt returnswealth710648.rzp@r \nby UPI 658121756648\nOn 03-08..."
    private static let indianTxnPattern =
        #"Txn\s+(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)(?:[\s\S]*?)(?:Card\s+(\d{3,4}))?(?:[\s\S]*?)At\s+([^\n;\r]+)"#

    // 4. IndusInd / Spent at Debit Pattern:
    // "INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60."
    private static let spentPattern =
        #"(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)\s+spent\s+(?:on|with|at)\s+(?:[A-Za-z0-9_\s]*?Card\s*(?:XX|ending)?\s*(\d{3,4}))?(?:[\s\S]*?)(?:on\s+(\d{2}[-\/]\d{2}[-\/]\d{2,4}|\d{2}[-\/][A-Za-z]{3}[-\/]\d{2,4}))?(?:[\s\S]*?)at\s+([^;\.\r\n]+)"#

    private static let uaeRegex = try? NSRegularExpression(pattern: uaePattern, options: [.caseInsensitive])
    private static let creditRegex = try? NSRegularExpression(pattern: indianCreditPattern, options: [.caseInsensitive])
    private static let txnRegex = try? NSRegularExpression(pattern: indianTxnPattern, options: [.caseInsensitive])
    private static let spentRegex = try? NSRegularExpression(pattern: spentPattern, options: [.caseInsensitive])

    static func parse(_ text: String, date defaultDate: Date = Date()) -> [ParsedSMSTransaction] {
        var results: [ParsedSMSTransaction] = []

        let blocks = splitIntoMessageBlocks(text)

        for block in blocks {
            let range = NSRange(block.startIndex..<block.endIndex, in: block)

            // Try Indian Credit match
            if let creditRegex, let match = creditRegex.firstMatch(in: block, options: [], range: range) {
                let cardLast4 = capture(match, 1, in: block)?
                    .replacingOccurrences(of: "X", with: "", options: .caseInsensitive)
                let rawCurrency = capture(match, 2, in: block) ?? "INR"
                let amountString = capture(match, 3, in: block) ?? "0"
                let dateString = capture(match, 4, in: block)
                let payerRaw = capture(match, 5, in: block) ?? "Income"

                if let amount = decimal(from: amountString), amount > 0 {
                    let currency = normalizeCurrency(rawCurrency)
                    let payer = cleanMerchant(payerRaw)
                    let txDate = parseDate(dateString, defaultDate: defaultDate)
                    let paymentMethod = detectPaymentMethod(in: block, defaultCredit: true)

                    results.append(ParsedSMSTransaction(
                        amount: amount,
                        currency: currency,
                        merchant: payer,
                        categoryName: guessCategory(for: payer).rawValue,
                        date: txDate,
                        paymentMethod: paymentMethod,
                        cardLast4: cardLast4,
                        rawText: block.trimmingCharacters(in: .whitespacesAndNewlines),
                        isCredit: true
                    ))
                    continue
                }
            }

            // Try Spent Debit match (e.g. "INR 272.00 spent on IndusInd Card XX8022...")
            if let spentRegex, let match = spentRegex.firstMatch(in: block, options: [], range: range) {
                let rawCurrency = capture(match, 1, in: block) ?? "INR"
                let amountString = capture(match, 2, in: block) ?? "0"
                let cardLast4 = capture(match, 3, in: block)?
                    .replacingOccurrences(of: "X", with: "", options: .caseInsensitive)
                let dateString = capture(match, 4, in: block)
                let merchantRaw = capture(match, 5, in: block) ?? "Merchant"

                if let amount = decimal(from: amountString), amount > 0 {
                    let currency = normalizeCurrency(rawCurrency)
                    let merchant = cleanMerchant(merchantRaw)
                    let txDate = parseDate(dateString, defaultDate: defaultDate)
                    let paymentMethod = detectPaymentMethod(in: block, defaultCredit: false)

                    results.append(ParsedSMSTransaction(
                        amount: amount,
                        currency: currency,
                        merchant: merchant,
                        categoryName: guessCategory(for: merchant).rawValue,
                        date: txDate,
                        paymentMethod: paymentMethod,
                        cardLast4: cardLast4,
                        rawText: block.trimmingCharacters(in: .whitespacesAndNewlines),
                        isCredit: false
                    ))
                    continue
                }
            }

            // Try Indian Txn / Debit match
            if let txnRegex, let match = txnRegex.firstMatch(in: block, options: [], range: range) {
                let rawCurrency = capture(match, 1, in: block) ?? "INR"
                let amountString = capture(match, 2, in: block) ?? "0"
                let cardLast4 = capture(match, 3, in: block)
                let merchantRaw = capture(match, 4, in: block) ?? "Merchant"

                if let amount = decimal(from: amountString), amount > 0 {
                    let currency = normalizeCurrency(rawCurrency)
                    let merchant = cleanMerchant(merchantRaw)
                    let paymentMethod = detectPaymentMethod(in: block, defaultCredit: false)

                    // Extract date if present (e.g. "On 03-08")
                    var txDate = defaultDate
                    if let dateMatch = block.range(of: #"On\s+(\d{2}[-\/]\d{2}(?:[-\/]\d{2,4})?)"#, options: [.regularExpression, .caseInsensitive]) {
                        let dateSub = String(block[dateMatch]).replacingOccurrences(of: "On ", with: "", options: .caseInsensitive)
                        txDate = parseDate(dateSub, defaultDate: defaultDate)
                    }

                    results.append(ParsedSMSTransaction(
                        amount: amount,
                        currency: currency,
                        merchant: merchant,
                        categoryName: guessCategory(for: merchant).rawValue,
                        date: txDate,
                        paymentMethod: paymentMethod,
                        cardLast4: cardLast4,
                        rawText: block.trimmingCharacters(in: .whitespacesAndNewlines),
                        isCredit: false
                    ))
                    continue
                }
            }

            // Try UAE / Standard Purchase match
            if let uaeRegex {
                let matches = uaeRegex.matches(in: block, options: [], range: range)
                for match in matches {
                    guard let currencyRaw = capture(match, 1, in: block),
                          let amountString = capture(match, 2, in: block),
                          let amount = decimal(from: amountString), amount > 0,
                          let cardType = capture(match, 3, in: block),
                          let merchantRaw = capture(match, 5, in: block)
                    else { continue }

                    let merchant = cleanMerchant(merchantRaw)

                    results.append(ParsedSMSTransaction(
                        amount: amount,
                        currency: normalizeCurrency(currencyRaw),
                        merchant: merchant,
                        categoryName: guessCategory(for: merchant).rawValue,
                        date: defaultDate,
                        paymentMethod: cardType.lowercased() == "credit" ? .creditCard : .debitCard,
                        cardLast4: capture(match, 4, in: block),
                        rawText: fullMatch(match, in: block),
                        isCredit: false
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Message Splitting

    /// Splits bulk pastes (including numbered lists like "1. ", "2. ", "3. ") into individual SMS messages.
    private static func splitIntoMessageBlocks(_ rawText: String) -> [String] {
        let text = rawText.replacingOccurrences(of: "\r\n", with: "\n")

        // Strip numbered list markers ("1. ", "2. ", "3. ", "4. ", "5. ") at line starts or word boundaries
        let listPattern = #"(?:^|\n|\s)\d+\.\s*"#
        let unnumbered = text.replacingOccurrences(of: listPattern, with: "\n\n", options: .regularExpression)

        // Split by double newlines first
        let rawBlocks = unnumbered.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var blocks: [String] = []
        let boundaryRegex = try? NSRegularExpression(
            pattern: #"(?=(?:Dear\s+Customer|Txn\s+|Purchase\s+of|INR\s+[\d,]+|Rs\.?\s*[\d,]+|Spent\s+))"#,
            options: [.caseInsensitive]
        )

        for block in rawBlocks {
            if let boundaryRegex {
                let range = NSRange(block.startIndex..<block.endIndex, in: block)
                let matches = boundaryRegex.matches(in: block, options: [], range: range)
                if matches.count > 1 {
                    var lastIndex = block.startIndex
                    for match in matches {
                        if let matchRange = Range(match.range, in: block), matchRange.lowerBound > lastIndex {
                            let sub = String(block[lastIndex..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !sub.isEmpty { blocks.append(sub) }
                            lastIndex = matchRange.lowerBound
                        }
                    }
                    let rem = String(block[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rem.isEmpty { blocks.append(rem) }
                    continue
                }
            }
            blocks.append(block)
        }

        return blocks.isEmpty ? [text] : blocks
    }

    // MARK: - Helpers

    private static func normalizeCurrency(_ raw: String) -> String {
        let upper = raw.uppercased().replacingOccurrences(of: ".", with: "")
        if upper == "RS" || upper == "INR" {
            return "INR"
        }
        return upper
    }

    private static func detectPaymentMethod(in text: String, defaultCredit: Bool) -> PaymentMethod {
        let upper = text.uppercased()
        if upper.contains("UPI") {
            return .upi
        } else if upper.contains("CREDIT") || upper.contains("CC") {
            return .creditCard
        } else if upper.contains("DEBIT") || upper.contains("CARD") {
            return .debitCard
        } else if defaultCredit {
            return .bankTransfer
        }
        return .debitCard
    }

    private static func parseDate(_ dateStr: String?, defaultDate: Date) -> Date {
        guard let dateStr = dateStr?.trimmingCharacters(in: .whitespacesAndNewlines), !dateStr.isEmpty else {
            return defaultDate
        }

        let formats = ["dd-MM-yyyy", "dd/MM/yyyy", "dd-MMM-yy", "dd-MMM-yyyy", "dd/MM/yy", "dd-MM-yy"]
        for format in formats {
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: dateStr) {
                return date
            }
        }

        // Handle short "dd-MM" (e.g., "03-08")
        let shortDf = DateFormatter()
        shortDf.dateFormat = "dd-MM"
        shortDf.locale = Locale(identifier: "en_US_POSIX")
        if let shortDate = shortDf.date(from: dateStr) {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: defaultDate)
            var components = calendar.dateComponents([.day, .month], from: shortDate)
            components.year = year
            if let fullDate = calendar.date(from: components) {
                return fullDate
            }
        }

        return defaultDate
    }

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

    private static func cleanMerchant(_ raw: String) -> String {
        let name = raw.split(separator: ",").first.map(String.init) ?? raw
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let categoryKeywords: [(BuiltInCategory, [String])] = [
        (.coffee, ["COFFEE", "STARBUCKS", "COSTA", "TIM HORTON", "CAFFE", "ARABICA", "BLUE BOTTLE"]),
        (.food, ["REST", "RESTAURANT", "CAFE", "GRILL", "KITCHEN", "SHAWARMA", "BURGER", "PIZZA", "MCDONALD", "KFC", "SUBWAY", "DINING", "SWIGGY", "ZOMATO", "FOOD"]),
        (.grocery, ["CARREFOUR", "LULU", "SUPERMARKET", "GROCERY", "SPINNEYS", "UNION COOP", "WAITROSE", "AL MAYA", "MART", "HYPERMARKET", "ZEPTO", "BLINKIT"]),
        (.fuel, ["ADNOC", "ENOC", "EPPCO", "PETROL", "FUEL"]),
        (.transport, ["CAREEM", "UBER", "RTA", "METRO", "TAXI", "SALIK", "PARKING", "RAPIDO", "NAMASTE"]),
        (.health, ["PHARMACY", "ASTER", "MEDCARE", "CLINIC", "HOSPITAL", "MEDICAL", "APOLLO", "1MG"]),
        (.insurance, ["INSURANCE", "TAKAFUL", "ASSURANCE"]),
        (.subscription, ["NETFLIX", "SPOTIFY", "OSN", "ANGHAMI", "SUBSCRIPTION", "APPLE.COM", "GOOGLE", "YOUTUBE"]),
        (.travel, ["EMIRATES", "FLYDUBAI", "AIR ARABIA", "BOOKING", "AGODA", "HOTEL", "AIRLINE", "AIRWAYS", "IRCTC", "MAKEMYTRIP", "INDIGO"]),
        (.bills, ["DEWA", "SEWA", "ETISALAT", "UTILITY", "AIRTEL", "JIO", "VI"]),
        (.upi, ["UPI", "GPAY", "PHONEPE", "PAYTM", "BHIM", "CRED"]),
        (.shopping, ["NOON", "AMAZON", "NAMSHI", "IKEA", "MALL", "CENTREPOINT", "UNIQLO", "SHARAF", "H&M", "STORE", "FLIPKART", "MYNTRA"]),
    ]

    static func guessCategory(for merchant: String) -> BuiltInCategory {
        let upper = merchant.uppercased()
        for (category, keywords) in categoryKeywords where keywords.contains(where: upper.contains) {
            return category
        }
        return .fallback
    }
}
