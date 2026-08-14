//
//  SMSExpenseParserTests.swift
//  MyExpenses+Tests
//

import Foundation
import Testing
@testable import MyExpenses_

@MainActor
struct SMSExpenseParserTests {

    @Test func parsesSingleTransaction() {
        let sms = "Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30."
        let result = SMSExpenseParser.parse(sms)

        #expect(result.count == 1)
        let tx = try! #require(result.first)
        #expect(tx.amount == Decimal(string: "42.93"))
        #expect(tx.currency == "AED")
        #expect(tx.merchant == "Noon")
        #expect(tx.paymentMethod == .debitCard)
        #expect(tx.cardLast4 == "0807")
        #expect(tx.categoryName == "Shopping")
    }

    @Test func parsesMultipleTransactionsInOneBlob() {
        let sms = """
        Purchase of AED 42.93 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,407.30. \
        Purchase of AED 20.00 with Debit Card ending 0807 at SOCIAL HUB FZCO, DUBAI. Avl Balance is AED 2,832.34. \
        Purchase of AED 25.40 with Debit Card ending 0807 at Noon, 80038888. Avl Balance is AED 2,852.34. \
        Purchase of AED 14.00 with Debit Card ending 0807 at AL JEERAN REST LLC, SHARJAH. Avl Balance is AED 3,032.10.
        """
        let result = SMSExpenseParser.parse(sms)

        #expect(result.count == 4)

        #expect(result[0].amount == Decimal(string: "42.93"))
        #expect(result[0].merchant == "Noon")
        #expect(result[0].categoryName == "Shopping")

        #expect(result[1].amount == Decimal(string: "20.00"))
        #expect(result[1].merchant == "SOCIAL HUB FZCO")
        #expect(result[1].categoryName == "Other")

        #expect(result[2].amount == Decimal(string: "25.40"))
        #expect(result[2].merchant == "Noon")

        #expect(result[3].amount == Decimal(string: "14.00"))
        #expect(result[3].merchant == "AL JEERAN REST LLC")
        #expect(result[3].categoryName == "Food") // "REST" keyword
    }

    @Test func everyTransactionUsesDebitCard() {
        let sms = "Purchase of AED 14.00 with Debit Card ending 0807 at AL JEERAN REST LLC, SHARJAH. Avl Balance is AED 3,032.10."
        let result = SMSExpenseParser.parse(sms)
        #expect(result.allSatisfy { $0.paymentMethod == .debitCard })
        #expect(result.first?.cardLast4 == "0807")
    }

    @Test func ignoresNonPurchaseText() {
        let sms = "Your OTP is 123456. Do not share it with anyone."
        #expect(SMSExpenseParser.parse(sms).isEmpty)
    }

    @Test func parsesCreditCardAndCommaAmount() {
        let sms = "Purchase of AED 1,250.00 with Credit Card ending 1234 at EMIRATES, DUBAI. Avl Balance is AED 5,000.00."
        let result = SMSExpenseParser.parse(sms)
        let tx = try! #require(result.first)
        #expect(tx.amount == Decimal(string: "1250.00"))
        #expect(tx.paymentMethod == .creditCard)
        #expect(tx.categoryName == "Travel")
    }

    @Test func parsesIndianBankCreditSMS() {
        let sms1 = "Dear Customer, Acct XX051 is credited with Rs 2480.00 on 01-Aug-26 from SHYAM SUNDER KU. UPI:490897397234-ICICI Bank."
        let res1 = SMSExpenseParser.parse(sms1)
        let tx1 = try! #require(res1.first)
        #expect(tx1.amount == Decimal(string: "2480.00"))
        #expect(tx1.currency == "INR")
        #expect(tx1.merchant == "SHYAM SUNDER KU")
        #expect(tx1.paymentMethod == .upi)
        #expect(tx1.isCredit == true)

        let sms2 = "Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank"
        let res2 = SMSExpenseParser.parse(sms2)
        let tx2 = try! #require(res2.first)
        #expect(tx2.amount == Decimal(string: "80.00"))
        #expect(tx2.currency == "INR")
        #expect(tx2.merchant == "PHONEPE")
        #expect(tx2.paymentMethod == .upi)
        #expect(tx2.isCredit == true)
    }

