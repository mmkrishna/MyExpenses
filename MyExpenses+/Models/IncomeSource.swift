import SwiftUI

/// Default and custom income source classification.
enum IncomeSource: String, CaseIterable, Identifiable {
    case salary = "Salary"
    case business = "Business"
    case stocks = "Stocks"
    case rent = "Rent"
    case interest = "Interest"
    case dividends = "Dividends"
    case freelance = "Freelance"
    case gifts = "Gifts"
    case other = "Other"
    case custom = "Custom"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .salary: "banknote.fill"
        case .business: "briefcase.fill"
        case .stocks: "chart.line.uptrend.xyaxis"
        case .rent: "house.fill"
        case .interest: "percent"
        case .dividends: "dollarsign.circle.fill"
        case .freelance: "laptopcomputer"
        case .gifts: "gift.fill"
        case .other: "ellipsis.circle.fill"
        case .custom: "plus.circle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .salary: "#34C759"      // green
        case .business: "#5856D6"    // indigo
        case .stocks: "#30B0C7"      // teal
        case .rent: "#007AFF"        // blue
        case .interest: "#FF9500"    // orange
        case .dividends: "#FF2D55"   // pink
        case .freelance: "#AF52DE"   // purple
        case .gifts: "#FF3B30"       // red
        case .other: "#8E8E93"       // grey
        case .custom: "#5F259F"      // deep purple
        }
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
