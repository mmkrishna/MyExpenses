import Foundation
import SwiftData
import Observation

enum ExpenseSortOption: String, CaseIterable, Identifiable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case amountDescending = "Highest Amount"
    case amountAscending = "Lowest Amount"

    var id: String { rawValue }
}

@Observable
final class ExpensesViewModel {
    var searchText: String = ""
    var selectedMonth: Date?
    var sortOption: ExpenseSortOption = .dateDescending

    var showingAddExpense = false
    var showingImportSMS = false
    var expenseToEdit: Expense?

    func availableMonths(in expenses: [Expense], calendar: Calendar = .current) -> [Date] {
        let months = Set(expenses.map { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        return months.sorted(by: >)
    }

    func filteredAndSorted(_ expenses: [Expense], calendar: Calendar = .current) -> [Expense] {
        var result = expenses

        if let selectedMonth {
            result = result.filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            result = result.filter { expense in
                expense.merchant.localizedCaseInsensitiveContains(trimmedSearch)
                    || expense.notes.localizedCaseInsensitiveContains(trimmedSearch)
                    || expense.category.displayName.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }

        switch sortOption {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.amount > $1.amount }
        case .amountAscending:
            result.sort { $0.amount < $1.amount }
        }

        return result
    }

    func delete(_ expense: Expense, context: ModelContext) {
        Haptics.delete()
        context.delete(expense)
    }
}
