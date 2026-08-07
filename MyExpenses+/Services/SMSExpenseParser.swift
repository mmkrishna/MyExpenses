//
//  SMSExpenseParser.swift
//  MyExpenses+
//

import Foundation

// MARK: - Parsed Transaction

/// A transaction extracted from a bank SMS, ready to become an Expense or Income after review.
nonisolated struct ParsedSMSTransaction: Identifiable {
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

// MARK: - Parser

/// Parses bank purchase and credit SMS messages into transaction objects.
///
/// A paste can contain one message or many (numbered lists, WhatsApp/iMessage chat
/// exports, or several bank notifications concatenated with no separator at all), so
/// parsing happens in two stages: `MessageSplitter` first breaks the paste into
/// individual SMS bodies, then each body is handed to `FormatCatalog`, which tries
/// each known bank format in turn until one matches.
nonisolated enum SMSExpenseParser {
    static func parse(_ text: String, date defaultDate: Date = Date()) -> [ParsedSMSTransaction] {
        MessageSplitter.split(text).compactMap { message in
            FormatCatalog.parse(message, defaultDate: defaultDate)
        }
    }

    static func guessCategory(for merchant: String) -> BuiltInCategory {
        MerchantCategorizer.category(for: merchant)
    }
}

// MARK: - Message Splitting

/// Breaks a raw clipboard paste into one string per SMS.
///
/// This runs in two passes:
/// 1. **Envelope splitting** — strips WhatsApp/iMessage chat-export headers and numbered
///    list markers ("1. ", "2. ", ...), which mark real, explicit message boundaries.
///    Everything between two markers stays together as one envelope, including any
///    incidental blank lines inside it (WhatsApp copies often insert one after the
///    first line of a multi-line SMS).
/// 2. **Keyword splitting** — for an envelope that still contains more than one
///    transaction concatenated with no marker at all (e.g. several UAE purchase
///    sentences pasted back to back), looks for the handful of phrases that start a
///    bank SMS ("Txn ", "Purchase of", ...) and splits there instead.
private nonisolated enum MessageSplitter {
    static func split(_ rawText: String) -> [String] {
        let normalized = rawText
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return splitIntoEnvelopes(normalized).flatMap(splitConcatenatedMessages)
    }

    // MARK: Envelope splitting

    /// A character that never appears in bank SMS text, used to mark confirmed
    /// message boundaries without disturbing blank lines that are part of a message.
    private static let boundary = "\u{1E}"

    /// "[03/08/2026, 6:32:56 PM] Kapil: " — WhatsApp/iMessage chat export header.
    /// Deliberately unanchored: a numbered marker ("1. ") is often glued directly in
    /// front of it, so requiring start-of-line here would miss that combination.
    private static let chatBracketHeaderRegex = try? NSRegularExpression(
        pattern: #"\[\d{1,2}/\d{1,2}/\d{2,4},?\s*\d{1,2}:\d{2}(?::\d{2})?\s*(?:[AP]M)?\]\s*[^:\n]*:\s*"#,
        options: [.caseInsensitive]
    )

    /// "03/08/2026, 6:32 PM - Kapil: " — the alternate iOS-style export header.
    private static let chatDashHeaderRegex = try? NSRegularExpression(
        pattern: #"\d{1,2}/\d{1,2}/\d{2,4},?\s*\d{1,2}:\d{2}\s*(?:[AP]M)?\s*-\s*[^:\n]*:\s*"#,
        options: [.caseInsensitive]
    )

    /// "1. ", "2. " — a list marker. Only recognized at the very start of the paste,
    /// right after a newline, or right after a previous sentence ends ("...Bank. 2.
    /// Txn..."). Never after a bare space — otherwise "Rs 2480.00" or "INR 20019.64"
    /// would be misread as list item "2480." or "20019.", corrupting the amount.
    private static let numberedMarkerRegex = try? NSRegularExpression(
        pattern: #"(?<=^|\n|\. )\d{1,3}\.\s+"#,
        options: [.caseInsensitive]
    )

    private static func splitIntoEnvelopes(_ text: String) -> [String] {
        var result = text
        for regex in [chatBracketHeaderRegex, chatDashHeaderRegex, numberedMarkerRegex] {
            guard let regex else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: boundary)
        }

        let envelopes = result.components(separatedBy: boundary)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return envelopes.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : envelopes
    }

    // MARK: Keyword splitting

    /// Phrases that open a bank SMS. Used only as a lookahead to find where one
    /// transaction ends and the next begins inside an envelope that has no explicit
    /// marker of its own. Deliberately narrow: a bare "INR 123.45" is *not* included,
    /// since that also matches secondary mentions like "Avl Lmt: INR 104,421.60" and
    /// would fracture a single message into unparsable pieces.
    private static let messageStartRegex = try? NSRegularExpression(
        pattern: #"(?:^|\n|\.\s+)(Dear\s+Customer\b|Txn\s|Purchase\s+of\b|Payment\s+of\b|Credit\s+Card\s+Purchase\b|Debit\s+Card\s+Purchase\b|Card\s+Purchase\b|(?:A\s+)?(?:Cr\.?|Dr\.?)\s+(?:trx|txn|transaction)\b|(?:[A-Za-z]{3}|Rs\.?|INR)\s*[\d,]+(?:\.\d{1,2})?\s+transferred\b|Your\s+(?:Cr\.?|Credit|Debit)?\s*Card\b|(?:Trx\.?|Txn\.?|Transaction)\s+of\b|Spent\s+(?:INR|Rs\.?|[A-Za-z]{3})\b|(?:INR|Rs\.?)\s*[\d,]+(?:\.\d{1,2})?\s+spent\b)"#,
        options: [.caseInsensitive]
    )

    private static func splitConcatenatedMessages(_ envelope: String) -> [String] {
        guard let messageStartRegex else { return [envelope] }

        let range = NSRange(envelope.startIndex..<envelope.endIndex, in: envelope)
        let matches = messageStartRegex.matches(in: envelope, range: range)

        guard !matches.isEmpty else { return [envelope] }

        var starts: [String.Index] = []
        for match in matches {
            if match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: envelope) {
                starts.append(r.lowerBound)
            } else if let r = Range(match.range(at: 0), in: envelope) {
                starts.append(r.lowerBound)
            }
        }

        if starts.first != envelope.startIndex {
            starts.insert(envelope.startIndex, at: 0)
        }

        var pieces: [String] = []
        for (index, start) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1] : envelope.endIndex
            let piece = String(envelope[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { pieces.append(piece) }
        }
        return pieces
    }
}

