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
        #expect(tx.category == .shopping)
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
        #expect(result[0].category == .shopping)

        #expect(result[1].amount == Decimal(string: "20.00"))
        #expect(result[1].merchant == "SOCIAL HUB FZCO")
        #expect(result[1].category == .other)

        #expect(result[2].amount == Decimal(string: "25.40"))
        #expect(result[2].merchant == "Noon")

        #expect(result[3].amount == Decimal(string: "14.00"))
        #expect(result[3].merchant == "AL JEERAN REST LLC")
        #expect(result[3].category == .food) // "REST" keyword
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
        #expect(tx.category == .travel)
    }
}
