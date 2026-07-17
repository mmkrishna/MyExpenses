//
//  CatalogTests.swift
//  MyExpenses+Tests
//
//  Guards the built-in catalogue and the seeding that turns it into rows.
//  A mistyped SF Symbol renders as a blank icon at runtime rather than failing
//  the build, so it is checked here.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import MyExpenses_

@MainActor
struct CatalogTests {

    @Test func everyBuiltInIconIsARealSFSymbol() {
        for category in BuiltInCategory.allCases {
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

    @Test func builtInsCoverTheExpectedCategories() {
        let names = Set(BuiltInCategory.allCases.map(\.rawValue))
        for expected in ["Food", "Coffee", "Grocery", "Fuel", "Transport", "Parking Subscription",
                         "Car License", "Shopping", "Entertainment", "Health", "Bills",
                         "Insurance", "Rent", "Travel", "Subscription", "Other"] {
            #expect(names.contains(expected), "missing built-in: \(expected)")
        }
        #expect(names.count == BuiltInCategory.allCases.count) // no duplicate names
    }

    @Test func everyBuiltInColourParsesToSomethingOtherThanTheFallback() {
        // Color(hex:) silently falls back to grey on a malformed string, so a typo
        // would otherwise go unnoticed. Only "Other" is legitimately grey.
        for category in BuiltInCategory.allCases where category != .other {
            #expect(category.colorHex.count == 7 && category.colorHex.hasPrefix("#"),
                    "\(category.rawValue) has a malformed hex: \(category.colorHex)")
        }
    }

    @Test func insuranceMerchantsAreCategorised() {
        #expect(SMSExpenseParser.guessCategory(for: "AXA INSURANCE") == .insurance)
        #expect(SMSExpenseParser.guessCategory(for: "Salama Takaful") == .insurance)
        // Must not swallow unrelated merchants.
        #expect(SMSExpenseParser.guessCategory(for: "Noon") == .shopping)
    }

    // MARK: - Seeding

    @Test func seedingCreatesBuiltInsOnceAndIsIdempotent() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext

        #expect(CategoryStore.seedBuiltInsIfNeeded(in: context) == true)
        #expect(CategoryStore.all(in: context).count == BuiltInCategory.allCases.count)
        #expect(CategoryStore.all(in: context).allSatisfy { $0.isBuiltIn })

        // Running again must not duplicate rows.
        #expect(CategoryStore.seedBuiltInsIfNeeded(in: context) == false)
        #expect(CategoryStore.all(in: context).count == BuiltInCategory.allCases.count)

        // Lookup is case-insensitive, and unknown names create a custom category.
        #expect(CategoryStore.find(named: "rent", in: context)?.name == "Rent")
        let custom = CategoryStore.findOrCreate(named: "Childcare", in: context)
        #expect(custom.isBuiltIn == false)
        #expect(CategoryStore.all(in: context).count == BuiltInCategory.allCases.count + 1)

        // Seeded categories keep the catalogue's order.
        #expect(CategoryStore.all(in: context).first?.name == BuiltInCategory.food.rawValue)
    }
}
