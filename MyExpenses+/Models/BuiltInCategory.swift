//
//  BuiltInCategory.swift
//  MyExpenses+
//

import SwiftUI

/// The default categories shipped with the app.
///
/// This is no longer stored on an expense — `ExpenseCategory` is, so users can add their
/// own. This enum survives as the seed catalogue for first launch and as the
/// vocabulary the SMS parser guesses against.
enum BuiltInCategory: String, CaseIterable, Identifiable {
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

    /// The category every expense falls back to.
    static let fallback: BuiltInCategory = .other

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

    /// Stored as hex because a user-editable category persists its own colour.
    /// The system palette is fully used, so later cases are custom tones picked
    /// from the unused hue gaps. Each stays dark enough to keep a white glyph
    /// legible on top, which rules out anything yellow.
    var colorHex: String {
        switch self {
        case .food: "#FF9500"                 // orange
        case .coffee: "#A2845E"               // brown
        case .grocery: "#34C759"              // green
        case .fuel: "#FF3B30"                 // red
        case .transport: "#007AFF"            // blue
        case .parkingSubscription: "#9E3D6B"  // plum
        case .carLicense: "#B35421"           // rust
        case .shopping: "#AF52DE"             // purple
        case .entertainment: "#FF2D55"        // pink
        case .health: "#00C7BE"               // mint
        case .bills: "#5856D6"                // indigo
        case .insurance: "#738029"            // olive
        case .rent: "#5C7099"                 // steel blue
        case .travel: "#32ADE6"               // cyan
        case .subscription: "#30B0C7"         // teal
        case .other: "#8E8E93"                // grey
        }
    }

    /// A fresh `ExpenseCategory` row for seeding.
    func makeCategory(sortOrder: Int) -> ExpenseCategory {
        ExpenseCategory(
            name: rawValue,
            symbolName: systemImage,
            colorHex: colorHex,
            isBuiltIn: true,
            sortOrder: sortOrder
        )
    }
}
