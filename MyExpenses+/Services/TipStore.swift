import Foundation
import StoreKit

/// StoreKit 2 tip jar. Every tier is a *consumable* that unlocks nothing — the
/// app is 100% free — so a purchase only ever needs to be finished, never
/// restored or checked for entitlement.
@Observable
final class TipStore {
    /// The tip tiers, in ascending price order. Raw values are the product IDs
    /// and must match App Store Connect and the bundled StoreKit configuration.
    enum Tier: String, CaseIterable, Identifiable {
        case coffee = "com.mmkrishna.myexpenses.tip.coffee"
        case lunch = "com.mmkrishna.myexpenses.tip.lunch"
        case supporter = "com.mmkrishna.myexpenses.tip.supporter"
        case ultimate = "com.mmkrishna.myexpenses.tip.ultimate"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .coffee: "☕"
            case .lunch: "🍕"
            case .supporter: "🚀"
            case .ultimate: "💎"
            }
        }

        var title: String {
            switch self {
            case .coffee: "Buy Me a Coffee"
            case .lunch: "Buy Me Lunch"
            case .supporter: "Become a Supporter"
            case .ultimate: "Ultimate Supporter"
            }
        }

        /// Shown until the real localized price loads from the store, and if
        /// loading ever fails. Matches the intended App Store Connect prices.
        var fallbackPrice: String {
            switch self {
            case .coffee: "$1.99"
            case .lunch: "$4.99"
            case .supporter: "$9.99"
            case .ultimate: "$19.99"
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    var errorMessage: String?

    /// One transaction listener per process, regardless of how many stores exist.
    private static var isListening = false

    func product(for tier: Tier) -> Product? {
        products.first { $0.id == tier.id }
    }

    /// The store's localized price if loaded, otherwise the intended fallback.
    func displayPrice(for tier: Tier) -> String {
        product(for: tier)?.displayPrice ?? tier.fallbackPrice
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = Tier.allCases.map { $0.id }
            let loaded = try await Product.products(for: ids)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Couldn't load tips right now. Please try again in a moment."
        }
        Self.startTransactionListener()
    }

    /// Attempts a purchase.
    /// - Returns: `true` only on a verified, finished purchase.
    func tip(_ product: Product) async -> Bool {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "That purchase couldn't be verified."
                    return false
                }
                // Consumable: nothing to grant, so just finish it.
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Something went wrong with the purchase. Please try again."
            return false
        }
    }

    /// Finishes transactions that arrive outside a direct purchase — Ask to Buy
    /// approvals, or purchases interrupted before they finished. Consumables
    /// grant nothing, so finishing is all that's required. Runs once per process.
    private static func startTransactionListener() {
        guard !isListening else { return }
        isListening = true
        Task.detached {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
            }
        }
    }
}
