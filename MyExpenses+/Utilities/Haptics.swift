import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func delete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
