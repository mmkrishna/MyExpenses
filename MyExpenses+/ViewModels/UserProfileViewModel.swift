import Foundation
import Observation
import SwiftUI

@Observable
final class UserProfileViewModel {
    private let defaults = UserDefaults.standard

    var name: String {
        didSet { defaults.set(name, forKey: "userProfileName") }
    }

    var photoData: Data? {
        didSet { defaults.set(photoData, forKey: "userProfilePhotoData") }
    }

    init() {
        name = defaults.string(forKey: "userProfileName") ?? ""
        photoData = defaults.data(forKey: "userProfilePhotoData")
    }

    var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var displayName: String { hasName ? name : "Welcome" }

    var initials: String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(2)
        let letters = parts.compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 0..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        return hasName ? "\(timeGreeting), \(name.split(separator: " ").first.map(String.init) ?? name)" : timeGreeting
    }
}
