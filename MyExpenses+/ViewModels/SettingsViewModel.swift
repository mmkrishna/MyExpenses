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

    func exportCSV(_ expenses: [Expense]) {
        guard let url = CSVExportService.export(expenses) else {
            alertMessage = "Could not export CSV."
            return
        }
        shareURL = url
    }

    func exportPDF(_ expenses: [Expense]) {
        guard let url = PDFExportService.export(expenses) else {
            alertMessage = "Could not export PDF."
            return
        }
        shareURL = url
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
