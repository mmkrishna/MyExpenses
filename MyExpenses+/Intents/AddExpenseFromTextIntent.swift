import AppIntents
import SwiftData

/// Parses a bank SMS / purchase message and logs the expense(s).
/// Exposed to Shortcuts and Siri so users can automate capture (e.g. a
/// "When I get a message from my bank" automation that pipes the text here).
struct AddExpenseFromTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense from Text"
    static let description = IntentDescription(
        "Reads a bank SMS or purchase message and logs the expense in MyExpenses+."
    )

    @Parameter(title: "Message", description: "The bank SMS or purchase text to log.")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = ExpenseImporter.importExpenses(from: text, into: AppModelContainer.shared.mainContext)

        guard result.count > 0 else {
            return .result(dialog: "I couldn't find any transactions in that message.")
        }

        let amount = CurrencyFormatter.string(from: result.total, currencyCode: result.currency)
        let noun = result.count == 1 ? "expense" : "expenses"
        return .result(dialog: "Added \(result.count) \(noun) totaling \(amount).")
    }
}

struct MyExpensesAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseFromTextIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log a purchase in \(.applicationName)",
                "Add expense from text in \(.applicationName)",
            ],
            shortTitle: "Add Expense from Text",
            systemImageName: "creditcard"
        )
    }
}
