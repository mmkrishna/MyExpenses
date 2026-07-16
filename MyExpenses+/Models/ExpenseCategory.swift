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
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case health = "Health"
    case bills = "Bills"
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
        case .shopping: "bag.fill"
        case .entertainment: "film.fill"
        case .health: "heart.fill"
        case .bills: "doc.text.fill"
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
        case .shopping: .purple
        case .entertainment: .pink
        case .health: .mint
        case .bills: .indigo
        case .travel: .cyan
        case .subscription: .teal
        case .other: .gray
        }
    }
}
