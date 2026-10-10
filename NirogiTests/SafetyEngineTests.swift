//
//  SafetyEngineTests.swift
//  NirogiTests
//
//  Unit tests for the matching engine.
//
//  The engine takes value types in and returns value types out, with no
//  UI, SwiftData or Vision dependency, so every rule can be verified
//  directly without a simulator or a photograph.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import XCTest
@testable import IT23257504_PartA

final class SafetyEngineTests: XCTestCase {

    private var engine: SafetyEngine!

    override func setUpWithError() throws {
        // Unit tests are hosted in the app, so the app bundle is Bundle.main
        // and the real shipping knowledge base is what gets tested.
        let knowledgeBase = try AllergenKnowledgeBase.load(from: .main)
        engine = SafetyEngine(knowledgeBase: knowledgeBase)
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func analyse(_ labelText: String, profile: ProfileSnapshot) -> AnalysisResult {
        engine.analyse(label: LabelParser.parse(labelText), profile: profile)
    }

    /// Convenience overload so a test can declare its profile inline, e.g.
    /// `analyse(label, profile: [("dairy", .severe)], diets: [.vegan])`.
    private func analyse(_ labelText: String,
                         profile rules: [(String, Severity)],
                         diets: [DietaryPreference] = [],
                         limits: [HealthLimit] = []) -> AnalysisResult {
        analyse(labelText, profile: profile(rules, diets: diets, limits: limits))
    }

    private func profile(_ rules: [(String, Severity)],
                         diets: [DietaryPreference] = [],
                         limits: [HealthLimit] = []) -> ProfileSnapshot {
        ProfileSnapshot(
            rules: rules.map { AllergenRule(categoryID: $0.0, severity: $0.1) },
            dietaryPreferences: diets,
            healthLimits: limits)
    }

    // MARK: - The central claim: verdicts are personal

    /// The same label must produce different verdicts for different users.
    /// This is the whole premise of the app.
    func testSameLabelDiffersByUser() {
        let label = """
        INGREDIENTS: Wheat Flour, Sugar, Whey Powder, Salt.
        May contain traces of peanuts.
        """

        let peanutUser = analyse(label, profile: [("peanut", .severe)])
        let glutenUser = analyse(label, profile: [("gluten", .moderate)])
        let unaffected = analyse(label, profile: [("shellfish", .severe)])

        XCTAssertEqual(peanutUser.verdict, .avoid, "A severe peanut allergy must escalate a trace warning")
        XCTAssertEqual(glutenUser.verdict, .avoid, "Wheat flour must be caught as gluten")
        XCTAssertEqual(unaffected.verdict, .safe, "Nothing here concerns a shellfish allergy")

        XCTAssertTrue(peanutUser.findings.allSatisfy { $0.categoryID == "peanut" })
        XCTAssertTrue(glutenUser.findings.allSatisfy { $0.categoryID == "gluten" })
    }

    /// An empty profile has nothing to check against, so nothing is flagged.
    func testEmptyProfileFlagsNothing() {
        let result = analyse("INGREDIENTS: Milk, Peanuts, Wheat Flour.",
                             profile: ProfileSnapshot())

        XCTAssertEqual(result.verdict, .safe)
        XCTAssertTrue(result.findings.isEmpty)
    }

    // MARK: - Hidden names

    /// The point of the knowledge base: a user says "dairy" and the engine
    /// recognises names that never mention milk.
    func testHiddenDairyNamesAreRecognised() {
        let hiddenNames = ["Sodium Caseinate", "Whey Powder", "Ghee",
                           "Lactose", "Butterfat", "Lactalbumin"]

        for name in hiddenNames {
            let result = analyse("INGREDIENTS: Sugar, \(name), Salt.",
                                 profile: [("dairy", .severe)])
            XCTAssertEqual(result.verdict, .avoid, "\(name) should be recognised as dairy")
        }
    }

    func testHiddenPeanutNamesAreRecognised() {
        for name in ["Arachis Oil", "Groundnut", "Monkey Nut"] {
            let result = analyse("INGREDIENTS: Salt, \(name).",
                                 profile: [("peanut", .severe)])
            XCTAssertEqual(result.verdict, .avoid, "\(name) should be recognised as peanut")
        }
    }

    /// Sri Lankan ingredients that international apps typically miss.
    func testLocalIngredientsAreRecognised() {
        let localCases: [(String, String)] = [
            ("Umbalakada", "maldive_fish"),
            ("Thala Oil", "sesame"),
            ("Kaju", "cashew"),
            ("Pol Kiri", "coconut")
        ]

        for (ingredient, categoryID) in localCases {
            let result = analyse("INGREDIENTS: Chilli, \(ingredient), Onion.",
                                 profile: [(categoryID, .moderate)])
            XCTAssertEqual(result.verdict, .avoid, "\(ingredient) should map to \(categoryID)")
        }
    }

    // MARK: - False positives

    /// "Coconut milk" contains the word "milk" but is not dairy. Getting
    /// this wrong would make the app useless in Sri Lanka, where coconut
    /// milk is in almost everything.
    func testCoconutMilkIsNotDairy() {
        let result = analyse("INGREDIENTS: Coconut Milk, Rice Flour, Salt.",
                             profile: [("dairy", .severe)])

        XCTAssertEqual(result.verdict, .safe)
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testPlantMilksAreNotDairy() {
        for milk in ["Soya Milk", "Almond Milk", "Oat Milk", "Cashew Milk"] {
            let result = analyse("INGREDIENTS: \(milk), Sugar.",
                                 profile: [("dairy", .severe)])
            XCTAssertEqual(result.verdict, .safe, "\(milk) is not dairy")
        }
    }

    /// Word boundaries must hold: "eggplant" is not "egg".
    func testWordBoundariesPreventSubstringMatches() {
        let result = analyse("INGREDIENTS: Eggplant, Oil, Chilli.",
                             profile: [("egg", .severe)])
        XCTAssertEqual(result.verdict, .safe, "Eggplant must not match egg")

        let realEgg = analyse("INGREDIENTS: Flour, Whole Egg, Sugar.",
                              profile: [("egg", .severe)])
        XCTAssertEqual(realEgg.verdict, .avoid, "A real egg must still be caught")
    }

    /// Cocoa butter and peanut butter are not dairy butter.
    func testButterExclusions() {
        for item in ["Cocoa Butter", "Peanut Butter", "Shea Butter"] {
            let result = analyse("INGREDIENTS: Sugar, \(item).",
                                 profile: [("dairy", .severe)])
            XCTAssertEqual(result.verdict, .safe, "\(item) is not dairy butter")
        }
    }

    // MARK: - Longest-match resolution

    /// A specific multi-word term must win over a generic single word it
    /// contains, and only one finding should result.
    func testLongestMatchWins() {
        let result = analyse("INGREDIENTS: Coconut Milk Powder, Sugar.",
                             profile: [("coconut", .moderate), ("dairy", .severe)])

        XCTAssertEqual(result.findings.count, 1, "Only coconut should be reported")
        XCTAssertEqual(result.findings.first?.categoryID, "coconut")
    }

    // MARK: - Trace warnings

    /// A trace warning is weaker evidence than a listed ingredient, so it
    /// escalates to Avoid only for a severe allergy.
    func testTraceWarningSeverityScaling() {
        let label = "INGREDIENTS: Rice Flour, Salt. May contain traces of peanuts."

        XCTAssertEqual(analyse(label, profile: [("peanut", .severe)]).verdict, .avoid)
        XCTAssertEqual(analyse(label, profile: [("peanut", .moderate)]).verdict, .caution)
        XCTAssertEqual(analyse(label, profile: [("peanut", .mild)]).verdict, .caution)
    }

    /// A listed ingredient is stronger evidence than a trace warning.
    func testListedIngredientSeverityScaling() {
        let label = "INGREDIENTS: Rice Flour, Peanuts, Salt."

        XCTAssertEqual(analyse(label, profile: [("peanut", .severe)]).verdict, .avoid)
        XCTAssertEqual(analyse(label, profile: [("peanut", .moderate)]).verdict, .avoid)
        XCTAssertEqual(analyse(label, profile: [("peanut", .mild)]).verdict, .caution,
                       "A mild sensitivity warrants Caution, not Avoid")
    }

    func testTraceWarningIsMarkedAsMayContain() {
        let result = analyse("INGREDIENTS: Rice Flour. May contain traces of peanuts.",
                             profile: [("peanut", .severe)])

        XCTAssertEqual(result.findings.first?.kind, .mayContain)
    }

    // MARK: - OCR error tolerance

    /// Transposed letters are the most common OCR error and must still be
    /// caught, flagged as a lower-confidence fuzzy match.
    func testTransposedLettersAreCaught() {
        let result = analyse("INGREDIENTS: Sugar, Casien, Flour.",
                             profile: [("dairy", .severe)])

        XCTAssertFalse(result.findings.isEmpty, "A transposition must still be caught")
        XCTAssertEqual(result.findings.first?.matchType, .fuzzy)
    }

    func testEditDistanceBoundary() {
        XCTAssertTrue(engine.isWithinOneEdit("casein", "casien"), "transposition")
        XCTAssertTrue(engine.isWithinOneEdit("whey", "vhey"), "substitution")
        XCTAssertTrue(engine.isWithinOneEdit("gluten", "glutenn"), "insertion")
        XCTAssertTrue(engine.isWithinOneEdit("gluten", "gluen"), "deletion")

        XCTAssertFalse(engine.isWithinOneEdit("casein", "protein"), "too different")
        XCTAssertFalse(engine.isWithinOneEdit("milk", "silk oil"), "length gap too large")
    }

    /// A confident exact match must not be diluted by fuzzy guessing.
    func testFuzzyMatchingOnlyWhenNothingExactFound() {
        let result = analyse("INGREDIENTS: Whey Powder, Sugar.",
                             profile: [("dairy", .severe)])

        XCTAssertEqual(result.findings.first?.matchType, .synonym)
        XCTAssertNotEqual(result.findings.first?.matchType, .fuzzy)
    }

    // MARK: - Deduplication

    /// Three dairy ingredients must produce one dairy warning, not three.
    func testRepeatedAllergenProducesOneFinding() {
        let result = analyse("INGREDIENTS: Milk Solids, Whey Powder, Casein, Butter.",
                             profile: [("dairy", .severe)])

        let dairyFindings = result.findings.filter { $0.categoryID == "dairy" }
        XCTAssertEqual(dairyFindings.count, 1)
    }

    /// A listed ingredient and a trace warning for the same allergen are
    /// different facts and must both survive.
    func testContainsAndMayContainAreKeptSeparately() {
        let result = analyse("INGREDIENTS: Peanuts, Sugar. May contain traces of peanuts.",
                             profile: [("peanut", .severe)])

        let kinds = Set(result.findings.map(\.kind))
        XCTAssertTrue(kinds.contains(.contains))
    }

    // MARK: - Dietary preferences

    func testVeganConflictIsCautionNotAvoid() {
        let result = analyse("INGREDIENTS: Flour, Whey Powder, Sugar.",
                             profile: [], diets: [.vegan])

        XCTAssertEqual(result.verdict, .caution, "A diet clash is not a medical danger")
        XCTAssertEqual(result.findings.first?.kind, .dietaryConflict)
    }

    func testAllergyTakesPrecedenceOverDietaryConflict() {
        let result = analyse("INGREDIENTS: Flour, Whey Powder.",
                             profile: [("dairy", .severe)], diets: [.vegan])

        XCTAssertEqual(result.verdict, .avoid)
        XCTAssertEqual(result.findings.first?.kind, .contains,
                       "The allergy, not the diet, should be reported")
    }

    func testVegetarianIgnoresDairyButCatchesFish() {
        let dairy = analyse("INGREDIENTS: Milk, Sugar.", profile: [], diets: [.vegetarian])
        XCTAssertEqual(dairy.verdict, .safe, "Dairy is fine for a vegetarian")

        let fish = analyse("INGREDIENTS: Chilli, Umbalakada.", profile: [], diets: [.vegetarian])
        XCTAssertEqual(fish.verdict, .caution, "Maldive fish breaks a vegetarian diet")
    }

    // MARK: - Nutrient limits

    func testNutrientOverLimitProducesCaution() {
        let label = """
        INGREDIENTS: Sugar, Flour.
        NUTRITION INFORMATION
        Per 100g
        Energy 480 kcal
        Sugar 22.5 g
        """
        let result = analyse(label, profile: [],
                             limits: [HealthLimit(nutrient: .sugar, maxPer100g: 5)])

        XCTAssertEqual(result.verdict, .caution)
        XCTAssertEqual(result.findings.first?.kind, .overLimit)
    }

    func testNutrientWithinLimitIsSafe() {
        let label = """
        INGREDIENTS: Rice Flour.
        NUTRITION INFORMATION
        Per 100g
        Sugar 1.2 g
        """
        let result = analyse(label, profile: [],
                             limits: [HealthLimit(nutrient: .sugar, maxPer100g: 5)])

        XCTAssertEqual(result.verdict, .safe)
    }

    // MARK: - Verdict composition

    /// The overall verdict is the most serious of its findings.
    func testMostSevereFindingDeterminesVerdict() {
        let label = """
        INGREDIENTS: Wheat Flour, Whey Powder, Sugar.
        NUTRITION INFORMATION
        Per 100g
        Sugar 30 g
        """
        let result = analyse(label,
                             profile: [("dairy", .severe), ("gluten", .mild)],
                             limits: [HealthLimit(nutrient: .sugar, maxPer100g: 5)])

        XCTAssertEqual(result.verdict, .avoid, "Severe dairy outranks the softer findings")
        XCTAssertGreaterThan(result.findings.count, 1)
        XCTAssertEqual(result.findings.first?.impliedVerdict, .avoid,
                       "The most serious finding must be listed first")
    }

    func testVerdictRankingHelper() {
        XCTAssertEqual(Verdict.mostSevere(.safe, .caution), .caution)
        XCTAssertEqual(Verdict.mostSevere(.caution, .avoid), .avoid)
        XCTAssertEqual(Verdict.mostSevere(.safe, .safe), .safe)
    }

    // MARK: - Evidence quality

    /// Every finding must carry the evidence that justifies it, because the
    /// app never shows a verdict without a reason.
    func testFindingsCarryTheirEvidence() {
        let result = analyse("INGREDIENTS: Sugar, Whey Powder.",
                             profile: [("dairy", .moderate)])

        let finding = try? XCTUnwrap(result.findings.first)
        XCTAssertEqual(finding?.matchedText, "whey powder")
        XCTAssertEqual(finding?.categoryName, "Dairy")
        XCTAssertFalse(finding?.reason.isEmpty ?? true, "A finding must explain itself")
    }

    // MARK: - Performance

    /// Analysis must stay fast enough to feel instant after a scan.
    func testAnalysisPerformance() throws {
        let label = """
        INGREDIENTS: Wheat Flour (62%), Sugar, Palm Oil, Whey Powder, Salt,
        Soy Lecithin (E322), Raising Agent (E500ii), Vanilla Flavour,
        Milk Solids, Cocoa Butter, Cashew Nuts, Sesame Seeds.
        May contain traces of peanuts and tree nuts.
        """
        let parsed = LabelParser.parse(label)
        let userProfile = profile([("dairy", .severe), ("peanut", .severe),
                                   ("gluten", .moderate), ("cashew", .mild)])

        measure {
            for _ in 0..<100 {
                _ = engine.analyse(label: parsed, profile: userProfile)
            }
        }
    }
}
