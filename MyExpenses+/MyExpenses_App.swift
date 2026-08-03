//
//  MyExpenses_App.swift
//  MyExpenses+
//
//  Created by Murali Krishna on 15/07/2026.
//

import SwiftUI
import SwiftData

@main
struct MyExpenses_App: App {
    @State private var userProfile: UserProfileViewModel

    init() {
        // Screenshot seeding must run before the profile reads its stored name.
        // Compiled out of Release builds.
        #if DEBUG
        ScreenshotData.seedIfRequested()
        #endif
        _userProfile = State(initialValue: UserProfileViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userProfile)
        }
        .modelContainer(AppModelContainer.shared)
    }
}
