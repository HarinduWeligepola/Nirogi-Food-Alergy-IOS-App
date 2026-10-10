//
//  LabelParser.swift
//  Nirogi (IT23257504-PartA)
//
//  Turns the raw, messy text Vision reads from a photo into structured
//  data: a list of individual ingredients, any cross-contamination warning,
//  and the numbers from the nutrition table.
//
//  This is pure text processing with no UI or framework dependency, so it
//  can be unit-tested directly against sample label strings.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

// MARK: - Parsed label

/// One ingredient as it appeared on the label.
struct Ingredient: Hashable, Sendable {
    /// Cleaned text, e.g. "whey powder".
    let text: String
    /// Position in the label's ingredient list, used to highlight it later.
    let index: Int
    /// True when this came from a "may contain traces of…" style warning
    /// rather than the ingredient list proper. The distinction matters:
    /// a trace warning is a weaker signal than a listed ingredient.
    let isTraceWarning: Bool
}

/// Everything the parser could extract from a label.
struct ParsedLabel: Hashable, Sendable {
    let rawText: String
    let ingredients: [Ingredient]
    let nutrition: [NutrientValue]

    /// Ingredient text only, in label order — what gets stored on a
    /// `ScanRecord` for display.
    var ingredientTexts: [String] { ingredients.map(\.text) }

    /// True when the parser found nothing usable, so the UI can tell the
    /// user to retake the photo rather than showing a misleading "Safe".
    var isEmpty: Bool { ingredients.isEmpty && nutrition.isEmpty }

    static let empty = ParsedLabel(rawText: "", ingredients: [], nutrition: [])
}

// MARK: - Parser

/// Converts raw OCR output into a `ParsedLabel`.
enum LabelParser {

    // MARK: Vocabulary

    /// Words that introduce the ingredient list on a packet.
    private static let ingredientHeaders = [
        "ingredients", "ingredient", "ingredients list", "composition",
        "contains the following", "made from"
    ]

    /// Phrases that introduce a cross-contamination warning. Everything
    /// after one of these is treated as a trace warning rather than a real
    /// ingredient.
    private static let traceMarkers = [
        "may contain", "may also contain", "traces of", "may contain traces",
        "produced in a facility", "manufactured in a facility",
        "made in a factory", "processed in a facility",
        "packed in a facility", "same equipment", "shared equipment"
    ]

    /// Headers that introduce the nutrition table. Nutrient values are only
    /// read from after one of these, because the ingredient list contains
    /// numbers that look deceptively like nutrient values — the "322" in
    /// "soy lecithin (E322)" being the classic trap.
    private static let nutritionHeaders = [
        "nutrition information", "nutritional information", "nutrition facts",
        "nutritional value", "nutritional facts", "nutrition", "per 100g",
        "per 100 g", "typical values"
    ]

    /// Headers that mark the end of the ingredient list. Anything after
    /// these is nutrition or storage information, not ingredients.
    private static let terminators = [
        "nutrition", "nutritional information", "nutrition facts",
        "storage", "store in", "best before", "expiry", "manufactured by",
        "net weight", "directions", "allergen advice", "allergy advice",
        "keep refrigerated", "batch no", "mrp"
    ]

    // MARK: - Entry point

    /// Parses raw OCR text into structured label data.
    ///
    /// - Parameter rawText: text exactly as Vision returned it, including
    ///   line breaks and any recognition noise.
    /// - Returns: the ingredients, trace warnings and nutrition values found.
    static func parse(_ rawText: String) -> ParsedLabel {
        let normalised = normalise(rawText)

        let (listText, traceText) = splitIngredientSection(from: normalised)

        var ingredients: [Ingredient] = []
        var index = 0

        for token in splitIntoIngredients(listText) {
            ingredients.append(Ingredient(text: token, index: index, isTraceWarning: false))
            index += 1
        }
        for token in splitIntoIngredients(traceText) {
            ingredients.append(Ingredient(text: token, index: index, isTraceWarning: true))
            index += 1
        }

        // Nutrition parsing needs the original line breaks: whether a value
        // sits on the same line as its name is exactly what distinguishes an
        // inline table from a column-major one.
        let nutrition = parseNutrition(from: normaliseKeepingLines(rawText))

        return ParsedLabel(rawText: rawText, ingredients: ingredients, nutrition: nutrition)
    }

