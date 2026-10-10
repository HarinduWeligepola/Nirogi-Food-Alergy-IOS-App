//
//  Allergen.swift
//  Nirogi (IT23257504-PartA)
//
//  Core value types describing allergens, how severely a user reacts to
//  them, and how a particular ingredient came to be matched.
//
//  These are deliberately plain Swift value types with no SwiftData or
//  SwiftUI dependency, so the safety engine that consumes them can be
//  unit-tested in isolation.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

// MARK: - Severity

/// How badly the user reacts to a given allergen.
///
/// Severity drives the final verdict: a `severe` match always produces
/// "Avoid", whereas a `mild` match only warrants "Caution".
nonisolated enum Severity: String, Codable, CaseIterable, Comparable, Sendable {
    case mild
    case moderate
    case severe

    /// Ordering so severities can be compared and sorted
    /// (`mild < moderate < severe`).
    private var rank: Int {
        switch self {
        case .mild: return 0
        case .moderate: return 1
        case .severe: return 2
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Human-readable label shown in the UI.
    var title: String {
        switch self {
        case .mild: return String(localized: "Mild")
        case .moderate: return String(localized: "Moderate")
        case .severe: return String(localized: "Severe")
        }
    }

    /// Short explanation shown when the user is choosing a severity.
    var explanation: String {
        switch self {
        case .mild: return "Mild discomfort. I prefer to avoid it."
        case .moderate: return "Makes me unwell. I avoid it."
        case .severe: return "Dangerous reaction. Never safe."
        }
    }
}

// MARK: - Allergen rule

/// One line of the user's personal profile: an allergen plus how severely
/// they react to it. A profile is simply a collection of these.
nonisolated struct AllergenRule: Codable, Hashable, Identifiable, Sendable {
    /// Matches `Allergen.id` in the bundled knowledge base.
    var categoryID: String
    var severity: Severity

    var id: String { categoryID }

    init(categoryID: String, severity: Severity) {
        self.categoryID = categoryID
        self.severity = severity
    }
}

// MARK: - Dietary preference

/// Lifestyle or belief-based restrictions, which are handled separately from
/// allergies because they are never medically dangerous — a conflict here is
/// always "Caution" rather than "Avoid".
nonisolated enum DietaryPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case vegetarian
    case vegan
    case halal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegetarian: return String(localized: "Vegetarian")
        case .vegan: return String(localized: "Vegan")
        case .halal: return String(localized: "Halal")
        }
    }

    var symbolName: String {
        switch self {
        case .vegetarian: return "leaf"
        case .vegan: return "carrot"
        case .halal: return "moon.stars"
        }
    }

    /// Knowledge-base allergen IDs that conflict with this preference.
    /// For example anything dairy-derived breaks a vegan diet.
    var conflictingCategoryIDs: [String] {
        switch self {
        case .vegetarian: return ["fish", "shellfish", "maldive_fish", "gelatin"]
        case .vegan: return ["dairy", "egg", "fish", "shellfish", "maldive_fish", "gelatin", "honey"]
        case .halal: return ["pork", "alcohol", "gelatin"]
        }
    }
}

// MARK: - Allergen (knowledge-base entry)

/// A single entry in the bundled allergen knowledge base.
///
/// The `synonyms` array is the heart of the app: it is what lets Nirogi spot
/// "casein" or "whey powder" when the user only told us they avoid dairy.
nonisolated struct Allergen: Codable, Identifiable, Hashable, Sendable {
    let id: String
    /// Display name, e.g. "Dairy".
    let name: String
    /// SF Symbol shown beside the allergen in the profile screen.
    let symbolName: String
    /// Alternative and hidden names that indicate this allergen is present.
    let synonyms: [String]
    /// Phrases that must *not* be treated as this allergen even though they
    /// contain one of its search terms. Without these, "coconut milk" would
    /// raise a false dairy alert because it contains the word "milk".
    let exclusions: [String]
    /// Short plain-English note explaining the link, shown as the "why"
    /// on a result, e.g. "Whey is a milk protein."
    let note: String
    /// Whether this allergen is especially relevant to Sri Lankan products,
    /// used to surface locally important options first in the profile UI.
    let isLocallyCommon: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, symbolName, synonyms, exclusions, note, isLocallyCommon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        symbolName = try c.decodeIfPresent(String.self, forKey: .symbolName) ?? "exclamationmark.triangle"
        synonyms = try c.decode([String].self, forKey: .synonyms)
        exclusions = try c.decodeIfPresent([String].self, forKey: .exclusions) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        isLocallyCommon = try c.decodeIfPresent(Bool.self, forKey: .isLocallyCommon) ?? false
    }

    init(id: String, name: String, symbolName: String = "exclamationmark.triangle",
         synonyms: [String], exclusions: [String] = [],
         note: String = "", isLocallyCommon: Bool = false) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.synonyms = synonyms
        self.exclusions = exclusions
        self.note = note
        self.isLocallyCommon = isLocallyCommon
    }

    /// Every string that should trigger a match for this allergen:
    /// its own name plus all known synonyms, lowercased.
    ///
    /// Sorted longest first so that the most specific term wins — matching
    /// "whey powder" is more informative than matching "whey" alone.
    var allSearchTerms: [String] {
        ([name] + synonyms)
            .map { $0.lowercased() }
            .sorted { $0.count > $1.count }
    }

    /// Exclusion phrases, lowercased for comparison.
    var normalisedExclusions: [String] {
        exclusions.map { $0.lowercased() }
    }
}