    @Test func parsesFiveMessageNumberedBatch() {
        let smsBatch = """
        1. Dear Customer, Acct XX051 is credited with Rs 2480.00 on 01-Aug-26 from SHYAM SUNDER KU. UPI:490897397234-ICICI Bank. 2. Txn Rs.149.00
        On HDFC Bank Card 5865
        At returnswealth710648.rzp@r 
        by UPI 658121756648
        On 03-08
        Not You?
        Call 18002586161/SMS BLOCK CC 5865 to 7308080808
        3. Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank
        4. Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank
        5. Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank
        """

        let result = SMSExpenseParser.parse(smsBatch)

        #expect(result.count == 5)

        #expect(result[0].amount == Decimal(string: "2480.00"))
        #expect(result[0].isCredit == true)

        #expect(result[1].amount == Decimal(string: "149.00"))
        #expect(result[1].merchant == "returnswealth710648.rzp@r")
        #expect(result[1].isCredit == false)

        #expect(result[2].amount == Decimal(string: "80.00"))
        #expect(result[2].isCredit == true)

        #expect(result[3].amount == Decimal(string: "80.00"))
        #expect(result[3].isCredit == true)

        #expect(result[4].amount == Decimal(string: "80.00"))
        #expect(result[4].isCredit == true)
    }

    @Test func parsesWhatsAppExportPasteWithFiveMessages() {
        let whatsappPaste = """
        [03/08/2026, 6:32:56 PM] Kapil: Txn Rs.149.00
        On HDFC Bank Card 5865
        At returnswealth710648.rzp@r 
        by UPI 658121756648
        On 03-08
        Not You?
        Call 18002586161/SMS BLOCK CC 5865 to 7308080808
        [03/08/2026, 6:33:19 PM] Kapil: INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60. To dispute, call 18602677777/SMS BLOCK 8022 to 5676757
        [03/08/2026, 6:34:02 PM] Kapil: Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank
        [03/08/2026, 6:35:18 PM] Kapil: Spent INR 20019.64
        Axis Bank Card no. XX9854
        04-07-26 13:36:19 IST
        AMAZON PAY
        Avl Limit: INR 181980.36
        Not you? SMS BLOCK 9854 to 919951860002
        [03/08/2026, 6:35:45 PM] Kapil: Rs.653.95 spent on your SBI Credit Card ending 3140 at BIGBASKET on 09/07/26. Trxn. not done by you? Report at https://sbicard.com/Dispute
        """

        let result = SMSExpenseParser.parse(whatsappPaste)

        #expect(result.count == 5)

        #expect(result[0].amount == Decimal(string: "149.00"))
        #expect(result[0].merchant == "returnswealth710648.rzp@r")
        #expect(result[0].isCredit == false)

        #expect(result[1].amount == Decimal(string: "272.00"))
        #expect(result[1].merchant == "SWIGGY PVT LTD FOOD2")
        #expect(result[1].categoryName == "Food")
        #expect(result[1].isCredit == false)

        #expect(result[2].amount == Decimal(string: "80.00"))
        #expect(result[2].merchant == "PHONEPE")
        #expect(result[2].isCredit == true)

        #expect(result[3].amount == Decimal(string: "20019.64"))
        #expect(result[3].merchant == "AMAZON PAY")
        #expect(result[3].categoryName == "Shopping")
        #expect(result[3].isCredit == false)

        #expect(result[4].amount == Decimal(string: "653.95"))
        #expect(result[4].merchant == "BIGBASKET")
        #expect(result[4].categoryName == "Grocery")
        #expect(result[4].isCredit == false)
    }

