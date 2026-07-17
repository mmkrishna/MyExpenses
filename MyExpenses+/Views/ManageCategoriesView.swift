import SwiftData
import SwiftUI

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\ExpenseCategory.sortOrder), SortDescriptor(\ExpenseCategory.name)])
    private var categories: [ExpenseCategory]

    @State private var editing: ExpenseCategory?
    @State private var creatingNew = false

    private var builtIns: [ExpenseCategory] { categories.filter(\.isBuiltIn) }
    private var custom: [ExpenseCategory] { categories.filter { !$0.isBuiltIn } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if custom.isEmpty {
                        Text("No categories of your own yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(custom) { category in
                        row(category)
                    }
                    .onDelete(perform: deleteCustom)
                } header: {
                    Text("Your Categories")
                } footer: {
                    Text("Deleting a category keeps its expenses — they just become uncategorised.")
                }

                Section("Built-in") {
                    ForEach(builtIns) { category in
                        row(category)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        creatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Category")
                }
            }
            .sheet(item: $editing) { category in
                EditCategoryView(category: category)
            }
            .sheet(isPresented: $creatingNew) {
                EditCategoryView(category: nil)
            }
        }
    }

    private func row(_ category: ExpenseCategory) -> some View {
        Button {
            editing = category
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(category.color, in: Circle())
                Text(category.name)
                    .foregroundStyle(.primary)
                Spacer()
                if !category.isBuiltIn {
                    Text("Custom")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Built-ins are protected, so only the custom list is deletable.
    private func deleteCustom(at offsets: IndexSet) {
        Haptics.delete()
        for index in offsets {
            modelContext.delete(custom[index])
        }
        try? modelContext.save()
    }
}

/// Add or edit a single category.
private struct EditCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: ExpenseCategory?

    @State private var name: String = ""
    @State private var symbolName: String = "tag.fill"
    @State private var color: Color = .blue

    /// A small, deliberately curated set — an open SF Symbol field would mostly
    /// produce blank icons from typos.
    private let symbolChoices = [
        "tag.fill", "cart.fill", "fork.knife", "cup.and.saucer.fill", "house.fill",
        "car.fill", "bus.fill", "airplane", "bag.fill", "gift.fill",
        "heart.fill", "cross.case.fill", "pawprint.fill", "graduationcap.fill",
        "book.fill", "gamecontroller.fill", "film.fill", "music.note",
        "dumbbell.fill", "scissors", "wrench.and.screwdriver.fill", "bolt.fill",
        "wifi", "phone.fill", "creditcard.fill", "banknote.fill",
        "shield.fill", "doc.text.fill", "figure.and.child.holdinghands", "leaf.fill",
    ]

    private var isEditing: Bool { category != nil }
    private var isBuiltIn: Bool { category?.isBuiltIn ?? false }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }

                Section("Colour") {
                    ColorPicker("Colour", selection: $color, supportsOpacity: false)
                    HStack(spacing: 12) {
                        Image(systemName: symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(color, in: Circle())
                        Text(trimmedName.isEmpty ? "Preview" : trimmedName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(symbolChoices, id: \.self) { symbol in
                            Button {
                                Haptics.selection()
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(symbol == symbolName ? .white : Color.accentColor)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        symbol == symbolName ? Color.accentColor : Color.accentColor.opacity(0.12),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isBuiltIn {
                    Section {
                        Text("Built-in categories can be renamed and recoloured, but not deleted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let category else { return }
        name = category.name
        symbolName = category.symbolName
        color = category.color
    }

    private func save() {
        if let category {
            category.name = trimmedName
            category.symbolName = symbolName
            category.colorHex = color.hexString
        } else {
            let nextOrder = (CategoryStore.all(in: modelContext).map(\.sortOrder).max() ?? 0) + 1
            modelContext.insert(
                ExpenseCategory(
                    name: trimmedName,
                    symbolName: symbolName,
                    colorHex: color.hexString,
                    isBuiltIn: false,
                    sortOrder: nextOrder
                )
            )
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

#Preview {
    ManageCategoriesView()
        .modelContainer(SampleData.previewContainer)
}
