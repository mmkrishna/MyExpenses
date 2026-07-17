import SwiftData

/// Versioned schema for the store.
///
/// Once the app ships, the on-disk schema is fixed: any later model change needs
/// a new `VersionedSchema` plus a `MigrationStage` here, or existing users' data
/// won't open. Declaring this now — while V1 is still the only version — means
/// that future change is a small addition rather than a retrofit.
///
/// To add V2:
///   1. Add `enum SchemaV2: VersionedSchema` with the new model shapes.
///   2. Append it to `MyExpensesMigrationPlan.schemas`.
///   3. Add a `.lightweight` stage (renames/additions) or `.custom` stage
///      (anything needing data to be rewritten) to `stages`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Expense.self, ExpenseCategory.self]
    }
}

enum MyExpensesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// Empty while V1 is the only version: there is nothing to migrate from yet.
    static var stages: [MigrationStage] { [] }
}
