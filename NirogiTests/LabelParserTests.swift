//
//  LabelParserTests.swift
//  NirogiTests
//
//  Unit tests for turning raw OCR output into structured label data.
//
//  Several of these are regression tests for bugs found by scanning real
//  sample labels through Vision. They are kept because the bugs they cover
//  were invisible in hand-written test strings.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import XCTest
@testable import IT23257504_PartA

final class LabelParserTests: XCTestCase {

    // MARK: - Ingredient splitting

    func testSplitsCommaSeparatedIngredients() {
        let parsed = LabelParser.parse("INGREDIENTS: Wheat Flour, Sugar, Palm Oil, Salt.")

        XCTAssertEqual(parsed.ingredientTexts, ["wheat flour", "sugar", "palm oil", "salt"])
    }

    func testStripsPercentages() {
        let parsed = LabelParser.parse("INGREDIENTS: Wheat Flour (62%), Sugar (20%).")

        XCTAssertTrue(parsed.ingredientTexts.contains("wheat flour"))
        XCTAssertFalse(parsed.ingredientTexts.contains { $0.contains("62") })
    }

    /// Bracketed sub-ingredients must be readable both ways: the whole
    /// phrase and each item inside it.
    func testBracketedSubIngredientsAreExtracted() {
        let parsed = LabelParser.parse("INGREDIENTS: Milk Solids (Whey, Casein), Sugar.")

        XCTAssertTrue(parsed.ingredientTexts.contains { $0.contains("whey") })
        XCTAssertTrue(parsed.ingredientTexts.contains { $0.contains("casein") })
    }

    /// Many small local packets have no "Ingredients:" heading at all.
    func testWorksWithoutIngredientsHeader() {
        let parsed = LabelParser.parse("Rice Flour, Sunflower Oil, Salt, Turmeric")

        XCTAssertEqual(parsed.ingredientTexts.count, 4)
    }

    func testRejectsBatchCodesAndNoise() {
        let parsed = LabelParser.parse("INGREDIENTS: Rice Flour, Salt. BATCH NO 20260115")

        XCTAssertFalse(parsed.ingredientTexts.contains { $0.contains("20260115") })
    }

