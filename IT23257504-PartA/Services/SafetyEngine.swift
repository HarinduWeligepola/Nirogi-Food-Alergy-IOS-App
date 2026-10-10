//
//  SafetyEngine.swift
//  Nirogi (IT23257504-PartA)
//
//  The heart of the app: decides whether a parsed label is safe for one
//  specific user.
//
//  Design note — this type has no SwiftUI, SwiftData or Vision dependency.
//  It takes value types in and returns value types out, which means it can
//  be unit-tested exhaustively without a simulator, and run off the main
//  actor without any concurrency concerns.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation

/// Analyses a parsed label against a user's profile.
nonisolated struct SafetyEngine: Sendable {

    /// The allergen definitions used for matching.
    let knowledgeBase: AllergenKnowledgeBase

    /// Minimum term length before fuzzy matching is allowed. Short words
    /// like "egg" or "soy" are excluded because a single character of slack
    /// would match far too many unrelated words.
    private static let minimumFuzzyLength = 5

    init(knowledgeBase: AllergenKnowledgeBase) {
        self.knowledgeBase = knowledgeBase
    }

    // MARK: - Public API

    /// Produces a verdict for one label and one user.
    ///
    /// - Parameters:
    ///   - label: structured output from `LabelParser`.
    ///   - profile: an immutable snapshot of the user's rules.
    /// - Returns: the verdict plus every finding that justifies it.
    func analyse(label: ParsedLabel, profile: ProfileSnapshot) -> AnalysisResult {
        var findings: [Finding] = []

        // 1. Allergen and dietary matching across the ingredient list.
        for ingredient in label.ingredients {
            let matches = resolvedMatches(in: ingredient.text)
            for match in matches {
                if let finding = finding(for: match, ingredient: ingredient, profile: profile) {
                    findings.append(finding)
                }
            }
        }

        // 2. Nutrient limits from the nutrition table.
        findings.append(contentsOf: nutritionFindings(label: label, profile: profile))

        // 3. Collapse duplicates and decide the overall verdict.
        let deduplicated = deduplicate(findings)
        let verdict = overallVerdict(for: deduplicated)

        return AnalysisResult(verdict: verdict,
                              findings: sorted(deduplicated),
                              ingredients: label.ingredientTexts,
                              nutrition: label.nutrition)
    }

    // MARK: - Matching

    /// A single raw hit of an allergen term inside an ingredient, before
    /// the user's profile is considered.
    struct Match: Hashable {
        let allergenID: String
        /// The text that actually matched, as it appears on the label.
        let matchedText: String
        /// Character offsets of the match within the ingredient.
        let start: Int
        let end: Int
        let matchType: MatchType

        var length: Int { end - start }

        /// True when this match sits entirely inside another match.
        func isContained(in other: Match) -> Bool {
            start >= other.start && end <= other.end
        }
    }

    /// Finds all allergen matches in one ingredient, then removes those that
    /// are swallowed by a longer, more specific match.
    ///
    /// This is what stops "coconut milk" from raising a dairy alert: the
    /// seven-character "milk" hit sits inside the twelve-character
    /// "coconut milk" hit, so it is discarded.
    func resolvedMatches(in ingredientText: String) -> [Match] {
        let text = ingredientText.lowercased()
        var candidates: [Match] = []

        for allergen in knowledgeBase.allergens {
            candidates.append(contentsOf: matches(for: allergen, in: text))
        }

        // Longest matches win, so sort by length and keep the first of any
        // overlapping group.
        let ordered = candidates.sorted { lhs, rhs in
            if lhs.length != rhs.length { return lhs.length > rhs.length }
            return lhs.start < rhs.start
        }

        var kept: [Match] = []
        for candidate in ordered {
            let isSwallowed = kept.contains { candidate.isContained(in: $0) }
            if !isSwallowed {
                kept.append(candidate)
            }
        }
        return kept
    }

    /// All matches of a single allergen's terms within one ingredient.
    private func matches(for allergen: Allergen, in text: String) -> [Match] {
        // An exclusion phrase vetoes this allergen for this ingredient
        // entirely — "coconut milk" is never dairy.
        let exclusionRanges = ranges(ofAny: allergen.normalisedExclusions, in: text)

        var found: [Match] = []

        for term in allergen.allSearchTerms {
            for range in wordBoundaryRanges(of: term, in: text) {
                // Skip a hit that overlaps an excluded phrase at all.
                //
                // Overlap rather than containment is deliberate. In "coconut
                // milk powder" the dairy synonym "milk powder" runs past the
                // end of the excluded phrase "coconut milk", so a
                // containment check would let it through and report coconut
                // milk powder as dairy.
                guard !overlapsExclusion(range, exclusionRanges) else { continue }

                found.append(Match(allergenID: allergen.id,
                                   matchedText: term,
                                   start: range.0,
                                   end: range.1,
                                   matchType: term == allergen.name.lowercased() ? .exact : .synonym))
            }
        }

        // Only attempt fuzzy matching when nothing matched cleanly, so a
        // confident result is never diluted by a guess.
        if found.isEmpty {
            found.append(contentsOf: fuzzyMatches(for: allergen, in: text, excluding: exclusionRanges))
        }

        return found
    }

    /// Finds near-miss matches caused by OCR errors, e.g. "vvhey" for
    /// "whey" or "casien" for "casein".
    private func fuzzyMatches(for allergen: Allergen,
                              in text: String,
                              excluding exclusionRanges: [(Int, Int)]) -> [Match] {
        var found: [Match] = []
        let words = tokenise(text)

        // Only single-word terms are worth fuzzy matching; multi-word
        // phrases have too many ways to differ by one character.
        let singleWordTerms = allergen.allSearchTerms.filter { term in
            !term.contains(" ") && term.count >= Self.minimumFuzzyLength
        }

        for word in words where word.text.count >= Self.minimumFuzzyLength {
            guard !overlapsExclusion((word.start, word.end), exclusionRanges) else { continue }

            for term in singleWordTerms {
                // Length can differ by at most one for a distance of one.
                guard abs(term.count - word.text.count) <= 1 else { continue }
                guard isWithinOneEdit(word.text, term) else { continue }

                found.append(Match(allergenID: allergen.id,
                                   matchedText: word.text,
                                   start: word.start,
                                   end: word.end,
                                   matchType: .fuzzy))
                break
            }
        }
        return found
    }

    // MARK: - Findings

    /// Turns a raw match into a finding, if the user actually cares about
    /// that allergen. Returns `nil` when the allergen is irrelevant to them.
    private func finding(for match: Match,
                         ingredient: Ingredient,
                         profile: ProfileSnapshot) -> Finding? {
        let name = knowledgeBase.name(for: match.allergenID)
        let note = knowledgeBase.allergen(id: match.allergenID)?.note ?? ""

        // Case 1: the user declared an allergy to this.
        if let severity = profile.severity(for: match.allergenID) {
            let kind: Finding.Kind = ingredient.isTraceWarning ? .mayContain : .contains
            return Finding(matchedText: match.matchedText,
                           categoryID: match.allergenID,
                           categoryName: name,
                           severity: severity,
                           kind: kind,
                           matchType: match.matchType,
                           reason: reasonText(matched: match.matchedText,
                                              allergenName: name,
                                              note: note,
                                              matchType: match.matchType),
                           ingredientIndex: ingredient.index)
        }

        // Case 2: no allergy, but it breaks a dietary preference.
        if let preference = profile.dietaryConflictSources[match.allergenID] {
            return Finding(matchedText: match.matchedText,
                           categoryID: match.allergenID,
                           categoryName: name,
                           severity: .mild,
                           kind: .dietaryConflict,
                           matchType: match.matchType,
                           reason: "\(match.matchedText.capitalisedFirst) is \(name.lowercased())-derived, which does not fit a \(preference.title.lowercased()) diet.",
                           ingredientIndex: ingredient.index)
        }

        return nil
    }

    /// Builds the plain-English explanation shown under a finding.
    private func reasonText(matched: String,
                            allergenName: String,
                            note: String,
                            matchType: MatchType) -> String {
        let subject = matched.capitalisedFirst
        var sentence: String

        if matched.lowercased() == allergenName.lowercased() {
            sentence = "\(subject) is listed on this label."
        } else {
            sentence = "\(subject) is a form of \(allergenName.lowercased())."
        }

        if !note.isEmpty {
            sentence += " \(note)"
        }

        if matchType == .fuzzy {
            sentence += " This was a close match, so the scan may have misread the word — please check the packet."
        }

        return sentence
    }

    /// Compares the nutrition table against the user's personal limits.
    private func nutritionFindings(label: ParsedLabel, profile: ProfileSnapshot) -> [Finding] {
        var findings: [Finding] = []

        for limit in profile.healthLimits {
            guard let value = label.nutrition.first(where: { $0.nutrient == limit.nutrient }) else { continue }
            guard value.amountPer100g > limit.maxPer100g else { continue }

            let reason = "This product has \(value.displayAmount) of \(limit.nutrient.title.lowercased()) per 100g, which is above your limit of \(limit.displayLimit)."

            findings.append(Finding(matchedText: value.displayAmount,
                                    categoryID: "nutrient_\(limit.nutrient.rawValue)",
                                    categoryName: limit.nutrient.title,
                                    severity: .mild,
                                    kind: .overLimit,
                                    matchType: .exact,
                                    reason: reason,
                                    ingredientIndex: -1))
        }

        return findings
    }

    // MARK: - Combining

    /// Keeps one finding per allergen and kind, preferring the most
    /// confident and most specific evidence.
    ///
    /// Without this, a label naming "milk solids", "whey" and "casein"
    /// would produce three near-identical dairy warnings.
    func deduplicate(_ findings: [Finding]) -> [Finding] {
        var best: [String: Finding] = [:]

        for finding in findings {
            let key = "\(finding.categoryID)|\(finding.kind.rawValue)"
            guard let existing = best[key] else {
                best[key] = finding
                continue
            }
            if isBetterEvidence(finding, than: existing) {
                best[key] = finding
            }
        }

        return Array(best.values)
    }

    /// Prefers higher-confidence matches, then longer matched text.
    private func isBetterEvidence(_ candidate: Finding, than existing: Finding) -> Bool {
        let candidateConfidence = candidate.matchType.confidence
        let existingConfidence = existing.matchType.confidence
        if candidateConfidence != existingConfidence {
            return candidateConfidence > existingConfidence
        }
        return candidate.matchedText.count > existing.matchedText.count
    }

    /// The overall verdict is the most serious of the individual findings.
    func overallVerdict(for findings: [Finding]) -> Verdict {
        var verdict = Verdict.safe
        for finding in findings {
            verdict = Verdict.mostSevere(verdict, finding.impliedVerdict)
        }
        return verdict
    }

    /// Orders findings so the most serious appear first on the result
    /// screen, with ties broken by confidence then name.
    func sorted(_ findings: [Finding]) -> [Finding] {
        findings.sorted { lhs, rhs in
            if lhs.impliedVerdict.rank != rhs.impliedVerdict.rank {
                return lhs.impliedVerdict.rank > rhs.impliedVerdict.rank
            }
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            if lhs.matchType.confidence != rhs.matchType.confidence {
                return lhs.matchType.confidence > rhs.matchType.confidence
            }
            return lhs.categoryName < rhs.categoryName
        }
    }
}

