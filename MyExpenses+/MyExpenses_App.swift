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
    @State private var userProfile = UserProfileViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userProfile)
        }
        .modelContainer(AppModelContainer.shared)
    }
}
