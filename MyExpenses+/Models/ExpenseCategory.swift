//
//  ExpenseCategory.swift
//  MyExpenses+
//
//  Created by Murali Krishna on 15/07/2026.
//

import SwiftUI

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case coffee = "Coffee"
    case grocery = "Grocery"
    case fuel = "Fuel"
    case transport = "Transport"
    case parkingSubscription = "Parking Subscription"
    case carLicense = "Car License"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case health = "Health"
    case bills = "Bills"
    case insurance = "Insurance"
    case rent = "Rent"
    case travel = "Travel"
    case subscription = "Subscription"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .coffee: "cup.and.saucer.fill"
        case .grocery: "cart.fill"
        case .fuel: "fuelpump.fill"
        case .transport: "car.fill"
        case .parkingSubscription: "parkingsign.circle.fill"
        case .carLicense: "licenseplate.fill"
        case .shopping: "bag.fill"
        case .entertainment: "film.fill"
        case .health: "heart.fill"
        case .bills: "doc.text.fill"
        case .insurance: "shield.fill"
        case .rent: "house.fill"
        case .travel: "airplane"
        case .subscription: "repeat.circle.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: .orange
        case .coffee: .brown
        case .grocery: .green
        case .fuel: .red
        case .transport: .blue
        // The system palette is fully used by the cases above, so the rest are custom
        // tones picked from the unused hue gaps. Each is dark/saturated enough to keep
        // a white glyph legible on top, which rules out anything yellow.
        case .parkingSubscription: Color(red: 0.62, green: 0.24, blue: 0.42) // plum
        case .carLicense: Color(red: 0.70, green: 0.33, blue: 0.13) // rust
        case .shopping: .purple
        case .entertainment: .pink
        case .health: .mint
        case .bills: .indigo
        case .insurance: Color(red: 0.45, green: 0.50, blue: 0.16) // olive
        case .rent: Color(red: 0.36, green: 0.44, blue: 0.60) // steel blue
        case .travel: .cyan
        case .subscription: .teal
        case .other: .gray
        }
    }
}