// MARK: - Text matching helpers

nonisolated extension SafetyEngine {

    /// A word and where it sits in the text.
    struct Token: Hashable {
        let text: String
        let start: Int
        let end: Int
    }

    /// Splits text into words, recording each word's offsets.
    func tokenise(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var startIndex = 0

        for (offset, character) in text.enumerated() {
            if character.isLetter || character.isNumber {
                if current.isEmpty { startIndex = offset }
                current.append(character)
            } else if !current.isEmpty {
                tokens.append(Token(text: current, start: startIndex, end: offset))
                current = ""
            }
        }
        if !current.isEmpty {
            tokens.append(Token(text: current, start: startIndex, end: text.count))
        }
        return tokens
    }

    /// Finds every occurrence of `term` in `text` that sits on word
    /// boundaries.
    ///
    /// The boundary check is what prevents "egg" from matching inside
    /// "eggplant" or "soy" inside "soybean oil"… while still allowing the
    /// legitimate multi-word synonyms to match as whole phrases.
    func wordBoundaryRanges(of term: String, in text: String) -> [(Int, Int)] {
        guard !term.isEmpty, text.count >= term.count else { return [] }

        let characters = Array(text)
        let termCharacters = Array(term)
        var results: [(Int, Int)] = []

        let limit = characters.count - termCharacters.count
        guard limit >= 0 else { return [] }

        for start in 0...limit {
            let end = start + termCharacters.count
            guard Array(characters[start..<end]) == termCharacters else { continue }

            let hasLetterBefore = start > 0 && isWordCharacter(characters[start - 1])
            let hasLetterAfter = end < characters.count && isWordCharacter(characters[end])

            if !hasLetterBefore && !hasLetterAfter {
                results.append((start, end))
            }
        }
        return results
    }

    /// True when a match shares any characters with an excluded phrase.
    ///
    /// Two ranges overlap when each starts before the other ends.
    func overlapsExclusion(_ range: (Int, Int), _ exclusions: [(Int, Int)]) -> Bool {
        exclusions.contains { exclusion in
            range.0 < exclusion.1 && range.1 > exclusion.0
        }
    }

    /// Character ranges covered by any of the given phrases.
    func ranges(ofAny phrases: [String], in text: String) -> [(Int, Int)] {
        var results: [(Int, Int)] = []
        for phrase in phrases {
            results.append(contentsOf: wordBoundaryRanges(of: phrase, in: text))
        }
        return results
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    /// True when two words differ by at most one insertion, deletion,
    /// substitution, or transposition of adjacent characters.
    ///
    /// This is a bounded Damerau-Levenshtein check rather than a full
    /// distance calculation: we only ever care whether the distance is 0 or
    /// 1, so it can bail out early and stay cheap inside the matching loop.
    ///
    /// Transpositions are included deliberately. Swapping two neighbouring
    /// letters — "casien" for "casein" — is the single most common error
    /// both in OCR output and in hand-typed text, and plain Levenshtein
    /// scores it as distance 2, which would let it slip through unflagged.
    func isWithinOneEdit(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }

        let left = Array(lhs)
        let right = Array(rhs)
        let difference = left.count - right.count
        guard abs(difference) <= 1 else { return false }

        // Same length: allow one substitution, or one adjacent swap.
        if difference == 0 {
            var mismatchIndices: [Int] = []
            for index in 0..<left.count where left[index] != right[index] {
                mismatchIndices.append(index)
                if mismatchIndices.count > 2 { return false }
            }

            // Exactly one differing position is a substitution.
            if mismatchIndices.count == 1 { return true }

            // Exactly two adjacent differing positions may be a swap.
            if mismatchIndices.count == 2 {
                let first = mismatchIndices[0]
                let second = mismatchIndices[1]
                guard second == first + 1 else { return false }
                return left[first] == right[second] && left[second] == right[first]
            }

            return false
        }

        // Different lengths: allow exactly one insertion or deletion.
        let longer = difference > 0 ? left : right
        let shorter = difference > 0 ? right : left

        var longerIndex = 0
        var shorterIndex = 0
        var skipped = false

        while longerIndex < longer.count && shorterIndex < shorter.count {
            if longer[longerIndex] == shorter[shorterIndex] {
                longerIndex += 1
                shorterIndex += 1
                continue
            }
            if skipped { return false }
            skipped = true
            longerIndex += 1
        }
        return true
    }
}

// MARK: - String helper

nonisolated extension String {
    /// Capitalises only the first character, leaving the rest alone so that
    /// "whey powder" becomes "Whey powder" rather than "Whey Powder".
    var capitalisedFirst: String {
        guard let first = first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
