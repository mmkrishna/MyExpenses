import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    private let defaults = UserDefaults.standard

    var currencyCode: String {
        didSet { defaults.set(currencyCode, forKey: "preferredCurrencyCode") }
    }

    var monthlyBudget: Double {
        didSet { defaults.set(monthlyBudget, forKey: "monthlyBudget") }
    }

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: "appearancePreference") }
    }

    var faceIDEnabled: Bool {
        didSet { defaults.set(faceIDEnabled, forKey: "faceIDEnabled") }
    }

    var isExporting = false
    var shareURL: URL?
    var alertMessage: String?

    init() {
        currencyCode = defaults.string(forKey: "preferredCurrencyCode") ?? (Locale.current.currency?.identifier ?? "USD")
        monthlyBudget = defaults.double(forKey: "monthlyBudget")
        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearancePreference") ?? "") ?? .system
        faceIDEnabled = defaults.bool(forKey: "faceIDEnabled")
    }

    static let availableCurrencyCodes: [String] = {
        Locale.commonISOCurrencyCodes.sorted()
    }()

    var biometryName: String { BiometricAuthService.biometryTypeName }
    var biometryAvailable: Bool { BiometricAuthService.isAvailable }

    /// Returns every preference to its just-installed value. Assigning through
    /// the properties lets their `didSet` clear the stored copies too, so there
    /// is no second list of keys to keep in step.
    func reset() {
        currencyCode = Locale.current.currency?.identifier ?? "USD"
        monthlyBudget = 0
        appearance = .system
        faceIDEnabled = false
    }

    @MainActor
    func toggleFaceID(_ enabled: Bool) async {
        guard enabled, biometryAvailable else {
            faceIDEnabled = enabled && biometryAvailable
            return
        }
        let success = await BiometricAuthService.authenticate(reason: "Enable \(biometryName) to protect your expenses")
        faceIDEnabled = success
        if !success {
            alertMessage = "Could not verify \(biometryName)."
        }
    }

    func exportAnnualReportCSV(expenses: [Expense], incomes: [Income], year: Int = Calendar.current.component(.year, from: Date())) {
        guard let url = CSVExportService.exportCategoryReport(
            reportTitle: "Annual Report",
            periodLabel: String(year),
            incomeTotal: totalIncome(incomes, inYear: year),
            expenseTotal: totalExpenses(expenses, inYear: year),
            categoryTotals: categoryTotals(expenses, inYear: year),
            incomeSourceTotals: incomeSourceTotals(incomes, inYear: year)
        ) else {
            alertMessage = "Could not export CSV."
            return
        }
        shareURL = url
    }

    @MainActor
    func exportAnnualReportPDF(expenses: [Expense], incomes: [Income], year: Int = Calendar.current.component(.year, from: Date())) {
        guard let url = MonthlyReportPDFService.export(
            reportTitle: "Annual Report",
            periodLabel: String(year),
            incomeTotal: totalIncome(incomes, inYear: year),
            expenseTotal: totalExpenses(expenses, inYear: year),
            categoryTotals: categoryTotals(expenses, inYear: year),
            incomeSourceTotals: incomeSourceTotals(incomes, inYear: year),
            currencyCode: currencyCode
        ) else {
            alertMessage = "Could not export PDF."
            return
        }
        shareURL = url
    }

    private func totalExpenses(_ expenses: [Expense], inYear year: Int, calendar: Calendar = .current) -> Decimal {
        expenses
            .filter { calendar.component(.year, from: $0.date) == year }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    private func totalIncome(_ incomes: [Income], inYear year: Int, calendar: Calendar = .current) -> Decimal {
        incomes
            .filter { calendar.component(.year, from: $0.date) == year }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    private func categoryTotals(_ expenses: [Expense], inYear year: Int, calendar: Calendar = .current) -> [CategorySpending] {
        let yearExpenses = expenses.filter { calendar.component(.year, from: $0.date) == year }
        let grouped = Dictionary(grouping: yearExpenses, by: \.category)
        return grouped
            .map { CategorySpending(category: $0.key, total: $0.value.reduce(into: Decimal.zero) { $0 += $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private func incomeSourceTotals(_ incomes: [Income], inYear year: Int, calendar: Calendar = .current) -> [IncomeSourceTotal] {
        let yearIncomes = incomes.filter { calendar.component(.year, from: $0.date) == year }
        let grouped = Dictionary(grouping: yearIncomes, by: \.source)
        return grouped
            .map { IncomeSourceTotal(source: $0.key, total: $0.value.reduce(into: Decimal.zero) { $0 += $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func backup(_ expenses: [Expense]) {
        guard let url = BackupService.backup(expenses) else {
            alertMessage = "Could not create backup."
            return
        }
        shareURL = url
    }

    func restore(from url: URL, context: ModelContext, existing: [Expense]) {
        do {
            let count = try BackupService.restore(from: url, context: context, existing: existing)
            alertMessage = count == 0 ? "No new expenses to restore." : "Restored \(count) expense\(count == 1 ? "" : "s")."
        } catch {
            alertMessage = "Could not restore backup: \(error.localizedDescription)"
        }
    }
}