// MARK: - Format Catalog

/// Every supported bank SMS format, tried in order against a single, already-isolated
/// message. The first one that matches wins. To support a new bank, add a case here.
private nonisolated enum FormatCatalog {
    static let all: [(String, Date) -> ParsedSMSTransaction?] = [
        IndianCreditFormat.parse,
        SBISpentFormat.parse,
        IndusIndSpentFormat.parse,
        AxisSpentFormat.parse,
        TxnDebitFormat.parse,
        UAEPurchaseFormat.parse,
        KeyValuePurchaseFormat.parse,
        AccountCrDrFormat.parse,
        BankTransferFormat.parse,
        CardUsedFormat.parse,
        TrxApprovedFormat.parse,
    ]

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        for format in all {
            if let transaction = format(message, defaultDate) {
                return transaction
            }
        }
        return nil
    }
}

// MARK: - Indian Bank Credit
// "Dear Customer, Acct XX051 is credited with Rs 2480.00 on 01-Aug-26 from SHYAM SUNDER
// KU. UPI:490897397234-ICICI Bank."
// "Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE;
// UPI:227178662096; Bal INR 131.80-CanaraBank"
private nonisolated enum IndianCreditFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"(?:Acct|A/c)\s+([A-Za-z0-9_]+)?\s*(?:is\s+)?credited\s+with\s+(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)(?:\s+on\s+([^\s;\.,]+))?\s+from\s+([^;\.\r\n]+)"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 3, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let cardLast4 = ParsingHelpers.capture(match, 1, in: message)?
            .replacingOccurrences(of: "X", with: "", options: .caseInsensitive)
        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 2, in: message) ?? "INR")
        let dateString = ParsingHelpers.capture(match, 4, in: message)
        let payer = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 5, in: message) ?? "Income")

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: payer,
            categoryName: MerchantCategorizer.category(for: payer).rawValue,
            date: ParsingHelpers.parseDate(dateString, defaultDate: defaultDate),
            paymentMethod: ParsingHelpers.detectPaymentMethod(in: message, defaultCredit: true),
            cardLast4: cardLast4.flatMap { $0.isEmpty ? nil : $0 },
            rawText: message,
            isCredit: true
        )
    }
}

