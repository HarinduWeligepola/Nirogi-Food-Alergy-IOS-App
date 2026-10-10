//
//  ModelTests.swift
//  NirogiTests
//
//  Tests for the persistence models and the knowledge base, using an
//  in-memory SwiftData container so nothing touches the real database.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import XCTest
import SwiftData
@testable import IT23257504_PartA

final class ModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeInMemoryContainer()
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Profile rules

    func testSettingARuleAddsIt() {
        let profile = UserProfile()
        profile.setRule(categoryID: "dairy", severity: .moderate)

        XCTAssertEqual(profile.rules.count, 1)
        XCTAssertEqual(profile.severity(for: "dairy"), .moderate)
    }

    /// Setting the same allergen twice must update it rather than
    /// producing two conflicting rules.
    func testSettingARuleTwiceUpdatesInPlace() {
        let profile = UserProfile()
        profile.setRule(categoryID: "dairy", severity: .mild)
        profile.setRule(categoryID: "dairy", severity: .severe)

        XCTAssertEqual(profile.rules.count, 1)
        XCTAssertEqual(profile.severity(for: "dairy"), .severe)
    }

    func testRemovingARule() {
        let profile = UserProfile()
        profile.setRule(categoryID: "peanut", severity: .severe)
        profile.removeRule(categoryID: "peanut")

        XCTAssertTrue(profile.rules.isEmpty)
        XCTAssertNil(profile.severity(for: "peanut"))
    }

    func testTogglingDietaryPreference() {
        let profile = UserProfile()

        profile.toggleDietaryPreference(.vegan)
        XCTAssertEqual(profile.dietaryPreferences, [.vegan])

        profile.toggleDietaryPreference(.vegan)
        XCTAssertTrue(profile.dietaryPreferences.isEmpty)
    }

    /// An unrecognised stored value must be skipped rather than breaking
    /// the whole profile, so an older database still opens.
    func testUnknownDietaryPreferenceIsIgnored() {
        let profile = UserProfile()
        profile.dietaryPreferenceIDs = ["vegan", "something_from_a_future_build"]

        XCTAssertEqual(profile.dietaryPreferences, [.vegan])
    }

    func testHealthLimitsReplaceRatherThanDuplicate() {
        let profile = UserProfile()
        profile.setHealthLimit(HealthLimit(nutrient: .sugar, maxPer100g: 10))
        profile.setHealthLimit(HealthLimit(nutrient: .sugar, maxPer100g: 5))

        XCTAssertEqual(profile.healthLimits.count, 1)
        XCTAssertEqual(profile.healthLimits.first?.maxPer100g, 5)
    }

    // MARK: - Snapshot

    /// The snapshot must carry everything the engine needs, so that the
    /// engine never has to touch a SwiftData model.
    func testSnapshotCarriesTheWholeProfile() {
        let profile = UserProfile()
        profile.setRule(categoryID: "dairy", severity: .severe)
        profile.toggleDietaryPreference(.vegan)
        profile.setHealthLimit(HealthLimit(nutrient: .sugar, maxPer100g: 5))

        let snapshot = profile.snapshot

        XCTAssertEqual(snapshot.severity(for: "dairy"), .severe)
        XCTAssertEqual(snapshot.dietaryPreferences, [.vegan])
        XCTAssertEqual(snapshot.healthLimits.count, 1)
    }

    func testDietaryConflictMapping() {
        let snapshot = ProfileSnapshot(dietaryPreferences: [.vegan])
        let conflicts = snapshot.dietaryConflictSources

        XCTAssertEqual(conflicts["dairy"], .vegan)
        XCTAssertEqual(conflicts["egg"], .vegan)
        XCTAssertNil(conflicts["gluten"], "Gluten does not break a vegan diet")
    }

    // MARK: - Persistence

    @MainActor
    func testProfileIsCreatedOnceAndReused() {
        let profile = ProfileStore.loadOrCreate(in: context)
        profile.displayName = "Harindu"
        try? context.save()

        let again = ProfileStore.loadOrCreate(in: context)

        XCTAssertEqual(again.id, profile.id, "A second call must return the same profile")
        XCTAssertEqual(again.displayName, "Harindu")
    }

    func testScanRecordRoundTrips() throws {
        let record = ScanRecord(
            productName: "Cream Biscuits",
            rawText: "INGREDIENTS: Wheat Flour, Whey Powder.",
            ingredients: ["wheat flour", "whey powder"],
            verdict: .avoid,
            findings: [Finding(matchedText: "whey powder", categoryID: "dairy",
                               categoryName: "Dairy", severity: .severe, kind: .contains,
                               matchType: .synonym, reason: "Whey is a milk protein.",
                               ingredientIndex: 1)])
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ScanRecord>())

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.verdict, .avoid)
        XCTAssertEqual(fetched.first?.findings.first?.matchedText, "whey powder")
    }

    /// An unrecognised stored verdict must fall back to Caution. Failing
    /// towards caution rather than safety is the correct bias for a
    /// health app.
    func testUnknownStoredVerdictFallsBackToCaution() {
        let record = ScanRecord()
        record.verdictRaw = "something_unexpected"

        XCTAssertEqual(record.verdict, .caution)
    }

    func testRecordSummaryListsUniqueAllergens() {
        let record = ScanRecord()
        record.findings = [
            Finding(matchedText: "whey", categoryID: "dairy", categoryName: "Dairy",
                    severity: .severe, kind: .contains, matchType: .synonym,
                    reason: "", ingredientIndex: 0),
            Finding(matchedText: "casein", categoryID: "dairy", categoryName: "Dairy",
                    severity: .severe, kind: .mayContain, matchType: .synonym,
                    reason: "", ingredientIndex: 1)
        ]

        XCTAssertEqual(record.summary, "Dairy", "Duplicate names must be collapsed")
    }

    func testEmptyRecordSummary() {
        XCTAssertEqual(ScanRecord().summary, "No conflicts found")
    }

    // MARK: - Knowledge base

    func testKnowledgeBaseLoads() throws {
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)

        XCTAssertFalse(knowledgeBase.allergens.isEmpty)
        XCTAssertNotNil(knowledgeBase.allergen(id: "dairy"))
        XCTAssertEqual(knowledgeBase.name(for: "maldive_fish"), "Maldive Fish")
    }

    func testAllergenIDsAreUnique() throws {
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)
        let ids = knowledgeBase.allergens.map(\.id)

        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate allergen IDs would shadow each other")
    }

    /// Every category referenced by a dietary preference must exist, or the
    /// preference would silently fail to flag anything.
    func testDietaryPreferenceCategoriesExist() throws {
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)

        for preference in DietaryPreference.allCases {
            for categoryID in preference.conflictingCategoryIDs {
                XCTAssertNotNil(knowledgeBase.allergen(id: categoryID),
                                "\(preference.title) references missing allergen '\(categoryID)'")
            }
        }
    }

    func testSearchTermsAreSortedLongestFirst() throws {
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)
        let dairy = try XCTUnwrap(knowledgeBase.allergen(id: "dairy"))
        let terms = dairy.allSearchTerms

        for index in 1..<terms.count {
            XCTAssertGreaterThanOrEqual(terms[index - 1].count, terms[index].count,
                                        "Longest-match resolution depends on this ordering")
        }
    }

    func testLocallyCommonAllergensArePresent() throws {
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)
        let localIDs = Set(knowledgeBase.locallyCommon.map(\.id))

        XCTAssertTrue(localIDs.contains("maldive_fish"))
        XCTAssertTrue(localIDs.contains("coconut"))
        XCTAssertTrue(localIDs.contains("cashew"))
    }

    // MARK: - Samples

    func testBundledSampleImagesAllLoad() {
        for sample in SampleLabel.all {
            XCTAssertNotNil(sample.image, "Sample image '\(sample.imageName)' is missing")
        }
    }
}
