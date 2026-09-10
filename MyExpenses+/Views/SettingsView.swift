// SettingsView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileViewModel.self) private var profile
    @State private var viewModel = SettingsViewModel()
    @State private var showingRestoreImporter = false
    @State private var showingEditProfile = false
    @State private var showingCategories = false
    @State private var tipStore = TipStore()
    @State private var showingThankYou = false
    @State private var showingDeleteAccount = false
    @State private var deleteAccountError: String?

    // Read from the bundle so the shipped version is always what's shown.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var exportFooterText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "A full annual report with income and spending broken down by category, for \(year)."
    }

    // Extracted so the Form body stays small enough for the type-checker.
    private var exportSection: some View {
        Section {
            Button {
                Haptics.tap()
                viewModel.exportAnnualReportCSV(expenses: expenses, incomes: incomes)
            } label: {
                Label("Export CSV", systemImage: "doc.text")
            }
            .disabled(expenses.isEmpty && incomes.isEmpty)

            Button {
                Haptics.tap()
                viewModel.exportAnnualReportPDF(expenses: expenses, incomes: incomes)
            } label: {
                Label("Export PDF", systemImage: "doc.richtext")
            }
            .disabled(expenses.isEmpty && incomes.isEmpty)
        } header: {
            Text("Export")
        } footer: {
            Text(exportFooterText)
        }
    }

    // Extracted so the Form body stays small enough for the type-checker.
    private var supportSection: some View {
        Section {
            Text("A one-time tip to support development. Totally optional.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(TipStore.Tier.allCases) { tier in
                Button {
                    tip(tier)
                } label: {
                    HStack(spacing: 10) {
                        Text(tier.emoji)
                            .accessibilityHidden(true)
                        Text(tier.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(tipStore.displayPrice(for: tier))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
                .accessibilityLabel("\(tier.title), \(tipStore.displayPrice(for: tier))")
            }
        } header: {
            Text("❤️ Support Development")
        } footer: {
            Text("Tips don't unlock anything — the app stays free. Thank you!")
        }
    }

    /// Kept visually last and styled destructively. There is no server account to
    /// close, so this is a full local wipe — the copy says exactly that rather
    /// than implying something is being deleted from a service.
    private var deleteAccountSection: some View {
        Section {
            Button(role: .destructive) {
                Haptics.tap()
                showingDeleteAccount = true
            } label: {
                Label("Delete Account", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Permanently erases your expenses, income, custom categories, profile and settings from this device. This cannot be undone — back up first if you want to keep a copy.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Developed by", value: "Murali Krishna M")
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("© 2026 Murali Krishna M")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
            Form {
                Section {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack(spacing: 14) {
                            ProfileAvatarView(photoData: profile.photoData, initials: profile.initials, size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.hasName ? profile.name : "Add Your Name")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(profile.hasName ? "Edit Profile" : "Tap to set up your profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit Profile")
                }
                .id(ScrollAnchor.top)

                Section("Currency & Budget") {
                    Picker("Currency", selection: $viewModel.currencyCode) {
                        ForEach(SettingsViewModel.availableCurrencyCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }

                    HStack {
                        Text("Monthly Budget")
                        Spacer()
                        TextField("0", value: $viewModel.monthlyBudget, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Categories") {
                    Button {
                        showingCategories = true
                    } label: {
                        Label("Manage Categories", systemImage: "tag")
                    }
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $viewModel.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Security") {
                    Toggle(isOn: Binding(
                        get: { viewModel.faceIDEnabled },
                        set: { newValue in
                            Task { await viewModel.toggleFaceID(newValue) }
                        }
                    )) {
                        Label(viewModel.biometryAvailable ? viewModel.biometryName : "Face ID", systemImage: "faceid")
                    }
                    .disabled(!viewModel.biometryAvailable)

                    if !viewModel.biometryAvailable {
                        Text("Biometric authentication is not available on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                exportSection

                Section("Backup & Restore") {
                    Button {
                        Haptics.tap()
                        viewModel.backup(expenses)
                    } label: {
                        Label("Backup Expenses", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(expenses.isEmpty)

                    Button {
                        showingRestoreImporter = true
                    } label: {
                        Label("Restore from Backup", systemImage: "icloud.and.arrow.down")
                    }
                }

                supportSection
                deleteAccountSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .onTabReselect(.settings) {
                withAnimation { scroll.scrollTo(ScrollAnchor.top, anchor: .top) }
            }
            .tabBarClearance()
            .contentColumn()
            .background(Theme.background)
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showingDeleteAccount,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every expense, income record, custom category, your profile and all settings will be erased from this device. This cannot be undone.")
            }
            .alert("Could not delete account", isPresented: Binding(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteAccountError ?? "")
            }
            .task { await tipStore.loadProducts() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            // The budget field uses .decimalPad, which has no return key, so it
            // needs an explicit way to dismiss.
            .keyboardDoneButton()
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingCategories) {
                ManageCategoriesView()
            }
            .sheet(item: Binding(
                get: { viewModel.shareURL.map(ShareItem.init) },
                set: { viewModel.shareURL = $0?.url }
            )) { item in
                ShareSheet(items: [item.url])
            }
            .fileImporter(isPresented: $showingRestoreImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    viewModel.restore(from: url, context: modelContext, existing: expenses)
                case .failure(let error):
                    viewModel.alertMessage = error.localizedDescription
                }
            }
            .alert("Settings", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .alert("Thank You! ❤️", isPresented: $showingThankYou) {
                Button("You're Welcome") {}
            } message: {
                Text("Your support means a lot and helps keep MyExpenses+ free for everyone.")
            }
            .alert("Support Development", isPresented: Binding(
                get: { tipStore.errorMessage != nil },
                set: { if !$0 { tipStore.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(tipStore.errorMessage ?? "")
            }
            }
        }
    }

    /// Wipes the stored data first, then the preferences. If the store throws,
    /// the preferences are left alone so the user is not stranded with their
    /// settings gone but their expenses still there.
    private func deleteAccount() {
        do {
            try AccountEraser.eraseStoredData(in: modelContext)
        } catch {
            deleteAccountError = error.localizedDescription
            return
        }
        profile.reset()
        viewModel.reset()
        Haptics.success()
    }

    private func tip(_ tier: TipStore.Tier) {
        Task {
            // Products can be empty if the first load was slow or failed (common in
            // the sandbox right after install). Try once more on tap before giving
            // up, so a transient miss doesn't dead-end on an error.
            if tipStore.product(for: tier) == nil {
                await tipStore.loadProducts()
            }
            guard let product = tipStore.product(for: tier) else {
                tipStore.errorMessage = "Tips aren't available right now. Please try again in a moment."
                return
            }
            if await tipStore.tip(product) {
                Haptics.success()
                showingThankYou = true
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    SettingsView()
        .modelContainer(SampleData.previewContainer)
        .environment(UserProfileViewModel())
}