// MARK: - SBI / "Spent at ... on ..." (amount leads, date trails)
// "Rs.653.95 spent on your SBI Credit Card ending 3140 at BIGBASKET on 09/07/26."
private nonisolated enum SBISpentFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)\s+spent\s+on\s+(?:your\s+)?([A-Za-z0-9_\s]*?Card\s*(?:XX|ending|no\.?)?\s*(\d{3,4}))?\s+at\s+([^\.\n;\r]+?)\s+on\s+(\d{2}[-\/]\d{2}[-\/]\d{2,4}|\d{2}[-\/][A-Za-z]{3}[-\/]\d{2,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 5, in: message) ?? "Merchant")

        return ParsedSMSTransaction(
            amount: amount,
            currency: ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "INR"),
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: ParsingHelpers.parseDate(ParsingHelpers.capture(match, 6, in: message), defaultDate: defaultDate),
            paymentMethod: ParsingHelpers.detectPaymentMethod(in: message, defaultCredit: false),
            cardLast4: ParsingHelpers.extractCardLast4(from: ParsingHelpers.capture(match, 4, in: message)),
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - IndusInd / "<amount> spent on ... at ..." (amount leads, date mid-message)
// "INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD
// FOOD2. Avl Lmt: INR 104,421.60."
private nonisolated enum IndusIndSpentFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)\s+spent\s+on\s+(?:your\s+)?([A-Za-z0-9_\s]*?Card\s*(?:XX|ending|no\.?)?\s*(\d{3,4}))?(?:[\s\S]*?)(?:on\s+(\d{2}[-\/]\d{2}[-\/]\d{2,4}|\d{2}[-\/][A-Za-z]{3}[-\/]\d{2,4}))?(?:[\s\S]*?)at\s+([^;\.\r\n]+)"#,
        options: [.caseInsensitive]
    )
    private static let inlineDateRegex = try? NSRegularExpression(
        pattern: #"\bon\s+(\d{2}[-\/]\d{2}[-\/]\d{2,4}|\d{2}[-\/][A-Za-z]{3}[-\/]\d{2,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 6, in: message) ?? "Merchant")

        var date = defaultDate
        if let inlineDateRegex, let dateMatch = ParsingHelpers.firstMatch(inlineDateRegex, in: message),
           let dateString = ParsingHelpers.capture(dateMatch, 1, in: message) {
            date = ParsingHelpers.parseDate(dateString, defaultDate: defaultDate)
        }

        return ParsedSMSTransaction(
            amount: amount,
            currency: ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "INR"),
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: date,
            paymentMethod: ParsingHelpers.detectPaymentMethod(in: message, defaultCredit: false),
            cardLast4: ParsingHelpers.extractCardLast4(from: ParsingHelpers.capture(match, 3, in: message)),
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Axis / multi-line "Spent <amount>"
// "Spent INR 20019.64\nAxis Bank Card no. XX9854\n04-07-26 13:36:19 IST\nAMAZON PAY\nAvl
// Limit: INR 181980.36"
private nonisolated enum AxisSpentFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"Spent\s+(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)(?:[\s\S]*?)(?:Card(?:\s*no\.?)?\s*(?:XX|ending)?\s*(\d{3,4}))?(?:[\s\S]*?)(\d{2}[-\/]\d{2}[-\/]\d{2,4})(?:[\s\S]*?)\n([A-Z0-9\s]+?)(?:\n|\r|Avl|Not|To|\.|$)"#,
        options: [.caseInsensitive]
    )
    private static let cardDigitsRegex = try? NSRegularExpression(
        pattern: #"Card(?:\s*no\.?)?\s*(?:XX|ending)?\s*(\d{3,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 5, in: message) ?? "Merchant")

        var cardLast4: String?
        if let cardDigitsRegex, let cardMatch = ParsingHelpers.firstMatch(cardDigitsRegex, in: message) {
            cardLast4 = ParsingHelpers.capture(cardMatch, 1, in: message)
        }

        return ParsedSMSTransaction(
            amount: amount,
            currency: ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "INR"),
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: ParsingHelpers.parseDate(ParsingHelpers.capture(match, 4, in: message), defaultDate: defaultDate),
            paymentMethod: ParsingHelpers.detectPaymentMethod(in: message, defaultCredit: false),
            cardLast4: cardLast4,
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Indian Txn / Debit (HDFC-style)
// "Txn Rs.149.00\nOn HDFC Bank Card 5865\nAt returnswealth710648.rzp@r \nby UPI
// 658121756648\nOn 03-08"
private nonisolated enum TxnDebitFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"Txn\s+(Rs\.?|INR|[A-Za-z]{3})\s*([\d,]+(?:\.\d{1,2})?)(?:[\s\S]*?)(?:Card\s+(\d{3,4}))?(?:[\s\S]*?)At\s+([^\n;\r]+)"#,
        options: [.caseInsensitive]
    )
    private static let inlineDateRegex = try? NSRegularExpression(
        pattern: #"On\s+(\d{2}[-\/]\d{2}(?:[-\/]\d{2,4})?)"#,
        options: [.caseInsensitive]
    )
    private static let cardDigitsRegex = try? NSRegularExpression(
        pattern: #"Card\s+(\d{3,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 4, in: message) ?? "Merchant")

        var date = defaultDate
        if let inlineDateRegex, let dateMatch = ParsingHelpers.firstMatch(inlineDateRegex, in: message),
           let dateString = ParsingHelpers.capture(dateMatch, 1, in: message) {
            date = ParsingHelpers.parseDate(dateString, defaultDate: defaultDate)
        }

        var cardLast4: String?
        if let cardDigitsRegex, let cardMatch = ParsingHelpers.firstMatch(cardDigitsRegex, in: message) {
            cardLast4 = ParsingHelpers.capture(cardMatch, 1, in: message)
        }

        return ParsedSMSTransaction(
            amount: amount,
            currency: ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "INR"),
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: date,
            paymentMethod: ParsingHelpers.detectPaymentMethod(in: message, defaultCredit: false),
            cardLast4: cardLast4,
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - UAE / Standard Purchase or Payment
// "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30."
// "Payment of AED 37.99 to Noon Minutes with Credit Card ending 8220. Avl Cr. Limit is AED 1,030.80."
private nonisolated enum UAEPurchaseFormat {
    private static let cardFirstRegex = try? NSRegularExpression(
        pattern: #"(?:Purchase|Payment)\s+of\s+([A-Za-z]{3})\s+([\d,]+(?:\.\d{1,2})?)\s+with\s+(Debit|Credit)?\s*Card(?:\s+ending\s+(\d{3,4}))?\s+(?:at|to)\s+(.+?)(?:\.\s*Avl\b|\.\s*Available\b|\.\s*$|$)"#,
        options: [.caseInsensitive]
    )

    private static let merchantFirstRegex = try? NSRegularExpression(
        pattern: #"(?:Purchase|Payment)\s+of\s+([A-Za-z]{3})\s+([\d,]+(?:\.\d{1,2})?)\s+(?:at|to)\s+(.+?)\s+with\s+(Debit|Credit)?\s*Card(?:\s+ending\s+(\d{3,4}))?(?:\.\s*Avl\b|\.\s*Available\b|\.\s*$|$)"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        if let regex = cardFirstRegex, let match = ParsingHelpers.firstMatch(regex, in: message),
           let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
           amount > 0 {
            let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "AED")
            let cardType = ParsingHelpers.capture(match, 3, in: message) ?? "Card"
            let cardLast4 = ParsingHelpers.capture(match, 4, in: message)
            let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 5, in: message) ?? "Merchant")
            let paymentMethod: PaymentMethod = cardType.lowercased() == "debit" ? .debitCard : .creditCard

            return ParsedSMSTransaction(
                amount: amount,
                currency: currency,
                merchant: merchant,
                categoryName: MerchantCategorizer.category(for: merchant).rawValue,
                date: defaultDate,
                paymentMethod: paymentMethod,
                cardLast4: cardLast4,
                rawText: message,
                isCredit: false
            )
        }

        if let regex = merchantFirstRegex, let match = ParsingHelpers.firstMatch(regex, in: message),
           let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
           amount > 0 {
            let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "AED")
            let merchant = ParsingHelpers.cleanMerchant(ParsingHelpers.capture(match, 3, in: message) ?? "Merchant")
            let cardType = ParsingHelpers.capture(match, 4, in: message) ?? "Card"
            let cardLast4 = ParsingHelpers.capture(match, 5, in: message)
            let paymentMethod: PaymentMethod = cardType.lowercased() == "debit" ? .debitCard : .creditCard

            return ParsedSMSTransaction(
                amount: amount,
                currency: currency,
                merchant: merchant,
                categoryName: MerchantCategorizer.category(for: merchant).rawValue,
                date: defaultDate,
                paymentMethod: paymentMethod,
                cardLast4: cardLast4,
                rawText: message,
                isCredit: false
            )
        }


        return nil
    }
}


