//
//  Nutrition.swift
//  Nirogi (IT23257504-PartA)
//
//  Types for the numeric half of a label. Reading the nutrition table is
//  what lets Nirogi answer questions an allergen list cannot, such as
//  "is this too sugary for me?" for a user managing diabetes.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

// MARK: - Nutrient

/// A nutrient Nirogi can read from a nutrition table and check against a
/// personal limit.
enum Nutrient: String, Codable, CaseIterable, Identifiable, Sendable {
    case sugar
    case salt
    case saturatedFat
    case energy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sugar: return String(localized: "Sugar")
        case .salt: return String(localized: "Salt / Sodium")
        case .saturatedFat: return String(localized: "Saturated Fat")
        case .energy: return String(localized: "Energy")
        }
    }

    var symbolName: String {
        switch self {
        case .sugar: return "cube.fill"
        case .salt: return "drop.fill"
        case .saturatedFat: return "circle.hexagongrid.fill"
        case .energy: return "flame.fill"
        }
    }

    /// Unit the value is reported in, per 100g of product.
    var unit: String {
        switch self {
        case .sugar, .saturatedFat: return "g"
        case .salt: return "mg"
        case .energy: return "kcal"
        }
    }

    /// Words that may introduce this nutrient in a nutrition table. Labels
    /// are inconsistent, so each nutrient needs several spellings.
    var tableKeywords: [String] {
        switch self {
        case .sugar:
            return ["sugar", "sugars", "total sugar", "of which sugars", "carbohydrate of which sugars"]
        case .salt:
            return ["salt", "sodium", "natrium"]
        case .saturatedFat:
            return ["saturated fat", "saturates", "of which saturates", "saturated fatty acids"]
        case .energy:
            return ["energy", "calories", "kcal", "energy value"]
        }
    }

    /// A sensible starting limit per 100g, offered as a default when the
    /// user first adds this nutrient to their profile. Based on widely used
    /// front-of-pack "high in" thresholds.
    var suggestedLimitPer100g: Double {
        switch self {
        case .sugar: return 22.5
        case .salt: return 1500
        case .saturatedFat: return 5.0
        case .energy: return 400
        }
    }
}

// MARK: - Nutrient value

/// One nutrient value as read from a label's nutrition table.
struct NutrientValue: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var nutrient: Nutrient
    /// Amount per 100g, normalised to the nutrient's `unit`.
    var amountPer100g: Double
    /// The raw text this was parsed from, kept so the user can check our
    /// reading against the photo.
    var sourceText: String

    init(id: UUID = UUID(), nutrient: Nutrient,
         amountPer100g: Double, sourceText: String) {
        self.id = id
        self.nutrient = nutrient
        self.amountPer100g = amountPer100g
        self.sourceText = sourceText
    }

    /// Value formatted for display, e.g. "22.5 g".
    var displayAmount: String {
        let rounded = (amountPer100g * 10).rounded() / 10
        let number = rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return "\(number) \(nutrient.unit)"
    }
}

// MARK: - Health limit

/// A ceiling the user sets for a nutrient. Exceeding it produces a Caution
/// finding rather than an Avoid, since this is a preference rather than a
/// medical danger.
struct HealthLimit: Codable, Hashable, Identifiable, Sendable {
    var nutrient: Nutrient
    /// Maximum acceptable amount per 100g, in the nutrient's unit.
    var maxPer100g: Double

    var id: String { nutrient.rawValue }

    init(nutrient: Nutrient, maxPer100g: Double) {
        self.nutrient = nutrient
        self.maxPer100g = maxPer100g
    }

    /// Convenience constructor using the nutrient's suggested default.
    static func suggested(for nutrient: Nutrient) -> HealthLimit {
        HealthLimit(nutrient: nutrient, maxPer100g: nutrient.suggestedLimitPer100g)
    }

    var displayLimit: String {
        let rounded = (maxPer100g * 10).rounded() / 10
        let number = rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        return "\(number) \(nutrient.unit)"
    }
}
