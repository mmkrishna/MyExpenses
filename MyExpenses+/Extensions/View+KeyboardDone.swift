import SwiftUI

extension View {
    /// Adds a "Done" button to the keyboard accessory bar.
    ///
    /// Some keyboards have no way to dismiss themselves: `.decimalPad` has no
    /// return key at all, and in a multi-line `TextEditor`/`TextField` the return
    /// key inserts a newline. Without this the keyboard can get stuck on screen.
    ///
    /// Resigns the first responder rather than clearing a specific `FocusState`,
    /// so one modifier covers every field in the view.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}