    // MARK: - Normalisation

    /// Cleans up OCR noise while keeping line breaks intact.
    ///
    /// Used for nutrition parsing, where line structure carries meaning.
    static func normaliseKeepingLines(_ text: String) -> String {
        var result = text.lowercased()

        for (from, to) in punctuationReplacements {
            result = result.replacingOccurrences(of: from, with: to)
        }

        // A hyphen at the end of a line is a word broken across lines.
        result = result.replacingOccurrences(of: "-\n", with: "")

        // Collapse runs of spaces and tabs, but never newlines.
        result = result.replacingOccurrences(
            of: #"[ \t]+"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Punctuation variants OCR produces inconsistently, and what to
    /// normalise each one to.
    private static let punctuationReplacements: [String: String] = [
        "\u{2018}": "'", "\u{2019}": "'",      // curly single quotes
        "\u{201C}": "\"", "\u{201D}": "\"",    // curly double quotes
        "\u{2013}": "-", "\u{2014}": "-",      // en and em dashes
        "\u{00A0}": " ",                        // non-breaking space
        "：": ":", "，": ",", "；": ";"          // full-width punctuation
    ]

    /// Lowercases the text and repairs the kinds of noise OCR introduces:
    /// smart quotes, stray line breaks inside words, and inconsistent
    /// whitespace.
    static func normalise(_ text: String) -> String {
        var result = text.lowercased()

        // Unify punctuation variants that OCR produces inconsistently.
        let replacements: [String: String] = [
            "\u{2018}": "'", "\u{2019}": "'",      // curly single quotes
            "\u{201C}": "\"", "\u{201D}": "\"",    // curly double quotes
            "\u{2013}": "-", "\u{2014}": "-",      // en and em dashes
            "\u{00A0}": " ",                        // non-breaking space
            "：": ":", "，": ",", "；": ";"          // full-width punctuation
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }

        // A hyphen at the end of a line is a word broken across lines.
        result = result.replacingOccurrences(of: "-\n", with: "")

        // Remaining line breaks behave as separators between items.
        result = result.replacingOccurrences(of: "\n", with: " ")

        // Collapse runs of whitespace into single spaces.
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Sectioning

    /// Splits the text into the ingredient list and any trace warning.
    ///
    /// If no "ingredients:" header is found the whole text is treated as the
    /// ingredient list, since many small local packets omit the header.
    ///
    /// The order of operations matters. The trace warning is located
    /// *before* terminator headers are trimmed, because real packets print
    /// the warning under its own "ALLERGEN ADVICE:" heading — and that
    /// heading also ends the ingredient list. Trimming first would throw
    /// the warning away, silently losing a "may contain peanuts" line.
    static func splitIngredientSection(from text: String) -> (list: String, trace: String) {
        var working = text

        // Start at the ingredients header when there is one.
        if let headerRange = earliestRange(of: ingredientHeaders, in: working) {
            working = String(working[headerRange.upperBound...])
            // Drop a leading colon or dash left over from the header.
            working = working.trimmingCharacters(in: CharacterSet(charactersIn: " :-."))
        }

        // Separate the cross-contamination warning from the real list, then
        // trim each part at its own terminator.
        if let traceRange = earliestRange(of: traceMarkers, in: working) {
            let list = String(working[..<traceRange.lowerBound])
            let trace = String(working[traceRange.upperBound...])
            return (cutAtTerminator(list), cutAtTerminator(trace))
        }

        return (cutAtTerminator(working), "")
    }

    /// Removes everything from the first terminator header onwards.
    private static func cutAtTerminator(_ text: String) -> String {
        guard let stopRange = earliestRange(of: terminators, in: text) else {
            return text.trimmed
        }
        return String(text[..<stopRange.lowerBound]).trimmed
    }

    /// Finds whichever of the given phrases appears earliest in the text.
    private static func earliestRange(of phrases: [String], in text: String) -> Range<String.Index>? {
        var earliest: Range<String.Index>?
        for phrase in phrases {
            guard let found = text.range(of: phrase) else { continue }
            if earliest == nil || found.lowerBound < earliest!.lowerBound {
                earliest = found
            }
        }
        return earliest
    }

    // MARK: - Ingredient splitting

    /// Splits a block of ingredient text into individual items.
    ///
    /// Bracketed sub-ingredients are kept with their parent as well as
    /// emitted separately, because both readings matter: "milk solids
    /// (whey)" should match on the whole phrase and on "whey" alone.
    static func splitIntoIngredients(_ text: String) -> [String] {
        guard !text.trimmed.isEmpty else { return [] }

        var items: [String] = []

        // Split on the separators labels actually use.
        let separators = CharacterSet(charactersIn: ",;.•·|")
        let pieces = text.components(separatedBy: separators)

        for piece in pieces {
            let cleaned = clean(piece)
            guard isPlausibleIngredient(cleaned) else { continue }
            items.append(cleaned)

            // Also emit the contents of any brackets as their own items.
            for inner in bracketedContents(of: cleaned) {
                let innerCleaned = clean(inner)
                if isPlausibleIngredient(innerCleaned), innerCleaned != cleaned {
                    items.append(innerCleaned)
                }
            }
        }

        // Remove duplicates while preserving label order.
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    /// Extracts the text inside round brackets, e.g. "milk (whey, casein)"
    /// yields "whey, casein".
    private static func bracketedContents(of text: String) -> [String] {
        var results: [String] = []
        var depth = 0
        var current = ""
        for character in text {
            if character == "(" || character == "[" {
                depth += 1
                if depth == 1 { current = "" ; continue }
            }
            if character == ")" || character == "]" {
                depth -= 1
                if depth == 0 {
                    // Inner list may itself be comma-separated.
                    results.append(contentsOf: current.components(separatedBy: ","))
                    current = ""
                    continue
                }
            }
            if depth > 0 { current.append(character) }
        }
        return results
    }

    /// Strips percentages, stray symbols and surrounding whitespace from an
    /// ingredient, e.g. "wheat flour (62%)" becomes "wheat flour".
    static func clean(_ text: String) -> String {
        var result = text

        // Remove percentage figures, which are not part of the name.
        result = result.replacingOccurrences(
            of: #"\d+(\.\d+)?\s*%"#, with: "", options: .regularExpression)

        // Remove leftover bracket characters and list bullets.
        result = result.replacingOccurrences(
            of: #"[()\[\]*†‡]"#, with: " ", options: .regularExpression)

        // Collapse whitespace.
        result = result.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
    }

    /// Rejects fragments that are clearly not ingredient names: empty
    /// strings, bare numbers, and single stray characters left by OCR.
    static func isPlausibleIngredient(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        // Must contain at least one letter.
        guard text.rangeOfCharacter(from: .letters) != nil else { return false }
        // Reject things that are mostly digits, such as batch codes.
        let digits = text.filter(\.isNumber).count
        guard Double(digits) / Double(text.count) < 0.5 else { return false }
        return true
    }

    // MARK: - Nutrition parsing

    /// Reads nutrient values out of a nutrition table.
    ///
    /// Two layouts have to be handled, because Vision reports what it sees
    /// rather than what the table means:
    ///
    /// 1. **Inline** — "Sugar 22.5 g" on one line. The common case.
    /// 2. **Column-major** — Vision returns every nutrient *name* first and
    ///    every *value* afterwards, because the wide gap between the two
    ///    printed columns reads as separate blocks. A naive parser then
    ///    pairs "Sugar" with the energy figure, silently reporting a wrong
    ///    number — which is worse than reporting none at all.
    ///
    /// Line structure is therefore preserved for nutrition parsing, unlike
    /// ingredient parsing where line breaks are just separators.
    static func parseNutrition(from text: String) -> [NutrientValue] {
        let lines = nutritionLines(of: text)
        guard !lines.isEmpty else { return [] }

        var values = inlineValues(in: lines)

        // Fill anything still missing using positional column pairing.
        for candidate in columnPairedValues(in: lines)
        where !values.contains(where: { $0.nutrient == candidate.nutrient }) {
            values.append(candidate)
        }

        // Return in a stable, declared order rather than discovery order.
        return Nutrient.allCases.compactMap { nutrient in
            values.first { $0.nutrient == nutrient }
        }
    }

    /// The lines belonging to the nutrition table, lowercased and trimmed.
    ///
    /// When no nutrition heading is present every line is returned, since
    /// some small packets print values with no heading at all.
    static func nutritionLines(of text: String) -> [String] {
        let all = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        guard let headerIndex = all.firstIndex(where: { line in
            nutritionHeaders.contains { line.contains($0) }
        }) else {
            return all
        }
        return Array(all[headerIndex...])
    }

    /// Values where the nutrient name and its number share a line.
    ///
    /// Every nutrient is looked for on every line, because compact labels
    /// print the whole table on one line: "Energy 480 kcal, Sugar 22.5 g,
    /// Salt 1.2 g".
    private static func inlineValues(in lines: [String]) -> [NutrientValue] {
        var results: [NutrientValue] = []

        for line in lines {
            for nutrient in Nutrient.allCases
            where !results.contains(where: { $0.nutrient == nutrient }) {

                guard let (keyword, afterKeyword) = keywordMatch(for: nutrient, in: line) else { continue }

                // Stop at the next nutrient's name, so "sugar salt 620 kcal"
                // cannot pair "sugar" with the energy figure.
                let window = truncateAtNextNutrient(afterKeyword, excluding: nutrient)

                guard let (amount, unit, source) = firstNumber(in: window) else { continue }
                guard acceptedUnits(for: nutrient).contains(unit) else { continue }

                results.append(NutrientValue(
                    nutrient: nutrient,
                    amountPer100g: normaliseAmount(amount, unit: unit, for: nutrient),
                    sourceText: "\(keyword) \(source)".trimmed))
            }
        }

        return results
    }

    /// Finds one nutrient's longest matching keyword in a line, returning
    /// the keyword and the text that follows it.
    private static func keywordMatch(for nutrient: Nutrient, in line: String) -> (String, String)? {
        let keywords = nutrient.tableKeywords.sorted { $0.count > $1.count }
        for keyword in keywords {
            guard let range = line.range(of: keyword) else { continue }
            return (keyword, String(line[range.upperBound...]))
        }
        return nil
    }

    /// Pairs a run of name-only lines with the run of value-only lines that
    /// follows it, which is how a two-column table arrives from Vision.
    private static func columnPairedValues(in lines: [String]) -> [NutrientValue] {
        var names: [(nutrient: Nutrient, keyword: String, index: Int)] = []
        var figures: [(amount: Double, unit: String, source: String, index: Int)] = []

        for (index, line) in lines.enumerated() {
            if let (nutrient, keyword, _) = matchNutrient(in: line),
               !line.contains(where: \.isNumber) {
                names.append((nutrient, keyword, index))
                continue
            }
            if let figure = standaloneValue(in: line) {
                figures.append((figure.amount, figure.unit, line, index))
            }
        }

        // Only trust this when it really is one block of names followed by
        // one block of values.
        guard let lastName = names.last?.index,
              let firstFigure = figures.first?.index,
              names.count > 1, lastName < firstFigure else { return [] }

        var results: [NutrientValue] = []
        for (position, name) in names.enumerated() {
            guard position < figures.count else { break }
            let figure = figures[position]

            // A mismatched unit means the columns are not aligned after all,
            // so nothing is reported rather than guessing.
            guard acceptedUnits(for: name.nutrient).contains(figure.unit) else { continue }

            results.append(NutrientValue(
                nutrient: name.nutrient,
                amountPer100g: normaliseAmount(figure.amount, unit: figure.unit, for: name.nutrient),
                sourceText: "\(name.keyword) \(figure.source)".trimmed))
        }
        return results
    }

    /// Finds which nutrient a line names, preferring the longest keyword so
    /// "of which saturates" wins over "saturates".
    private static func matchNutrient(in line: String) -> (Nutrient, String, String)? {
        var best: (Nutrient, String, String)?

        for nutrient in Nutrient.allCases {
            for keyword in nutrient.tableKeywords {
                guard let range = line.range(of: keyword) else { continue }
                if let existing = best, existing.1.count >= keyword.count { continue }
                best = (nutrient, keyword, String(line[range.upperBound...]))
            }
        }
        return best
    }

    /// Cuts a snippet at the first mention of a different nutrient.
    private static func truncateAtNextNutrient(_ text: String, excluding nutrient: Nutrient) -> String {
        var cutoff = text.endIndex

        for other in Nutrient.allCases where other != nutrient {
            for keyword in other.tableKeywords {
                guard let range = text.range(of: keyword) else { continue }
                if range.lowerBound < cutoff { cutoff = range.lowerBound }
            }
        }
        return String(text[..<cutoff])
    }

    /// Reads a line that is nothing but a number and a unit, e.g. "620 kcal".
    private static func standaloneValue(in line: String) -> (amount: Double, unit: String)? {
        let pattern = #"^(\d+(?:[.,]\d+)?)\s*(kcal|kj|mg|g)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let numberRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line) else { return nil }

        let numberText = line[numberRange].replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(numberText) else { return nil }
        return (amount, String(line[unitRange]))
    }

    /// Units that are valid for a given nutrient on a label.
    static func acceptedUnits(for nutrient: Nutrient) -> Set<String> {
        switch nutrient {
        case .sugar, .saturatedFat: return ["g", "mg"]
        case .salt: return ["g", "mg"]
        case .energy: return ["kcal", "kj"]
        }
    }


    /// Extracts the first number and its unit from a snippet of text.
    private static func firstNumber(in text: String) -> (amount: Double, unit: String, source: String)? {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(kcal|kj|mg|g|%)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numberRange = Range(match.range(at: 1), in: text) else { return nil }

        let numberText = text[numberRange].replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(numberText) else { return nil }

        var unit = ""
        if match.numberOfRanges > 2, let unitRange = Range(match.range(at: 2), in: text) {
            unit = String(text[unitRange])
        }

        let sourceRange = Range(match.range, in: text)
        let source = sourceRange.map { String(text[$0]) } ?? numberText

        return (amount, unit, source.trimmed)
    }

    /// Converts a parsed figure into the unit Nirogi compares against.
    ///
    /// Salt is the case that matters: labels report it in grams or
    /// milligrams interchangeably, and comparing 1.2 g against a 1500 mg
    /// limit without converting would silently pass a salty product.
    static func normaliseAmount(_ amount: Double, unit: String, for nutrient: Nutrient) -> Double {
        switch nutrient {
        case .salt:
            // Target unit is mg.
            if unit == "g" { return amount * 1000 }
            return amount
        case .energy:
            // Target unit is kcal; kJ is roughly 4.184 kcal.
            if unit == "kj" { return amount / 4.184 }
            return amount
        case .sugar, .saturatedFat:
            // Target unit is g.
            if unit == "mg" { return amount / 1000 }
            return amount
        }
    }
}

// MARK: - Helpers

private extension String {
    /// Shorthand for trimming surrounding whitespace.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
