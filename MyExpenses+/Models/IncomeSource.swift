import SwiftUI

/// Default and custom income source classification.
enum IncomeSource: String, CaseIterable, Identifiable {
    case salary = "Salary"
    case rent = "Rent"
    case interest = "Interest"
    case custom = "Custom"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .salary: "banknote.fill"
        case .rent: "house.fill"
        case .interest: "percent"
        case .custom: "ellipsis.circle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .salary: "#34C759"     // green
        case .rent: "#007AFF"       // blue
        case .interest: "#FF9500"   // orange
        case .custom: "#AF52DE"     // purple
        }
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
