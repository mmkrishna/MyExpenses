//
//  TipStoreTests.swift
//  MyExpenses+Tests
//

import Foundation
import Testing
@testable import MyExpenses_

@MainActor
struct TipStoreTests {
    @Test func tiersAreDistinctAndUseTheBundleIDPrefix() {
        let ids = TipStore.Tier.allCases.map(\.id)
        #expect(ids.count == 4)
        #expect(Set(ids).count == 4)
        #expect(ids.allSatisfy { $0.hasPrefix("com.mmkrishna.myexpenses.tip.") })
        for tier in TipStore.Tier.allCases {
            #expect(!tier.emoji.isEmpty)
            #expect(!tier.title.isEmpty)
            #expect(tier.fallbackPrice.hasPrefix("$"))
        }
    }

    /// Validates the bundled StoreKit configuration against the Tier enum. This
    /// is deterministic — it parses the config file rather than spinning up an
    /// SKTestSession — and catches the drift that actually bites in production:
    /// a product-ID typo, a price that no longer matches the fallback shown in
    /// the UI, or a tier accidentally not marked Consumable. (The live purchase
    /// path is exercised through Xcode's StoreKit testing on the scheme.)
    @Test func bundledStoreKitConfigMatchesTheTiers() throws {
        struct Config: Decodable {
            struct Product: Decodable {
                let productID: String
                let displayPrice: String
                let type: String
            }
            let products: [Product]
        }

        let url = try #require(
            Bundle.main.url(forResource: "MyExpenses+", withExtension: "storekit"),
            "The StoreKit configuration must be bundled with the app."
        )
        let config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))

        // Same set of product IDs as the Tier enum — no more, no less.
        let configIDs = Set(config.products.map(\.productID))
        let tierIDs = Set(TipStore.Tier.allCases.map(\.id))
        #expect(configIDs == tierIDs)

        // Every product is a consumable (the whole point — nothing is unlocked).
        #expect(config.products.allSatisfy { $0.type == "Consumable" })

        // Each tier's fallback price matches the configured price, so the UI shows
        // the right number before the live price loads.
        let priceByID = Dictionary(uniqueKeysWithValues: config.products.map { ($0.productID, $0.displayPrice) })
        for tier in TipStore.Tier.allCases {
            #expect(tier.fallbackPrice == "$\(priceByID[tier.id] ?? "?")")
        }
    }
}
