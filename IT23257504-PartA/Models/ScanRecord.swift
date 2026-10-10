//
//  ScanRecord.swift
//  Nirogi (IT23257504-PartA)
//
//  A saved scan: the photo, the text we read from it, and the verdict we
//  reached. Persisted with SwiftData so history survives app restarts.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import SwiftData

/// One completed scan, stored in the user's history.
@Model
final class ScanRecord {

    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// User-editable product name. Defaults to a generated name such as
    /// "Scan at 14:32" until the user renames it.
    var productName: String = ""

    /// Full text Vision read from the photo, kept so the user can inspect
    /// exactly what the OCR saw when a verdict looks wrong.
    var rawText: String = ""

    /// Ingredient list after parsing, in label order.
    var ingredients: [String] = []

    /// Stored as a raw string rather than the enum directly, so that adding
    /// a new verdict case in a future build cannot break decoding of
    /// existing records.
    var verdictRaw: String = Verdict.safe.rawValue

    /// The evidence behind the verdict.
    var findings: [Finding] = []

    /// Nutrient values read from the nutrition table, if present.
    var nutrition: [NutrientValue] = []

    /// The label photo. `.externalStorage` tells SwiftData to keep the image
    /// as a file on disk rather than inside the database, which keeps
    /// queries fast as history grows — an explicit performance decision.
    @Attribute(.externalStorage) var imageData: Data?

    /// Barcode read from the packet, when one was detected. Lets a repeat
    /// scan of the same product be recognised instantly.
    var barcode: String?

    // MARK: Place the scan happened (optional, for the map screen)

    var latitude: Double?
    var longitude: Double?
    /// Shop or place name the user attached to this scan.
    var placeName: String?

    init(productName: String = "",
         rawText: String = "",
         ingredients: [String] = [],
         verdict: Verdict = .safe,
         findings: [Finding] = [],
         nutrition: [NutrientValue] = [],
         imageData: Data? = nil,
         barcode: String? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.productName = productName
        self.rawText = rawText
        self.ingredients = ingredients
        self.verdictRaw = verdict.rawValue
        self.findings = findings
        self.nutrition = nutrition
        self.imageData = imageData
        self.barcode = barcode
    }

    // MARK: - Derived values

    /// The stored verdict, falling back to `.caution` if the raw string is
    /// unrecognised. Failing towards caution rather than safety is the
    /// correct bias for a health app.
    var verdict: Verdict {
        get { Verdict(rawValue: verdictRaw) ?? .caution }
        set { verdictRaw = newValue.rawValue }
    }

    /// Whether the user has a saved location for this scan.
    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// Short summary shown in the history list, e.g. "Contains Dairy, Peanut".
    var summary: String {
        guard !findings.isEmpty else { return "No conflicts found" }
        let names = findings.map(\.categoryName)
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        return unique.prefix(3).joined(separator: ", ")
    }

    /// Applies the engine's output to this record.
    func apply(_ result: AnalysisResult) {
        verdict = result.verdict
        findings = result.findings
        ingredients = result.ingredients
        nutrition = result.nutrition
    }

    /// Generates a default product name from the scan time, used when the
    /// user has not named the product themselves.
    static func defaultName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return "Scan \(formatter.string(from: date))"
    }
}