    /// Numbered markers combined with WhatsApp headers, plus a blank line inside a
    /// multi-line message (WhatsApp sometimes inserts one after the first line) —
    /// this exact paste used to return zero transactions.
    @Test func parsesNumberedWhatsAppExportWithBlankLinesInsideMessages() {
        let paste = """
        1. [03/08/2026, 6:32:56 PM] Kapil: Txn Rs.149.00

        On HDFC Bank Card 5865
        At returnswealth710648.rzp@r
        by UPI 658121756648
        On 03-08
        Not You?
        Call 18002586161/SMS BLOCK CC 5865 to 7308080808

        2. [03/08/2026, 6:33:19 PM] Kapil: INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60. To dispute, call 18602677777/SMS BLOCK 8022 to 5676757
        3. [03/08/2026, 6:34:02 PM] Kapil: Dear Customer, Acct XXXXX71966 credited with INR 80.00 on 28/07/26 from PHONEPE; UPI:227178662096; Bal INR 131.80-CanaraBank
        4. [03/08/2026, 6:35:18 PM] Kapil: Spent INR 20019.64

        Axis Bank Card no. XX9854
        04-07-26 13:36:19 IST
        AMAZON PAY
        Avl Limit: INR 181980.36
        Not you? SMS BLOCK 9854 to 919951860002

        5. [03/08/2026, 6:35:45 PM] Kapil: Rs.653.95 spent on your SBI Credit Card ending 3140 at BIGBASKET on 09/07/26. Trxn. not done by you? Report at https://sbicard.com/Dispute
        """

        let result = SMSExpenseParser.parse(paste)

        #expect(result.count == 5)
        #expect(result[0].merchant == "returnswealth710648.rzp@r")
        #expect(result[1].merchant == "SWIGGY PVT LTD FOOD2")
        #expect(result[2].merchant == "PHONEPE")
        #expect(result[3].merchant == "AMAZON PAY")
        #expect(result[4].merchant == "BIGBASKET")
    }

    /// A lazy wildcard on both sides of the optional card-digits group in the
    /// IndusInd, Axis, and HDFC patterns let the regex engine skip that group
    /// whenever the rest of the match still succeeded without it, so cardLast4
    /// came back nil even when the SMS plainly included a card number.
    @Test func extractsCardLast4ForIndusIndAxisAndHDFCFormats() {
        let indusInd = "INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60."
        #expect(SMSExpenseParser.parse(indusInd).first?.cardLast4 == "8022")

        let axis = "Spent INR 20019.64\nAxis Bank Card no. XX9854\n04-07-26 13:36:19 IST\nAMAZON PAY\nAvl Limit: INR 181980.36\nNot you? SMS BLOCK 9854 to 919951860002"
        #expect(SMSExpenseParser.parse(axis).first?.cardLast4 == "9854")

        let hdfc = "Txn Rs.149.00\nOn HDFC Bank Card 5865\nAt returnswealth710648.rzp@r \nby UPI 658121756648\nOn 03-08\nNot You?\nCall 18002586161/SMS BLOCK CC 5865 to 7308080808"
        #expect(SMSExpenseParser.parse(hdfc).first?.cardLast4 == "5865")
    }

    /// DateFormatter's custom `dateFormat` patterns are lenient about separators and
    /// digit counts even with isLenient = false: "dd-MM-yyyy" (first in the format
    /// list) happily "matched" a 2-digit year like "26" and produced year 26 AD,
    /// and the loop returned on that first apparent match before ever reaching
    /// "dd/MM/yy". Every 2-digit-year date — which is most Indian bank SMS —
    /// landed two millennia in the past. Amount and merchant were right, so the
    /// record showed in its list while every month-scoped total silently skipped
    /// it. Credits and debits were both affected, since they share this parser.
    @Test func twoDigitYearDatesParseToTheCorrectCentury() {
        // Credit (Canara) — the reported symptom: missing from the Income total.
        let credit = "Dear Customer, Acct XXXXX71966 credited with INR 500.00 on 04/08/26 from TESTPAYER; UPI:227178662096; Bal INR 1131.80-CanaraBank"
        let creditTx = try! #require(SMSExpenseParser.parse(credit).first)
        var components = Calendar.current.dateComponents([.day, .month, .year], from: creditTx.date)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 4)