// MARK: - Key-Value Purchase
// "Credit Card Purchase\nCard Ending: 1013\nAt: HOOKAH PANI STAR CAFE, DUBAI\nAmount: AED 110.00\nDate: 02/08/2026, 22:54\nAvailable Limit: AED 17,899.46"
private nonisolated enum KeyValuePurchaseFormat {
    private static let amountRegex = try? NSRegularExpression(
        pattern: #"Amount:\s*([A-Za-z]{3}|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)"#,
        options: [.caseInsensitive]
    )
    private static let merchantRegex = try? NSRegularExpression(
        pattern: #"At:\s*([^\n\r]+)"#,
        options: [.caseInsensitive]
    )
    private static let cardEndingRegex = try? NSRegularExpression(
        pattern: #"Card\s+Ending:\s*([A-Za-z0-9\*]+)"#,
        options: [.caseInsensitive]
    )
    private static let dateRegex = try? NSRegularExpression(
        pattern: #"Date:\s*([^\n\r]+)"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard message.localizedCaseInsensitiveContains("Card Purchase") || message.localizedCaseInsensitiveContains("Amount:"),
              let amountRegex, let amountMatch = ParsingHelpers.firstMatch(amountRegex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(amountMatch, 2, in: message) ?? "0"),
              amount > 0,
              let merchantRegex, let merchantMatch = ParsingHelpers.firstMatch(merchantRegex, in: message)
        else { return nil }

        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(amountMatch, 1, in: message) ?? "AED")
        let rawMerchant = ParsingHelpers.capture(merchantMatch, 1, in: message) ?? "Merchant"
        let merchant = ParsingHelpers.cleanMerchant(rawMerchant)

        var cardLast4: String?
        if let cardEndingRegex, let cardMatch = ParsingHelpers.firstMatch(cardEndingRegex, in: message) {
            cardLast4 = ParsingHelpers.extractCardLast4(from: ParsingHelpers.capture(cardMatch, 1, in: message))
        }

        var date = defaultDate
        if let dateRegex, let dateMatch = ParsingHelpers.firstMatch(dateRegex, in: message),
           let dateStr = ParsingHelpers.capture(dateMatch, 1, in: message) {
            date = ParsingHelpers.parseDate(dateStr, defaultDate: defaultDate)
        }

        let isCreditCard = message.localizedCaseInsensitiveContains("Credit")

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: date,
            paymentMethod: isCreditCard ? .creditCard : .debitCard,
            cardLast4: cardLast4,
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Account Cr/Dr Transaction
// "A Cr. transaction of AED 37.25 on your account number XXX820001 was successful.Available balance is 2970.45."
// "A Dr. transaction of AED 200.00 on your account number XXX820001 was successful.Available balance is 2770.45."
private nonisolated enum AccountCrDrFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"(?:A\s+)?(Cr\.?|Dr\.?|Credit|Debit)\s+(?:trx|txn|transaction)\s+of\s+([A-Za-z]{3}|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+on\s+(?:your\s+)?(?:account|acc\.?|a/c)\s*(?:number|no\.?)?\s*([A-Za-z0-9_\*]+)"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let typeStr = ParsingHelpers.capture(match, 1, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 3, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let isCredit = typeStr.localizedCaseInsensitiveContains("Cr") || typeStr.localizedCaseInsensitiveContains("Credit")
        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 2, in: message) ?? "AED")
        let accNumber = ParsingHelpers.capture(match, 4, in: message)
        let merchant = isCredit ? "Account Credit" : "Account Debit"

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: defaultDate,
            paymentMethod: .bankTransfer,
            cardLast4: ParsingHelpers.extractCardLast4(from: accNumber),
            rawText: message,
            isCredit: isCredit
        )
    }
}

