import SwiftUI

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case bankTransfer = "Bank Transfer"
    case digitalWallet = "Digital Wallet"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cash: "banknote.fill"
        case .creditCard: "creditcard.fill"
        case .debitCard: "creditcard"
        case .bankTransfer: "building.columns.fill"
        case .digitalWallet: "wallet.pass.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}
