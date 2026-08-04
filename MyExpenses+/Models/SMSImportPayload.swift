import Foundation

/// Carries clipboard text into `ImportSMSView`. Presenting via `.sheet(item:)` on
/// this — rather than `.sheet(isPresented:)` plus a separate text `@State` — makes
/// the hand-off atomic. The two-state-vars approach can race with the system's
/// paste-permission alert, opening the sheet before the text propagates.
struct SMSImportPayload: Identifiable {
    let id = UUID()
    let text: String
}
