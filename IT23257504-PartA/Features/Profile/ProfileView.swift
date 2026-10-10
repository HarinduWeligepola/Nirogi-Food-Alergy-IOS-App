//
//  ProfileView.swift
//  Nirogi (IT23257504-PartA)
//
//  Where the user tells Nirogi what to watch for. Editing anything here
//  changes how every future scan — and every saved scan — is judged.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

struct ProfileView: View {

    @Bindable var profile: UserProfile

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var showAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                nameCard
                dietaryCard
                limitsCard

                SectionHeading(text: "Allergens", symbolName: "exclamationmark.triangle")

                if !searchText.isEmpty {
                    allergenSection(title: "Results", allergens: searchResults)
                } else {
                    allergenSection(title: "Common in Sri Lanka",
                                    allergens: appEnvironment.knowledgeBase.locallyCommon)
                    allergenSection(title: "Others",
                                    allergens: appEnvironment.knowledgeBase.others)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .nirogiBackground()
        .navigationTitle("Profile")
        .searchable(text: $searchText, prompt: "Search allergens")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAbout = true } label: {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    // MARK: - Cards

    private var nameCard: some View {
        GlassCard(title: "Your name", symbolName: "person.fill") {
            TextField("Optional", text: $profile.displayName)
                .textFieldStyle(.plain)
                .padding(Theme.Spacing.xs)
                .background(Theme.Palette.surface.opacity(0.6), in: .rect(cornerRadius: Theme.Radius.sm))
                .onChange(of: profile.displayName) { _, _ in save() }
        }
    }

    private var dietaryCard: some View {
        GlassCard(title: "Diet", symbolName: "leaf.fill") {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(DietaryPreference.allCases) { preference in
                    Toggle(isOn: binding(for: preference)) {
                        Label(preference.title, systemImage: preference.symbolName)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.ink)
                    }
                    .tint(Theme.Palette.jade)
                }
            }
        }
    }

    private var limitsCard: some View {
        GlassCard(title: "Nutrition limits", symbolName: "chart.bar.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Flag products that exceed these amounts per 100g.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)

                ForEach(Nutrient.allCases) { nutrient in
                    limitRow(for: nutrient)
                }
            }
        }
    }

    private func limitRow(for nutrient: Nutrient) -> some View {
        let limit = profile.healthLimits.first { $0.nutrient == nutrient }

        return VStack(spacing: Theme.Spacing.xxs) {
            Toggle(isOn: Binding(
                get: { limit != nil },
                set: { isOn in
                    if isOn {
                        profile.setHealthLimit(.suggested(for: nutrient))
                    } else {
                        profile.removeHealthLimit(for: nutrient)
                    }
                    save()
                }
            )) {
                Label(nutrient.title, systemImage: nutrient.symbolName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.ink)
            }
            .tint(Theme.Palette.turmeric)

            if let limit {
                HStack {
                    Text("Maximum")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)

                    Slider(
                        value: Binding(
                            get: { limit.maxPer100g },
                            set: { newValue in
                                profile.setHealthLimit(HealthLimit(nutrient: nutrient, maxPer100g: newValue))
                                save()
                            }
                        ),
                        in: sliderRange(for: nutrient),
                        step: sliderStep(for: nutrient)
                    )
                    .tint(Theme.Palette.turmeric)

                    Text(limit.displayLimit)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.Palette.ink)
                        .frame(minWidth: 62, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(nutrient.title) limit")
                .accessibilityValue(limit.displayLimit)
            }
        }
    }

    /// Sensible slider bounds per nutrient, since their units differ by
    /// orders of magnitude.
    private func sliderRange(for nutrient: Nutrient) -> ClosedRange<Double> {
        switch nutrient {
        case .sugar, .saturatedFat: return 0...50
        case .salt: return 0...3000
        case .energy: return 0...900
        }
    }

    private func sliderStep(for nutrient: Nutrient) -> Double {
        switch nutrient {
        case .sugar, .saturatedFat: return 0.5
        case .salt: return 50
        case .energy: return 10
        }
    }

    private func allergenSection(title: String, allergens: [Allergen]) -> some View {
        GlassCard(title: title, symbolName: nil) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(allergens) { allergen in
                    AllergenRuleRow(
                        allergen: allergen,
                        severity: profile.severity(for: allergen.id),
                        onChange: { newSeverity in
                            if let newSeverity {
                                profile.setRule(categoryID: allergen.id, severity: newSeverity)
                            } else {
                                profile.removeRule(categoryID: allergen.id)
                            }
                            save()
                        })

                    if allergen.id != allergens.last?.id {
                        Divider().overlay(Theme.Palette.hairline)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var searchResults: [Allergen] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return appEnvironment.knowledgeBase.allergens }

        // Searching synonyms too means typing "casein" finds Dairy, which
        // is how a user who read a confusing label would actually search.
        return appEnvironment.knowledgeBase.allergens.filter { allergen in
            allergen.allSearchTerms.contains { $0.contains(query) }
        }
    }

    private func binding(for preference: DietaryPreference) -> Binding<Bool> {
        Binding(
            get: { profile.dietaryPreferenceIDs.contains(preference.rawValue) },
            set: { _ in
                profile.toggleDietaryPreference(preference)
                save()
            }
        )
    }

    private func save() {
        profile.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - Allergen row

/// One allergen with its severity selector.
struct AllergenRuleRow: View {

    let allergen: Allergen
    let severity: Severity?
    let onChange: (Severity?) -> Void

    private var isOn: Bool { severity != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Toggle(isOn: Binding(
                get: { isOn },
                set: { newValue in
                    // Default to moderate: cautious by default is the safer
                    // starting point for a health app.
                    onChange(newValue ? .moderate : nil)
                }
            )) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: allergen.symbolName)
                        .foregroundStyle(isOn ? Theme.Palette.jade : Theme.Palette.inkMuted)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(allergen.name)
                            .font(.body.weight(isOn ? .semibold : .regular))
                            .foregroundStyle(Theme.Palette.ink)

                        Text("\(allergen.synonyms.count) hidden names known")
                            .font(.caption2)
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
            }
            .tint(Theme.Palette.jade)

            if let severity {
                Picker("Severity", selection: Binding(
                    get: { severity },
                    set: { onChange($0) }
                )) {
                    ForEach(Severity.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(severity.explanation)
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
        }
        .animation(Theme.Motion.quick, value: isOn)
    }
}

// MARK: - About

/// Explains how the app works and repeats the safety disclaimer.
struct AboutView: View {

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(.rect(cornerRadius: Theme.Radius.md))
                        .accessibilityHidden(true)

                    Text("Nirogi · නිරෝගී")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Palette.ink)

                    GlassCard(title: "How it works", symbolName: "gearshape.fill") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            aboutLine("1", "Apple's Vision framework reads the label text on your device.")
                            aboutLine("2", "The text is split into individual ingredients.")
                            aboutLine("3", "Each ingredient is checked against \(appEnvironment.knowledgeBase.searchTermCount) known names, including hidden ones.")
                            aboutLine("4", "Matches are compared with your profile to produce a verdict.")
                        }
                    }

                    GlassCard(title: "Privacy", symbolName: "lock.shield.fill") {
                        Text("Everything happens on this device. Your photos, your allergies and your scan history are never uploaded.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GlassCard(title: "Important", symbolName: "hand.raised.fill",
                              tint: Color("VerdictCaution")) {
                        Text("Nirogi assists with reading labels. It is not medical advice, and scanning can misread text. Always check the packet yourself, especially for a severe allergy.")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Created by Harindu Weligepola · IT23257504\nSE4041 Mobile Application Design and Development")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .nirogiBackground()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func aboutLine(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.Palette.jade, in: .circle)

            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
