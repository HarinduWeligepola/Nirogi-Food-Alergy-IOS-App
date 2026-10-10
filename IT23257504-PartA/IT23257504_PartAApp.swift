//
//  IT23257504_PartAApp.swift
//  Nirogi (IT23257504-PartA)
//
//  Application entry point.
//
//  Nirogi — නිරෝගී — reads the ingredient list on a food packet using
//  Apple's Vision framework and judges it against the user's own allergen
//  profile, so the same label can be Safe for one person and Avoid for
//  another.
//
//  SE4041 Mobile Application Design and Development, Assignment 02 Part A.
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

@main
struct IT23257504_PartAApp: App {

    /// Services shared by the whole app, built once at launch.
    @State private var appEnvironment = AppEnvironment()

    /// The SwiftData stack backing the profile and scan history.
    private let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                // Jade accent applies to system controls throughout the app.
                .tint(Theme.Palette.jade)
        }
        .modelContainer(container)
    }
}