    func testStorageInformationIsNotTreatedAsIngredients() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Rice Flour, Salt.
        STORAGE: Store in a cool dry place away from sunlight.
        """)

        XCTAssertFalse(parsed.ingredientTexts.contains { $0.contains("cool dry place") })
        XCTAssertEqual(parsed.ingredientTexts, ["rice flour", "salt"])
    }

    // MARK: - Trace warnings

    func testTraceWarningIsSeparatedFromIngredients() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Rice Flour, Salt. May contain traces of peanuts.
        """)

        let traces = parsed.ingredients.filter(\.isTraceWarning)
        XCTAssertTrue(traces.contains { $0.text.contains("peanut") })
        XCTAssertFalse(parsed.ingredients.first { $0.text == "rice flour" }?.isTraceWarning ?? true)
    }

    /// Regression: real packets print the trace warning under its own
    /// "ALLERGEN ADVICE:" heading, and that heading also ends the
    /// ingredient list. Trimming terminators before locating the warning
    /// silently discarded "may contain peanuts" entirely.
    func testTraceWarningSurvivesAllergenAdviceHeading() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Wheat Flour, Sugar, Whey Powder.
        ALLERGEN ADVICE:
        May contain traces of peanuts and tree nuts.
        NUTRITION INFORMATION
        Per 100g
        Energy 480 kcal
        """)

        let traces = parsed.ingredients.filter(\.isTraceWarning)
        XCTAssertTrue(traces.contains { $0.text.contains("peanut") },
                      "The trace warning must survive its own heading")
        XCTAssertFalse(parsed.ingredientTexts.contains { $0.contains("kcal") },
                       "Nutrition rows are not ingredients")
    }

    func testFacilityWordingCountsAsTraceWarning() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Chilli, Onion, Salt.
        Produced in a facility that also handles prawns.
        """)

        XCTAssertTrue(parsed.ingredients.contains { $0.text.contains("prawn") && $0.isTraceWarning })
    }

    // MARK: - Nutrition, inline layout

    func testInlineNutritionTable() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Flour, Sugar.
        Nutrition Information per 100g: Energy 480 kcal, Sugar 22.5 g, Salt 1.2 g
        """)

        let values = Dictionary(uniqueKeysWithValues: parsed.nutrition.map { ($0.nutrient, $0.amountPer100g) })
        XCTAssertEqual(values[.energy], 480)
        XCTAssertEqual(values[.sugar], 22.5)
        XCTAssertEqual(values[.salt], 1200, "1.2 g must be converted to milligrams")
    }

    func testMultiLineNutritionTable() {
        let parsed = LabelParser.parse("""
        NUTRITION INFORMATION
        Per 100g
        Energy 545 kcal
        Sugar 51.0 g
        Saturated Fat 18.5 g
        Salt 95 mg
        """)

        let values = Dictionary(uniqueKeysWithValues: parsed.nutrition.map { ($0.nutrient, $0.amountPer100g) })
        XCTAssertEqual(values[.energy], 545)
        XCTAssertEqual(values[.sugar], 51.0)
        XCTAssertEqual(values[.saturatedFat], 18.5)
        XCTAssertEqual(values[.salt], 95)
    }

    // MARK: - Nutrition, column-major layout

    /// Regression: this is verbatim Vision output for one of the sample
    /// labels. Because the printed table has a wide gap between its two
    /// columns, Vision returned every nutrient name first and every value
    /// afterwards. The parser used to pair "Sugar" with the energy figure
    /// and report 620 g of sugar.
    func testColumnMajorNutritionTable() {
        let parsed = LabelParser.parse("""
        COCONUT MILK POWDER
        INGREDIENTS:
        Coconut Milk (96%), Maltodextrin,
        Sodium Caseinate, Anti-caking
        Agent (E551).
        NUTRITION INFORMATION
        Per 100g
        Energy
        Sugar
        Salt
        620 kcal
        8.0 g
        180 mg
        """)

        let values = Dictionary(uniqueKeysWithValues: parsed.nutrition.map { ($0.nutrient, $0.amountPer100g) })
        XCTAssertEqual(values[.energy], 620)
        XCTAssertEqual(values[.sugar], 8.0, "Sugar must not inherit the energy figure")
        XCTAssertEqual(values[.salt], 180)
    }

    /// A number in the ingredient list must never be read as a nutrient.
    /// "Soy Lecithin (E322)" was previously reported as 322 mg of salt.
    func testAdditiveNumbersAreNotReadAsNutrients() {
        let parsed = LabelParser.parse("""
        INGREDIENTS: Flour, Salt, Soy Lecithin (E322), Raising Agent (E500ii).
        """)

        XCTAssertNil(parsed.nutrition.first { $0.nutrient == .salt },
                     "E322 is an additive code, not a salt value")
    }

    // MARK: - Unit conversion

    func testUnitConversions() {
        XCTAssertEqual(LabelParser.normaliseAmount(1.2, unit: "g", for: .salt), 1200)
        XCTAssertEqual(LabelParser.normaliseAmount(500, unit: "mg", for: .salt), 500)
        XCTAssertEqual(LabelParser.normaliseAmount(1000, unit: "mg", for: .sugar), 1.0)
        XCTAssertEqual(LabelParser.normaliseAmount(2000, unit: "kj", for: .energy) , 2000 / 4.184,
                       accuracy: 0.01)
    }

    // MARK: - OCR noise

    func testRepairsWordsBrokenAcrossLines() {
        let normalised = LabelParser.normalise("whey pow-\nder")

        XCTAssertTrue(normalised.contains("whey powder"))
    }

    func testNormalisesCurlyPunctuation() {
        let normalised = LabelParser.normalise("cow\u{2019}s milk \u{201C}pure\u{201D}")

        XCTAssertTrue(normalised.contains("cow's milk"))
        XCTAssertFalse(normalised.contains("\u{2019}"))
    }

    func testCollapsesExcessWhitespace() {
        let normalised = LabelParser.normalise("wheat    flour,\n\n  sugar")

        XCTAssertFalse(normalised.contains("  "))
    }

    // MARK: - Edge cases

    func testEmptyInputProducesEmptyResult() {
        let parsed = LabelParser.parse("")

        XCTAssertTrue(parsed.isEmpty)
        XCTAssertTrue(parsed.ingredients.isEmpty)
    }

    func testGibberishProducesNoIngredients() {
        let parsed = LabelParser.parse("### 12345 !!! 678")

        XCTAssertTrue(parsed.ingredients.isEmpty)
    }

    func testDuplicateIngredientsAreCollapsed() {
        let parsed = LabelParser.parse("INGREDIENTS: Sugar, Salt, Sugar, Salt.")

        XCTAssertEqual(parsed.ingredientTexts.count, 2)
    }

    // MARK: - Performance

    /// Parsing runs on every scan, so it must stay cheap.
    func testParsingPerformance() {
        let label = """
        INGREDIENTS: Wheat Flour (62%), Sugar, Palm Oil, Whey Powder, Salt,
        Soy Lecithin (E322), Raising Agent (E500ii), Vanilla Flavour,
        Milk Solids, Cocoa Butter, Cashew Nuts (8%), Sesame Seeds.
        ALLERGEN ADVICE: May contain traces of peanuts and tree nuts.
        NUTRITION INFORMATION
        Per 100g
        Energy 480 kcal
        Sugar 22.5 g
        Saturated Fat 11.2 g
        Salt 1.2 g
        """

        measure {
            for _ in 0..<100 {
                _ = LabelParser.parse(label)
            }
        }
    }
}
