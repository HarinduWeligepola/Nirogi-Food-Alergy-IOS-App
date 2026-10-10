//
//  AllergenKnowledgeBase.swift
//  Nirogi (IT23257504-PartA)
//
//  Loads and indexes the bundled allergen knowledge base.
//
//  The knowledge base is what lets Nirogi recognise a hidden allergen: the
//  user says "dairy" and the app knows to look for casein, whey and ghee.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

/// Immutable, pre-indexed store of allergen definitions loaded from
/// `allergens.json`.
///
/// Loading happens once at launch; lookups afterwards are dictionary hits
/// rather than repeated array scans, which keeps analysis fast even as the
/// synonym list grows past three hundred entries.
struct AllergenKnowledgeBase: Sendable {

    /// Every allergen, in the order defined by the JSON file.
    let allergens: [Allergen]

    /// Fast lookup by allergen ID.
    private let byID: [String: Allergen]

    // MARK: - Init

    init(allergens: [Allergen]) {
        self.allergens = allergens
        self.byID = Dictionary(uniqueKeysWithValues: allergens.map { ($0.id, $0) })
    }

    // MARK: - Loading

    /// Errors that can occur while loading the knowledge base.
    enum LoadError: LocalizedError {
        case fileNotFound
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "allergens.json is missing from the app bundle."
            case .decodingFailed(let detail):
                return "Could not read the allergen database: \(detail)"
            }
        }
    }

    /// Shape of the JSON file, used only for decoding.
    private struct Payload: Decodable {
        let version: Int
        let allergens: [Allergen]
    }

    /// Loads the knowledge base from the given bundle.
    /// - Throws: `LoadError` if the file is missing or malformed.
    static func load(from bundle: Bundle = .main) throws -> AllergenKnowledgeBase {
        guard let url = bundle.url(forResource: "allergens", withExtension: "json") else {
            throw LoadError.fileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return AllergenKnowledgeBase(allergens: payload.allergens)
        } catch {
            throw LoadError.decodingFailed(error.localizedDescription)
        }
    }

    /// Loads the knowledge base, falling back to an empty one rather than
    /// crashing.
    ///
    /// A missing database is a developer error, not a user error, so in
    /// release builds the app degrades to "no allergens known" — which is
    /// visibly wrong but safe — instead of terminating.
    static func loadOrEmpty(from bundle: Bundle = .main) -> AllergenKnowledgeBase {
        do {
            return try load(from: bundle)
        } catch {
            assertionFailure("Allergen knowledge base failed to load: \(error)")
            return AllergenKnowledgeBase(allergens: [])
        }
    }

    // MARK: - Lookup

    /// Returns the allergen with the given ID, if it exists.
    func allergen(id: String) -> Allergen? {
        byID[id]
    }

    /// Display name for an allergen ID, falling back to the raw ID so the
    /// UI always has something to show.
    func name(for id: String) -> String {
        byID[id]?.name ?? id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Allergens especially relevant to Sri Lankan products, surfaced first
    /// in the profile screen because they are the ones foreign apps miss.
    var locallyCommon: [Allergen] {
        allergens.filter(\.isLocallyCommon)
    }

    /// The remaining allergens, shown below the local ones.
    var others: [Allergen] {
        allergens.filter { !$0.isLocallyCommon }
    }

    /// Total number of search terms indexed, shown in the About screen as a
    /// measure of the database's coverage.
    var searchTermCount: Int {
        allergens.reduce(0) { $0 + $1.synonyms.count + 1 }
    }
}
