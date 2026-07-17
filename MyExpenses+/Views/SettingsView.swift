// SettingsView.swift
// Expense Tracker
//
// Created by Murali Krishna on 15/07/2026.

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
            }
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