// MARK: - Bank Transfer (ADCB style)
// "AED850.00 transferred via ADCB Personal Internet Banking / Mobile App from acc. no. XXX820001 on Aug  4 2026  7:52AM. Avl. bal. AED 2933.20."
private nonisolated enum BankTransferFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"([A-Za-z]{3}|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+transferred\s+via\s+([^\n\r]+?)\s+from\s+acc\.\s*no\.\s*([A-Za-z0-9_\*]+)(?:\s+on\s+([^\.\n;\r]+))?"#,
        options: [.caseInsensitive]
    )
    private static let dateExtractRegex = try? NSRegularExpression(
        pattern: #"([A-Za-z]{3}\s+\d{1,2}\s+\d{4}|\d{2}[-\/]\d{2}[-\/]\d{2,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "AED")
        let rawMerchant = ParsingHelpers.capture(match, 3, in: message) ?? "Bank Transfer"
        let merchant = ParsingHelpers.cleanMerchant(rawMerchant)
        let accNumber = ParsingHelpers.capture(match, 4, in: message)

        var date = defaultDate
        if let rawDateStr = ParsingHelpers.capture(match, 5, in: message) {
            if let dateExtractRegex, let dateMatch = ParsingHelpers.firstMatch(dateExtractRegex, in: rawDateStr),
               let extractedDateStr = ParsingHelpers.capture(dateMatch, 1, in: rawDateStr) {
                date = ParsingHelpers.parseDate(extractedDateStr, defaultDate: defaultDate)
            } else {
                date = ParsingHelpers.parseDate(rawDateStr, defaultDate: defaultDate)
            }
        }

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: date,
            paymentMethod: .bankTransfer,
            cardLast4: ParsingHelpers.extractCardLast4(from: accNumber),
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Card Used Format
// "Your Cr.Card XXX6212 was used for AED2942.00 on 03/08/2026 10:16:47 at ZURICH INTL. LIFE LT,DUBAI-AE. Avl. Cr.limit is AED5783.69"
private nonisolated enum CardUsedFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"Your\s+(?:Cr\.?\s*)?Card\s+([A-Za-z0-9_\*]+)\s+was\s+used\s+for\s+([A-Za-z]{3}|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)(?:\s+on\s+(\d{2}[-\/]\d{2}[-\/]\d{2,4}(?:\s+\d{2}:\d{2}:\d{2})?))?\s+at\s+([^;\.\r\n]+)"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 3, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let cardStr = ParsingHelpers.capture(match, 1, in: message)
        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 2, in: message) ?? "AED")
        let dateStr = ParsingHelpers.capture(match, 4, in: message)
        let rawMerchant = ParsingHelpers.capture(match, 5, in: message) ?? "Merchant"
        let merchant = ParsingHelpers.cleanMerchant(rawMerchant)

        let isCreditCard = message.localizedCaseInsensitiveContains("Cr")

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: ParsingHelpers.parseDate(dateStr, defaultDate: defaultDate),
            paymentMethod: isCreditCard ? .creditCard : .debitCard,
            cardLast4: ParsingHelpers.extractCardLast4(from: cardStr),
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Trx Approved Format
// "Trx. of AED80.00 on your card ending *429 at SWABI LAUNDRY L.L.C, UAE is Approved. Avl. card bal is 19502.90. Trx Date: 04/08/26 16:45"
private nonisolated enum TrxApprovedFormat {
    private static let regex = try? NSRegularExpression(
        pattern: #"(?:Trx\.?|Txn\.?|Transaction)\s+of\s+([A-Za-z]{3}|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+on\s+(?:your\s+)?card(?:\s+ending)?\s*([A-Za-z0-9_\*]+)?\s+at\s+(.+?)\s+(?:is|was)\s+Approved"#,
        options: [.caseInsensitive]
    )
    private static let dateRegex = try? NSRegularExpression(
        pattern: #"(?:Trx\s+Date|Date):\s*(\d{2}[-\/]\d{2}[-\/]\d{2,4})"#,
        options: [.caseInsensitive]
    )

    static func parse(_ message: String, defaultDate: Date) -> ParsedSMSTransaction? {
        guard let regex, let match = ParsingHelpers.firstMatch(regex, in: message),
              let amount = ParsingHelpers.decimal(from: ParsingHelpers.capture(match, 2, in: message) ?? "0"),
              amount > 0
        else { return nil }

        let currency = ParsingHelpers.normalizeCurrency(ParsingHelpers.capture(match, 1, in: message) ?? "AED")
        let cardStr = ParsingHelpers.capture(match, 3, in: message)
        let rawMerchant = ParsingHelpers.capture(match, 4, in: message) ?? "Merchant"
        let merchant = ParsingHelpers.cleanMerchant(rawMerchant)

        var date = defaultDate
        if let dateRegex, let dateMatch = ParsingHelpers.firstMatch(dateRegex, in: message),
           let dateStr = ParsingHelpers.capture(dateMatch, 1, in: message) {
            date = ParsingHelpers.parseDate(dateStr, defaultDate: defaultDate)
        }

        let isCreditCard = message.localizedCaseInsensitiveContains("Credit")

        return ParsedSMSTransaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            categoryName: MerchantCategorizer.category(for: merchant).rawValue,
            date: date,
            paymentMethod: isCreditCard ? .creditCard : .debitCard,
            cardLast4: ParsingHelpers.extractCardLast4(from: cardStr),
            rawText: message,
            isCredit: false
        )
    }
}

