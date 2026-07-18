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
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileViewModel.self) private var profile
    @State private var viewModel = SettingsViewModel()
    @State private var showingRestoreImporter = false
    @State private var showingEditProfile = false
    @State private var showingCategories = false
    @State private var tipStore = TipStore()
    @State private var showingThankYou = false

    // Read from the bundle so the shipped version is always what's shown.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // Extracted so the Form body stays small enough for the type-checker.
    private var supportSection: some View {
        Section {
            Text("If this app has helped you manage your expenses, you can support future development with a one-time tip. Every contribution helps improve the app and keeps it free for everyone.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(TipStore.Tier.allCases) { tier in
                Button {
                    tip(tier)
                } label: {
                    HStack(spacing: 12) {
                        Text(tier.emoji)
                            .font(.title3)
                            .accessibilityHidden(true)
                        Text(tier.title)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(tipStore.displayPrice(for: tier))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .accessibilityLabel("\(tier.title), \(tipStore.displayPrice(for: tier))")
            }
        } header: {
            Text("❤️ Support Development")
        } footer: {
            Text("Tips are optional and do not unlock any additional features. Thank you for supporting independent development.")
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

                Section("Export") {
                    Button {
                        Haptics.tap()
                        viewModel.exportCSV(expenses)
                    } label: {
                        Label("Export CSV", systemImage: "doc.text")
                    }
                    .disabled(expenses.isEmpty)

                    Button {
                        Haptics.tap()
                        viewModel.exportPDF(expenses)
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                    .disabled(expenses.isEmpty)
                }

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
                aboutSection
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

    private func tip(_ tier: TipStore.Tier) {
        guard let product = tipStore.product(for: tier) else {
            // Products haven't loaded (offline, or the store is unreachable).
            tipStore.errorMessage = "Tips aren't available right now. Please try again in a moment."
            return
        }
        Task {
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
