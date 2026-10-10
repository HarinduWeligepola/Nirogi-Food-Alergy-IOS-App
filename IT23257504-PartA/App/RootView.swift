//
//  RootView.swift
//  Nirogi (IT23257504-PartA)
//
//  Decides what the user sees first, and hosts the main tab structure.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

/// Entry view: shows onboarding until the safety disclaimer is accepted,
/// then the main app.
struct RootView: View {

    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                if profile.hasAcceptedDisclaimer {
                    MainTabView(profile: profile)
                        .transition(.opacity)
                } else {
                    OnboardingView(profile: profile)
                        .transition(.opacity)
                }
            } else {
                // First launch: the profile is created, then this view
                // re-renders with it.
                ProgressView()
                    .task { _ = ProfileStore.loadOrCreate(in: context) }
            }
        }
        .animation(Theme.Motion.standard, value: profiles.first?.hasAcceptedDisclaimer)
    }
}

// MARK: - Main tabs

/// The app's primary navigation: four tabs, each with its own stack.
struct MainTabView: View {

    let profile: UserProfile

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView(profile: profile)
                }
            }

            Tab("Scan", systemImage: "viewfinder") {
                NavigationStack {
                    ScanView(profile: profile)
                }
            }

            Tab("Places", systemImage: "map.fill") {
                NavigationStack {
                    ScanMapView()
                }
            }

            Tab("Profile", systemImage: "person.crop.circle.fill") {
                NavigationStack {
                    ProfileView(profile: profile)
                }
            }
        }
        .tint(Theme.Palette.jade)
    }
}

// MARK: - Shared background

/// The app's standard screen background.
///
/// Liquid Glass refracts whatever is behind it, so a flat background would
/// leave every card looking grey and lifeless. This soft jade-to-turmeric
/// wash gives the glass something to pick up without competing with the
/// content for attention.
struct NirogiBackground: View {
    var body: some View {
        ZStack {
            Theme.Palette.background

            LinearGradient(
                colors: [
                    Theme.Palette.jade.opacity(0.18),
                    Theme.Palette.turmeric.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the app's standard background behind a screen.
    func nirogiBackground() -> some View {
        background(NirogiBackground())
    }
}
