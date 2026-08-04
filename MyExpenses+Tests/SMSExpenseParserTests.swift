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

    @Test func parsesIndusIndSpentSMS() {
        let sms = "INR 272.00 spent on IndusInd Card XX8022 on 02-08-2026 07:06:45 pm at SWIGGY PVT LTD FOOD2. Avl Lmt: INR 104,421.60. To dispute, call 18602677777/SMS BLOCK 8022 to 5676757"
        let result = SMSExpenseParser.parse(sms)

        let tx = try! #require(result.first)
        #expect(tx.amount == Decimal(string: "272.00"))
        #expect(tx.currency == "INR")
        #expect(tx.merchant == "SWIGGY PVT LTD FOOD2")
        #expect(tx.cardLast4 == "8022")
        #expect(tx.categoryName == "Food")
        #expect(tx.isCredit == false)
    }
}