// MARK: - Shared Parsing Helpers

private nonisolated enum ParsingHelpers {
    static func firstMatch(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func decimal(from string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ",", with: ""))
    }

    /// Merchant fields often trail into a second field ("Noon, 80038888"); only the
    /// part before the comma is the actual merchant name.
    static func cleanMerchant(_ raw: String) -> String {
        let name = raw.split(separator: ",").first.map(String.init) ?? raw
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeCurrency(_ raw: String) -> String {
        let upper = raw.uppercased().replacingOccurrences(of: ".", with: "")
        return (upper == "RS" || upper == "INR") ? "INR" : upper
    }

    static func extractCardLast4(from text: String?) -> String? {
        guard let text else { return nil }
        let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digits.count >= 4 { return String(digits.suffix(4)) }
        return digits.isEmpty ? nil : digits
    }

    static func detectPaymentMethod(in text: String, defaultCredit: Bool) -> PaymentMethod {
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

    private static let dateFormats = [
        "dd-MM-yyyy", "dd/MM/yyyy", "dd-MM-yy", "dd/MM/yy", "dd-MMM-yy", "dd-MMM-yyyy",
        "MMM d yyyy", "MMM dd yyyy", "dd MMM yyyy",
        "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm", "dd/MM/yy HH:mm:ss", "dd/MM/yy HH:mm",
        "dd-MM-yyyy HH:mm:ss", "dd-MM-yyyy HH:mm", "dd-MM-yy HH:mm:ss", "dd-MM-yy HH:mm",
        "MMM d yyyy h:mma", "MMM d yyyy h:mm a", "MMM d yyyy HH:mm", "MMM dd yyyy h:mma", "MMM dd yyyy h:mm a", "MMM dd yyyy HH:mm"
    ]

    static func parseDate(_ dateStr: String?, defaultDate: Date) -> Date {
        guard let dateStr = dateStr?.trimmingCharacters(in: .whitespacesAndNewlines), !dateStr.isEmpty else {
            return defaultDate
        }

        let cleaned = dateStr.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: ",", with: "")

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: cleaned),
               Calendar.current.component(.year, from: date) >= 1900 {
                return date
            }
        }

        // Short "dd-MM" (e.g. "03-08") carries no year, so borrow the default date's.
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "dd-MM"
        shortFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let shortDate = shortFormatter.date(from: cleaned) else { return defaultDate }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.day, .month], from: shortDate)
        components.year = calendar.component(.year, from: defaultDate)
        return components.year.flatMap { _ in calendar.date(from: components) } ?? defaultDate
    }
}