        // Debit (SBI) — same root cause, so imported spending was dropped from
        // the Dashboard's current-month figure too.
        let debit = "Rs.653.95 spent on your SBI Credit Card ending 3140 at BIGBASKET on 09/07/26."
        let debitTx = try! #require(SMSExpenseParser.parse(debit).first)
        components = Calendar.current.dateComponents([.day, .month, .year], from: debitTx.date)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 9)

        // Debit (Axis) — dd-MM-yy with dashes rather than slashes.
        let axis = "Spent INR 20019.64\nAxis Bank Card no. XX9854\n04-07-26 13:36:19 IST\nAMAZON PAY\nAvl Limit: INR 181980.36"
        let axisTx = try! #require(SMSExpenseParser.parse(axis).first)
        components = Calendar.current.dateComponents([.day, .month, .year], from: axisTx.date)
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 4)

        // Credit (ICICI) — dd-MMM-yy, the named-month variant.
        let icici = "Dear Customer, Acct XX051 is credited with Rs 2480.00 on 01-Aug-26 from SHYAM SUNDER KU. UPI:490897397234-ICICI Bank."
        let iciciTx = try! #require(SMSExpenseParser.parse(icici).first)
        components = Calendar.current.dateComponents([.day, .month, .year], from: iciciTx.date)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 1)
    }

    /// Same lazy-wildcard issue affected the IndusInd format's transaction date.
    @Test func extractsDateForIndusIndFormat() {
        let sms = "INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60."
        let tx = try! #require(SMSExpenseParser.parse(sms).first)
        let components = Calendar.current.dateComponents([.day, .month, .year], from: tx.date)
        #expect(components.day == 2)
        #expect(components.month == 8)
        #expect(components.year == 2026)
    }

    @Test func parsesUserProvidedBankSMSBatch() {
        let paste = """
        [06/08/2026, 12:27:09 PM] Srinivas DPW Mandadi: Credit Card Purchase
        Card Ending: 1013
        At: HOOKAH PANI STAR CAFE, DUBAI
        Amount: AED 110.00
        Date: 02/08/2026, 22:54
        Available Limit: AED 17,899.46
        [06/08/2026, 12:27:25 PM] Srinivas DPW Mandadi: A Cr. transaction of AED 37.25 on your account number XXX820001 was successful.Available balance is 2970.45.
        [06/08/2026, 12:27:32 PM] Srinivas DPW Mandadi: A Dr. transaction of AED 200.00 on your account number XXX820001 was successful.Available balance is 2770.45.
        [06/08/2026, 12:27:39 PM] Srinivas DPW Mandadi: AED850.00 transferred via ADCB Personal Internet Banking / Mobile App from acc. no. XXX820001 on Aug  4 2026  7:52AM. Avl. bal. AED 2933.20.
        [06/08/2026, 12:28:12 PM] Srinivas DPW Mandadi: Your Cr.Card XXX6212 was used for AED2942.00 on 03/08/2026 10:16:47 at ZURICH INTL. LIFE LT,DUBAI-AE. Avl. Cr.limit is AED5783.69
        [06/08/2026, 12:28:44 PM] Srinivas DPW Mandadi: Trx. of AED80.00 on your card ending *429 at SWABI LAUNDRY L.L.C, UAE is Approved. Avl. card bal is 19502.90. Trx Date: 04/08/26 16:45
        """

        let result = SMSExpenseParser.parse(paste)
        #expect(result.count == 6)

        // 1. Credit Card Purchase - HOOKAH PANI STAR CAFE
        let tx1 = result[0]
        #expect(tx1.amount == Decimal(string: "110.00"))
        #expect(tx1.currency == "AED")
        #expect(tx1.merchant == "HOOKAH PANI STAR CAFE")
        #expect(tx1.cardLast4 == "1013")
        #expect(tx1.paymentMethod == .creditCard)
        #expect(tx1.isCredit == false)
        #expect(tx1.categoryName == "Food")

        // 2. A Cr. transaction of AED 37.25
        let tx2 = result[1]
        #expect(tx2.amount == Decimal(string: "37.25"))
        #expect(tx2.currency == "AED")
        #expect(tx2.merchant == "Account Credit")
        #expect(tx2.cardLast4 == "0001")
        #expect(tx2.isCredit == true)

        // 3. A Dr. transaction of AED 200.00
        let tx3 = result[2]
        #expect(tx3.amount == Decimal(string: "200.00"))
        #expect(tx3.currency == "AED")
        #expect(tx3.merchant == "Account Debit")
        #expect(tx3.cardLast4 == "0001")
        #expect(tx3.isCredit == false)

        // 4. AED850.00 transferred via ADCB
        let tx4 = result[3]
        #expect(tx4.amount == Decimal(string: "850.00"))
        #expect(tx4.currency == "AED")
        #expect(tx4.merchant == "ADCB Personal Internet Banking / Mobile App")
        #expect(tx4.cardLast4 == "0001")
        #expect(tx4.isCredit == false)

        // 5. Your Cr.Card XXX6212 was used for AED2942.00 at ZURICH INTL. LIFE LT
        let tx5 = result[4]
        #expect(tx5.amount == Decimal(string: "2942.00"))
        #expect(tx5.currency == "AED")
        #expect(tx5.merchant == "ZURICH INTL. LIFE LT")
        #expect(tx5.cardLast4 == "6212")
        #expect(tx5.paymentMethod == .creditCard)
        #expect(tx5.categoryName == "Insurance")
        #expect(tx5.isCredit == false)

        // 6. Trx. of AED80.00 on your card ending *429 at SWABI LAUNDRY L.L.C
        let tx6 = result[5]
        #expect(tx6.amount == Decimal(string: "80.00"))
        #expect(tx6.currency == "AED")
        #expect(tx6.merchant == "SWABI LAUNDRY L.L.C")
        // "*429" masks the fourth digit, so only three are actually known.
        // Padding to "0429" would state a digit the message never gave and show
        // the user a card number that is wrong in its leading position, so the
        // parser keeps what it was told.
        #expect(tx6.cardLast4 == "429")
        #expect(tx6.categoryName == "Bills")
        #expect(tx6.isCredit == false)
    }

    @Test func parsesUndetectedThreeTransactionsPaste() {
        let paste = """
        [06/08/2026, 12:27:25 PM] Srinivas DPW Mandadi: A Cr. transaction of AED 37.25 on your account number XXX820001 was successful.Available balance is 2970.45.
        [06/08/2026, 12:27:32 PM] Srinivas DPW Mandadi: A Dr. transaction of AED 200.00 on your account number XXX820001 was successful.Available balance is 2770.45.
        Trx. of AED80.00 on your card ending *429 at SWABI LAUNDRY L.L.C, UAE is Approved. Avl. card bal is 19502.90. Trx Date: 04/08/26 16:45
        """

        let result = SMSExpenseParser.parse(paste)
        #expect(result.count == 3)
    }

    @Test func parsesPaymentOfToMerchantWithCardSMS() {
        let sms = "Payment of AED 37.99 to Noon Minutes with Credit Card ending 8220. Avl Cr. Limit is AED 1,030.80."
        let result = SMSExpenseParser.parse(sms)
        #expect(result.count == 1)

        let tx = result[0]
        #expect(tx.amount == Decimal(string: "37.99"))
        #expect(tx.currency == "AED")
        #expect(tx.merchant == "Noon Minutes")
        #expect(tx.cardLast4 == "8220")
        #expect(tx.paymentMethod == .creditCard)
        #expect(tx.categoryName == "Shopping")
        #expect(tx.isCredit == false)
    }

    // MARK: - DIB / FAB

    /// DIB truncates merchant names mid-word and runs the next sentence straight
    /// on with no space (".Available"), and some names carry a dot of their own,
    /// so the merchant has to run to that exact phrase rather than to the first
    /// full stop — otherwise "Amazon.ae" comes back as "Amazon".
    @Test func parsesDIBOnlinePurchase() {
        let sms = "Online Purchase of AED 194.75 on Covered Card XX8726 on 05-MAY-2026 12:58 from Amazon.ae.Available Credit Limit is AED 24,923.34"
        let tx = try! #require(SMSExpenseParser.parse(sms).first)
        #expect(tx.amount == Decimal(string: "194.75"))
        #expect(tx.currency == "AED")
        #expect(tx.merchant == "Amazon.ae")
        #expect(tx.cardLast4 == "8726")
        #expect(tx.isCredit == false)

        let components = Calendar.current.dateComponents([.day, .month, .year], from: tx.date)
        #expect(components.day == 5)
        #expect(components.month == 5)
        #expect(components.year == 2026)
    }

    /// FAB's card-bill payment carries no merchant, so it is labelled by the card
    /// it settles rather than given an invented one.
    @Test func parsesFABCardBillPayment() {
        let sms = "Dear Customer, Your Payment of AED 105.00 for card 5425XXXXXXXX7109 has been processed on 15/05/2026"
        let tx = try! #require(SMSExpenseParser.parse(sms).first)
        #expect(tx.amount == Decimal(string: "105.00"))
        #expect(tx.currency == "AED")
        #expect(tx.cardLast4 == "7109")
        #expect(tx.merchant == "Card Payment ****7109")
        #expect(tx.isCredit == false)
    }

    /// Each format's opening phrase must also be listed in the splitter, or its
    /// messages never start a new piece and get swallowed into the one before —
    /// every message here parsed fine alone while the batch came back 5 of 8.
    @Test func parsesAMixedUAEBatchInOnePaste() {
        let paste = """
        Dear Customer, Your Payment of AED 105.00 for card 5425XXXXXXXX7109 has been processed on 15/05/2026

        Dear Customer, Your Payment of AED 38.00 for card 5213XXXXXXXX3974 has been processed on 15/05/2026

        Your Cr.Card XXX0533 was used for AED1205.00 on 27/01/2026 15:35:43 at EMIRATES,DUBAI-AE. Avl. Cr.limit is AED1511.08

        Your Cr.Card XXX0533 was used for AED38.05 on 06/12/2025 12:32:17 at Noon Food,Dubai-AE. Avl. Cr.limit is AED437.39

        Online Purchase of AED 16.00 on Covered Card XX8726 on 12-MAY-2026 12:05 from Amazon Prime Subscri.Available Credit Limit is AED 24,779.21

        Online Purchase of AED 1,350.00 on Covered Card XX8726 on 05-MAY-2026 12:08 from Smart Dubai Governme.Available Credit Limit is AED 25,118.09
        """

        let result = SMSExpenseParser.parse(paste)

        #expect(result.count == 6)
        #expect(result.map(\.amount) == [
            Decimal(string: "105.00"), Decimal(string: "38.00"),
            Decimal(string: "1205.00"), Decimal(string: "38.05"),
            Decimal(string: "16.00"), Decimal(string: "1350.00"),
        ])
        #expect(result[2].merchant == "EMIRATES")
        #expect(result[3].merchant == "Noon Food")
        #expect(result[5].merchant == "Smart Dubai Governme")
    }
}

