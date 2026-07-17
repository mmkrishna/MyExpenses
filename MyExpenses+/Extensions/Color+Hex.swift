import SwiftUI

extension Color {
    /// Creates a colour from a "#RRGGBB" string, falling back to grey so a bad
    /// stored value can never crash or render invisibly.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            self = .gray
            return
        }

        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }

    /// "#RRGGBB" for persisting a user-picked colour.
    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        // Grayscale colours report 2 components rather than 4.
        let red: CGFloat, green: CGFloat, blue: CGFloat
        if components.count >= 3 {
            red = components[0]; green = components[1]; blue = components[2]
        } else {
            red = components[0]; green = components[0]; blue = components[0]
        }
        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