// MARK: - Merchant Categorization

private nonisolated enum MerchantCategorizer {
    private static let keywordsByCategory: [(BuiltInCategory, [String])] = [
        (.coffee, ["COFFEE", "STARBUCKS", "COSTA", "TIM HORTON", "CAFFE", "ARABICA", "BLUE BOTTLE"]),
        (.food, ["REST", "RESTAURANT", "CAFE", "GRILL", "KITCHEN", "SHAWARMA", "BURGER", "PIZZA", "MCDONALD", "KFC", "SUBWAY", "DINING", "SWIGGY", "ZOMATO", "FOOD"]),
        (.grocery, ["CARREFOUR", "LULU", "SUPERMARKET", "GROCERY", "SPINNEYS", "UNION COOP", "WAITROSE", "AL MAYA", "MART", "HYPERMARKET", "ZEPTO", "BLINKIT", "BIGBASKET", "GROFERS"]),
        (.fuel, ["ADNOC", "ENOC", "EPPCO", "PETROL", "FUEL"]),
        (.transport, ["CAREEM", "UBER", "RTA", "METRO", "TAXI", "SALIK", "PARKING", "RAPIDO", "NAMASTE"]),
        (.health, ["PHARMACY", "ASTER", "MEDCARE", "CLINIC", "HOSPITAL", "MEDICAL", "APOLLO", "1MG"]),
        (.insurance, ["INSURANCE", "TAKAFUL", "ASSURANCE", "ZURICH", "LIFE LT"]),
        (.subscription, ["NETFLIX", "SPOTIFY", "OSN", "ANGHAMI", "SUBSCRIPTION", "APPLE.COM", "GOOGLE", "YOUTUBE"]),
        (.travel, ["EMIRATES", "FLYDUBAI", "AIR ARABIA", "BOOKING", "AGODA", "HOTEL", "AIRLINE", "AIRWAYS", "IRCTC", "MAKEMYTRIP", "INDIGO"]),
        (.bills, ["DEWA", "SEWA", "ETISALAT", "UTILITY", "AIRTEL", "JIO", "VI", "LAUNDRY", "CLEANING"]),
        (.upi, ["UPI", "GPAY", "PHONEPE", "PAYTM", "BHIM", "CRED"]),
        (.shopping, ["NOON", "AMAZON", "NAMSHI", "IKEA", "MALL", "CENTREPOINT", "UNIQLO", "SHARAF", "H&M", "STORE", "FLIPKART", "MYNTRA"]),
    ]

    static func category(for merchant: String) -> BuiltInCategory {
        let upper = merchant.uppercased()
        for (category, keywords) in keywordsByCategory where keywords.contains(where: upper.contains) {
            return category
        }
        return .fallback
    }
}
