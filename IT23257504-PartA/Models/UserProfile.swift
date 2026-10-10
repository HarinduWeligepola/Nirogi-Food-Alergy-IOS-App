//
//  UserProfile.swift
//  Nirogi (IT23257504-PartA)
//
//  The user's personal safety profile, persisted with SwiftData.
//
//  This is the object that makes Nirogi personal: the same label produces a
//  different verdict depending on what is stored here.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import SwiftData

/// The single profile belonging to the person using the app.
///
/// Nirogi is deliberately single-profile: one phone, one set of allergies.
/// The profile is created on first launch and edited from the Profile tab.
@Model
final class UserProfile {

    /// Stable identifier, used to fetch the one and only profile.
    var id: UUID = UUID()

    /// Optional display name, shown on the home screen greeting.
    var displayName: String = ""

    /// The user's allergen rules. Stored as Codable value types, which
    /// SwiftData persists inline — appropriate here because the list is
    /// small and always loaded together with the profile.
    var rules: [AllergenRule] = []

    /// Lifestyle restrictions, stored as raw values for forward
    /// compatibility: an unknown value decoded from an older build is
    /// simply ignored rather than failing the whole fetch.
    var dietaryPreferenceIDs: [String] = []

    /// Personal nutrient ceilings checked against the nutrition table.
    var healthLimits: [HealthLimit] = []

    /// Whether the user has read the "not medical advice" disclaimer.
    /// Gating the app on this is both an ethical and a usability decision.
    var hasAcceptedDisclaimer: Bool = false

    /// Language chosen in onboarding: "en", "si" or "ta". `nil` means
    /// follow the system language.
    var preferredLanguageCode: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(displayName: String = "",
         rules: [AllergenRule] = [],
         dietaryPreferenceIDs: [String] = [],
         healthLimits: [HealthLimit] = [],
         hasAcceptedDisclaimer: Bool = false,
         preferredLanguageCode: String? = nil) {
        self.id = UUID()
        self.displayName = displayName
        self.rules = rules
        self.dietaryPreferenceIDs = dietaryPreferenceIDs
        self.healthLimits = healthLimits
        self.hasAcceptedDisclaimer = hasAcceptedDisclaimer
        self.preferredLanguageCode = preferredLanguageCode
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Derived values

    /// Dietary preferences as strongly typed values, skipping any raw
    /// strings this build does not recognise.
    var dietaryPreferences: [DietaryPreference] {
        dietaryPreferenceIDs.compactMap { DietaryPreference(rawValue: $0) }
    }

    /// True when the user has told us nothing yet, so the app can prompt
    /// them to set up their profile before scanning.
    var isEmpty: Bool {
        rules.isEmpty && dietaryPreferenceIDs.isEmpty && healthLimits.isEmpty
    }

    /// Severity assigned to a given allergen, or `nil` if the user has not
    /// flagged it at all.
    func severity(for categoryID: String) -> Severity? {
        rules.first { $0.categoryID == categoryID }?.severity
    }

    // MARK: - Mutation

    /// Adds or updates a rule, keeping exactly one entry per allergen.
    func setRule(categoryID: String, severity: Severity) {
        if let index = rules.firstIndex(where: { $0.categoryID == categoryID }) {
            rules[index].severity = severity
        } else {
            rules.append(AllergenRule(categoryID: categoryID, severity: severity))
        }
        updatedAt = Date()
    }

    /// Removes a rule entirely, meaning the user no longer avoids it.
    func removeRule(categoryID: String) {
        rules.removeAll { $0.categoryID == categoryID }
        updatedAt = Date()
    }

    func toggleDietaryPreference(_ preference: DietaryPreference) {
        if let index = dietaryPreferenceIDs.firstIndex(of: preference.rawValue) {
            dietaryPreferenceIDs.remove(at: index)
        } else {
            dietaryPreferenceIDs.append(preference.rawValue)
        }
        updatedAt = Date()
    }

    func setHealthLimit(_ limit: HealthLimit) {
        if let index = healthLimits.firstIndex(where: { $0.nutrient == limit.nutrient }) {
            healthLimits[index] = limit
        } else {
            healthLimits.append(limit)
        }
        updatedAt = Date()
    }

    func removeHealthLimit(for nutrient: Nutrient) {
        healthLimits.removeAll { $0.nutrient == nutrient }
        updatedAt = Date()
    }

    // MARK: - Snapshot

    /// Converts this SwiftData model into an immutable value type for the
    /// safety engine.
    ///
    /// Passing a snapshot rather than the model keeps the engine free of any
    /// SwiftData dependency, which is what makes it trivially unit-testable
    /// and safe to run off the main actor.
    var snapshot: ProfileSnapshot {
        ProfileSnapshot(rules: rules,
                        dietaryPreferences: dietaryPreferences,
                        healthLimits: healthLimits)
    }
}

// MARK: - Profile snapshot

/// An immutable copy of everything the safety engine needs to know about
/// the user. Contains no persistence or UI types.
struct ProfileSnapshot: Hashable, Sendable {
    var rules: [AllergenRule]
    var dietaryPreferences: [DietaryPreference]
    var healthLimits: [HealthLimit]

    init(rules: [AllergenRule] = [],
         dietaryPreferences: [DietaryPreference] = [],
         healthLimits: [HealthLimit] = []) {
        self.rules = rules
        self.dietaryPreferences = dietaryPreferences
        self.healthLimits = healthLimits
    }

    func severity(for categoryID: String) -> Severity? {
        rules.first { $0.categoryID == categoryID }?.severity
    }

    /// Allergen IDs the user must avoid because of a dietary preference,
    /// mapped to the preference responsible for it.
    var dietaryConflictSources: [String: DietaryPreference] {
        var map: [String: DietaryPreference] = [:]
        for preference in dietaryPreferences {
            for categoryID in preference.conflictingCategoryIDs where map[categoryID] == nil {
                map[categoryID] = preference
            }
        }
        return map
    }
}
