//
//  CatalogTests.swift
//  MyExpenses+Tests
//
//  Guards the category / payment-method catalogs: a mistyped SF Symbol name
//  renders as a blank icon at runtime rather than failing to build.
//

import Foundation
import Testing
import UIKit
@testable import MyExpenses_

@MainActor
struct CatalogTests {

    @Test func everyCategoryIconIsARealSFSymbol() {
        for category in ExpenseCategory.allCases {
            #expect(
                UIImage(systemName: category.systemImage) != nil,
                "\(category.rawValue) has an invalid SF Symbol: \(category.systemImage)"
            )
        }
    }

    @Test func everyPaymentMethodIconIsARealSFSymbol() {
        for method in PaymentMethod.allCases {
            #expect(
                UIImage(systemName: method.systemImage) != nil,
                "\(method.rawValue) has an invalid SF Symbol: \(method.systemImage)"
            )
        }
    }

    @Test func newCategoriesAndPaymentMethodExist() {
        #expect(ExpenseCategory(rawValue: "Rent") == .rent)
        #expect(ExpenseCategory(rawValue: "Parking Subscription") == .parkingSubscription)
        #expect(ExpenseCategory(rawValue: "Insurance") == .insurance)
        #expect(ExpenseCategory(rawValue: "Car License") == .carLicense)
        #expect(PaymentMethod(rawValue: "Check") == .check)
    }

    @Test func insuranceMerchantsAreCategorised() {
        #expect(SMSExpenseParser.guessCategory(for: "AXA INSURANCE") == .insurance)
        #expect(SMSExpenseParser.guessCategory(for: "Salama Takaful") == .insurance)
        // Must not swallow unrelated merchants.
        #expect(SMSExpenseParser.guessCategory(for: "Noon") == .shopping)
    }

    @Test func categoryRawValuesAreUnique() {
        let raws = ExpenseCategory.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }

    /// Existing stored expenses must keep decoding after new cases are added.
    @Test func previouslyStoredCategoriesStillDecode() {
        for raw in ["Food", "Coffee", "Grocery", "Fuel", "Transport", "Shopping",
                    "Entertainment", "Health", "Bills", "Travel", "Subscription", "Other"] {
            #expect(ExpenseCategory(rawValue: raw) != nil, "lost category: \(raw)")
        }
        for raw in ["Cash", "Credit Card", "Debit Card", "Bank Transfer", "Digital Wallet", "Other"] {
            #expect(PaymentMethod(rawValue: raw) != nil, "lost payment method: \(raw)")
        }
    }
}
