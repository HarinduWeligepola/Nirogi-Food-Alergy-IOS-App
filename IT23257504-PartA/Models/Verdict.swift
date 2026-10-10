//
//  Verdict.swift
//  Nirogi (IT23257504-PartA)
//
//  The result of analysing a label against one user's profile, plus the
//  individual findings that justify it.
//
//  Every verdict carries its evidence. The app never shows a bare red cross:
//  it always shows which word was matched, which of the user's rules it hit,
//  and why those two are connected.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

// MARK: - Verdict

/// Overall safety outcome for one label and one user.
enum Verdict: String, Codable, CaseIterable, Sendable {
    /// Nothing in the label conflicts with the user's profile.
    case safe
    /// Something worth knowing: a mild allergen, a "may contain" warning,
    /// a dietary conflict, or a nutrient over the user's limit.
    case caution
    /// A moderate or severe allergen is present as an actual ingredient.
    case avoid

    /// The word shown on the verdict card.
    var title: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .avoid: return "Avoid"
        }
    }

    /// SF Symbol for this verdict.
    ///
    /// These three symbols have deliberately **different outlines** — seal,
    /// triangle and octagon — so the verdict is still distinguishable in
    /// greyscale, by colour-blind users, or at a glance. Colour alone is
    /// never the only signal.
    var symbolName: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .avoid: return "xmark.octagon.fill"
        }
    }

    /// Asset-catalogue name for the verdict's fill colour.
    var fillColorName: String {
        switch self {
        case .safe: return "VerdictSafe"
        case .caution: return "VerdictCaution"
        case .avoid: return "VerdictAvoid"
        }
    }

    /// Asset-catalogue name for the verdict's text colour, which is darker
    /// in light mode so body copy still clears WCAG AA contrast.
    var textColorName: String {
        switch self {
        case .safe: return "VerdictSafeText"
        case .caution: return "VerdictCautionText"
        case .avoid: return "VerdictAvoidText"
        }
    }

    /// Ranking used when combining several findings: the most serious
    /// finding determines the overall verdict.
    var rank: Int {
        switch self {
        case .safe: return 0
        case .caution: return 1
        case .avoid: return 2
        }
    }

    /// Returns whichever of the two verdicts is more serious.
    static func mostSevere(_ lhs: Verdict, _ rhs: Verdict) -> Verdict {
        lhs.rank >= rhs.rank ? lhs : rhs
    }
}

// MARK: - Match type

/// How an ingredient came to be linked to an allergen. Surfaced in the UI so
/// the user can judge how much to trust a match.
enum MatchType: String, Codable, Sendable {
    /// The allergen's own name appeared, e.g. "peanut".
    case exact
    /// A known alternative name appeared, e.g. "arachis oil" for peanut.
    case synonym
    /// A near-miss, allowing for OCR errors, e.g. "vvhey" for "whey".
    case fuzzy

    var description: String {
        switch self {
        case .exact: return "Exact match"
        case .synonym: return "Known alternative name"
        case .fuzzy: return "Close match (possible scan error)"
        }
    }

    /// Rough confidence weighting, used to sort findings and to warn the
    /// user when a match relies on correcting a likely OCR mistake.
    var confidence: Double {
        switch self {
        case .exact: return 1.0
        case .synonym: return 0.95
        case .fuzzy: return 0.70
        }
    }
}

// MARK: - Finding

/// One piece of evidence behind a verdict.
struct Finding: Codable, Hashable, Identifiable, Sendable {

    /// What kind of problem this finding represents.
    enum Kind: String, Codable, Sendable {
        /// The allergen is listed as an actual ingredient.
        case contains
        /// Cross-contamination wording, e.g. "may contain traces of peanuts".
        case mayContain
        /// A nutrient exceeds a limit the user set, e.g. sugar over 5g/100g.
        case overLimit
        /// Conflicts with a dietary preference rather than an allergy.
        case dietaryConflict

        var title: String {
            switch self {
            case .contains: return "Contains"
            case .mayContain: return "May contain"
            case .overLimit: return "Over your limit"
            case .dietaryConflict: return "Diet conflict"
            }
        }

        var symbolName: String {
            switch self {
            case .contains: return "exclamationmark.octagon.fill"
            case .mayContain: return "exclamationmark.bubble.fill"
            case .overLimit: return "chart.bar.fill"
            case .dietaryConflict: return "leaf.fill"
            }
        }
    }

    var id: UUID
    /// The exact text found on the label, e.g. "whey powder".
    var matchedText: String
    /// Knowledge-base allergen ID, e.g. "dairy".
    var categoryID: String
    /// Display name of the allergen, e.g. "Dairy".
    var categoryName: String
    /// The severity the *user* assigned to this allergen.
    var severity: Severity
    var kind: Kind
    var matchType: MatchType
    /// Plain-English explanation of the link, e.g. "Whey is a milk protein."
    var reason: String
    /// Index of the ingredient this came from, used to highlight it in the
    /// parsed ingredient list on the result screen.
    var ingredientIndex: Int

    init(id: UUID = UUID(), matchedText: String, categoryID: String,
         categoryName: String, severity: Severity, kind: Kind,
         matchType: MatchType, reason: String, ingredientIndex: Int) {
        self.id = id
        self.matchedText = matchedText
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.severity = severity
        self.kind = kind
        self.matchType = matchType
        self.reason = reason
        self.ingredientIndex = ingredientIndex
    }

    /// The verdict this single finding implies, before it is combined with
    /// the others.
    ///
    /// The rules are intentionally conservative:
    /// - a severe or moderate allergen actually present means Avoid
    /// - a mild allergen, a trace warning, a diet clash or an exceeded
    ///   nutrient limit means Caution
    var impliedVerdict: Verdict {
        switch kind {
        case .contains:
            return severity >= .moderate ? .avoid : .caution
        case .mayContain:
            // Trace wording is a manufacturer's hedge, so it only escalates
            // to Avoid for a severe allergy, where the risk is real.
            return severity == .severe ? .avoid : .caution
        case .overLimit, .dietaryConflict:
            return .caution
        }
    }
}

// MARK: - Analysis result

/// Everything the safety engine produces for one label.
struct AnalysisResult: Codable, Hashable, Sendable {
    var verdict: Verdict
    var findings: [Finding]
    /// The cleaned, separated ingredient list the verdict was based on.
    var ingredients: [String]
    /// Nutrient values read from the nutrition table, if one was found.
    var nutrition: [NutrientValue]

    init(verdict: Verdict, findings: [Finding],
         ingredients: [String] = [], nutrition: [NutrientValue] = []) {
        self.verdict = verdict
        self.findings = findings
        self.ingredients = ingredients
        self.nutrition = nutrition
    }

    /// Findings grouped so the result screen can show hard conflicts above
    /// softer warnings.
    var blocking: [Finding] { findings.filter { $0.impliedVerdict == .avoid } }
    var warnings: [Finding] { findings.filter { $0.impliedVerdict == .caution } }

    /// A result with nothing wrong, used when a label is clean.
    static func clean(ingredients: [String], nutrition: [NutrientValue] = []) -> AnalysisResult {
        AnalysisResult(verdict: .safe, findings: [],
                       ingredients: ingredients, nutrition: nutrition)
    }
}
