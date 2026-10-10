# Nirogi — Technical Documentation

**SE4041 Assignment 02 Part A · Harindu Weligepola · IT23257504**

---

## Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [The scan pipeline](#3-the-scan-pipeline)
4. [The matching algorithm](#4-the-matching-algorithm)
5. [Nutrition parsing](#5-nutrition-parsing)
6. [Data model](#6-data-model)
7. [The interface layer](#7-the-interface-layer)
8. [Accessibility](#8-accessibility)
9. [Localization](#9-localization)
10. [Performance](#10-performance)
11. [Testing](#11-testing)
12. [Limitations](#12-limitations)

---

## 1. Overview

Nirogi is a SwiftUI app for iOS 26 that reads a food label with Apple's Vision
framework and decides whether it is safe for one specific user.

| | |
|---|---|
| Minimum iOS | 26.1 |
| Language | Swift 5 language mode |
| UI | SwiftUI with Liquid Glass |
| Persistence | SwiftData |
| Emerging technology | Vision (OCR + barcode), plus MapKit and Localization |
| Third-party dependencies | None |
| Bundle identifier | `lk.ac.sliit.IT23257504-PartA` |

---

## 2. Architecture

The app follows **MVVM** with a clear dependency direction: views depend on view
models, view models depend on services, and services depend on nothing but
Foundation.

```
┌──────────────────────────────────────────────────────┐
│ Views (SwiftUI)                                      │
│   OnboardingView · HomeView · ScanView               │
│   ResultView · ProfileView · ScanMapView             │
└───────────────┬──────────────────────────────────────┘
                │ observes
┌───────────────▼──────────────────────────────────────┐
│ View models                                          │
│   ScanViewModel  (@Observable, @MainActor)           │
└───────────────┬──────────────────────────────────────┘
                │ calls
┌───────────────▼──────────────────────────────────────┐
│ Services  — no UI, no persistence                    │
│   OCRService · LabelParser · SafetyEngine            │
│   AllergenKnowledgeBase                              │
└───────────────┬──────────────────────────────────────┘
                │ operates on
┌───────────────▼──────────────────────────────────────┐
│ Models                                               │
│   Value types: Allergen, Finding, Verdict, …         │
│   SwiftData:   UserProfile, ScanRecord               │
└──────────────────────────────────────────────────────┘
```

### The decision that shaped everything

**`SafetyEngine` has no dependency on SwiftUI, SwiftData or Vision.** It takes
value types in and returns value types out.

This single constraint produced three benefits:

1. **Testability.** The core logic is verified by 67 unit tests that need no
   simulator, no camera and no database.
2. **Concurrency safety.** Because it touches no shared mutable state, parsing
   and matching run on a background task without any locking.
3. **Reusability.** The same engine judges a fresh scan and re-judges a saved
   one, with no duplicated logic.

To keep that boundary, the SwiftData `UserProfile` exposes a `snapshot` property
returning an immutable `ProfileSnapshot`. The engine only ever sees the
snapshot, never the model.

### Composition root

`AppEnvironment` builds the knowledge base, engine and OCR service once at
launch and injects them through the SwiftUI environment. Parsing a
300-term JSON database happens once, not on every render.

---

## 3. The scan pipeline

```
UIImage
  │
  ├─ OCRService ─────────────────────────────── Vision
  │    ├─ RecognizeTextRequest   → text, confidence
  │    └─ DetectBarcodesRequest  → barcode        (concurrent)
  │
  ├─ LabelParser ──────────────────────────── pure text processing
  │    ├─ normalise           repair OCR noise
  │    ├─ splitIngredientSection   list vs trace warning
  │    ├─ splitIntoIngredients     individual items
  │    └─ parseNutrition           numeric values
  │
  └─ SafetyEngine ─────────────────────────── matching
       ├─ resolvedMatches    find allergens, resolve overlaps
       ├─ finding(for:)      apply the user's rules
       ├─ deduplicate        one finding per allergen and kind
       └─ overallVerdict     most serious wins
                │
                ▼
         AnalysisResult
```

### OCR configuration

Three settings in `OCRService` are deliberate and worth defending in a viva:

| Setting | Value | Why |
|---|---|---|
| `recognitionLevel` | `.accurate` | Ingredient lists are small, dense print. A misread word could mean a missed allergen. |
| `usesLanguageCorrection` | **`false`** | Language correction is tuned for ordinary prose and would "helpfully" rewrite unfamiliar technical words. Since those exact words are what we match on, raw output is safer. |
| `recognitionLanguages` | `en-US` | Vision cannot read Sinhala or Tamil script, so the app targets the English portion of a trilingual label. |

Text recognition and barcode detection run **concurrently** with `async let`,
because they are independent passes over the same image. A missing barcode is
normal, not an error, so its failure is ignored rather than propagated.

### Quality reporting

`ScanOutput.isLowQuality` is true when average confidence is below 0.45 or fewer
than two text blocks were found. The result screen then warns the user to retake
the photo rather than silently trusting a bad read.

---

## 4. The matching algorithm

This is the core of the app. The goal: find allergens the label does not name
directly, without inventing ones that are not there.

### 4.1 The knowledge base

`Resources/allergens.json` holds **20 allergens** and **303 search terms**.

```json
{
  "id": "dairy",
  "name": "Dairy",
  "note": "Derived from cow's milk.",
  "isLocallyCommon": true,
  "exclusions": ["coconut milk", "soy milk", "cocoa butter", "…"],
  "synonyms": ["whey", "casein", "sodium caseinate", "ghee", "lactose", "…"]
}
```

`synonyms` is what finds hidden allergens. `exclusions` is what prevents false
positives. `isLocallyCommon` surfaces Sri Lankan allergens first in the UI.

### 4.2 Matching, step by step

For each ingredient the parser produced:

**Step 1 — Find every candidate, for every allergen.**
Matching runs against *all* allergens, not just the user's, because a match the
user does not care about may still be needed to veto one they do.

**Step 2 — Require word boundaries.**
A term only matches when neither neighbouring character is alphanumeric. This is
what stops `egg` matching inside `eggplant`, while still allowing multi-word
phrases like `arachis oil` to match as a whole.

**Step 3 — Apply exclusions.**
A candidate is discarded if it **overlaps** an excluded phrase.

> Overlap, not containment. In `coconut milk powder`, the dairy synonym
> `milk powder` (characters 8–19) runs *past* the end of the excluded phrase
> `coconut milk` (0–12). A containment check would let it through and report
> coconut milk powder as dairy. This was a real bug, caught by a unit test.

**Step 4 — Longest match wins.**
Candidates are sorted by length, and a candidate is dropped if it sits inside an
already-kept match. In `coconut milk`:

| Candidate | Allergen | Range | Outcome |
|---|---|---|---|
| `coconut milk` | coconut | 0–12 | **kept** (longest) |
| `coconut` | coconut | 0–7 | dropped, inside the above |
| `milk` | dairy | 8–12 | dropped, inside the above |

This is the second line of defence after exclusions, and it generalises: the
most specific reading of a phrase always wins.

**Step 5 — Fuzzy matching, only if nothing matched cleanly.**
If an allergen produced no exact or synonym match, each word of at least five
characters is compared against its single-word terms using a bounded
**Damerau-Levenshtein** check.

> Transpositions are included deliberately. Swapping two neighbouring letters —
> `casien` for `casein` — is the most common OCR error, and plain Levenshtein
> scores it as distance **2**, which would let it slip through unflagged.

The check bails out early: it only ever asks whether the distance is 0 or 1, so
it stays cheap inside the matching loop. Short words are excluded because one
character of slack on `egg` or `soy` would match far too much.

### 4.3 From match to finding

A raw match becomes a `Finding` only if the user cares about it:

| Condition | Finding kind | Severity |
|---|---|---|
| User has an allergy rule, ingredient listed | `.contains` | the user's |
| User has an allergy rule, trace warning | `.mayContain` | the user's |
| No allergy, but breaks a dietary preference | `.dietaryConflict` | mild |
| Nutrient exceeds the user's limit | `.overLimit` | mild |
| Otherwise | *no finding* | — |

### 4.4 Severity to verdict

```swift
switch kind {
case .contains:
    return severity >= .moderate ? .avoid : .caution
case .mayContain:
    return severity == .severe ? .avoid : .caution
case .overLimit, .dietaryConflict:
    return .caution
}
```

The reasoning: a trace warning is a manufacturer's hedge, so it only escalates
to Avoid for a severe allergy where the risk is real. A dietary conflict is
never a medical danger, so it never exceeds Caution.

### 4.5 Deduplication and composition

A label naming *milk solids*, *whey* and *casein* would otherwise produce three
near-identical dairy warnings. Findings are collapsed to one per
(allergen, kind) pair, keeping the highest-confidence and most specific
evidence. The overall verdict is then the most serious of what remains, and
findings are sorted most-serious-first for display.

---

## 5. Nutrition parsing

Reading numbers turned out to be harder than reading words, because Vision
reports *what it sees*, not what a table means. Two layouts must be handled.

**Inline** — the common case:

```
Energy 480 kcal, Sugar 22.5 g, Salt 1.2 g
```

**Column-major** — when the printed table has a wide gap between its two
columns, Vision returns every name first and every value afterwards:

```
Energy
Sugar
Salt
620 kcal
8.0 g
180 mg
```

A naive parser pairs `Sugar` with the energy figure and reports **620 g of
sugar**. For a diabetic user a wrong number is worse than no number.

### The defences

1. **Line structure is preserved** for nutrition parsing, unlike ingredient
   parsing where line breaks are just separators. Whether a value shares a line
   with its name is exactly what distinguishes the two layouts.
2. **Scoped to the table.** Values are only read after a nutrition heading, so
   the `322` in `Soy Lecithin (E322)` can never be read as salt.
3. **Windows are cut at the next nutrient's name**, so a keyword cannot capture
   its neighbour's figure.
4. **Units must match.** Sugar accepts `g`/`mg`, energy accepts `kcal`/`kj`.
5. **Column pairing is positional but guarded** — it only applies when the
   layout genuinely is one block of names followed by one block of values, and
   every pairing is unit-checked before being accepted.

### Unit normalisation

Labels report salt in grams or milligrams interchangeably. Comparing `1.2 g`
against a `1500 mg` limit without converting would silently pass a salty
product, so every value is normalised to one unit per nutrient.

---

## 6. Data model

### Persisted (SwiftData)

**`UserProfile`** — one per device.

| Property | Type | Notes |
|---|---|---|
| `rules` | `[AllergenRule]` | Allergen + severity, Codable, stored inline |
| `dietaryPreferenceIDs` | `[String]` | Raw strings for forward compatibility |
| `healthLimits` | `[HealthLimit]` | Per-nutrient ceilings |
| `hasAcceptedDisclaimer` | `Bool` | Gates the app on first launch |

**`ScanRecord`** — one per saved scan.

| Property | Type | Notes |
|---|---|---|
| `rawText` | `String` | Exactly what Vision read, so a user can audit a verdict |
| `ingredients` | `[String]` | Parsed, in label order |
| `verdictRaw` | `String` | Stored as a string, not an enum |
| `findings` | `[Finding]` | The evidence |
| `imageData` | `Data?` | `@Attribute(.externalStorage)` |
| `latitude` / `longitude` | `Double?` | Optional place tagging |

### Two deliberate choices

**Enums are stored as raw strings.** Adding a new verdict case in a future build
cannot then break decoding of existing records. An unrecognised value falls back
to `.caution` — *failing towards caution rather than safety is the correct bias
for a health app.*

**Images use `.externalStorage`.** A full-resolution capture is several
megabytes. Keeping images as files on disk rather than inside the database keeps
history queries fast as the record count grows. Images are also JPEG-compressed
at 0.6 before saving.

---

## 7. The interface layer

### Navigation

`TabView` with four tabs, each owning its own `NavigationStack`: Home, Scan,
Places, Profile. The app has six distinct screens in total, exceeding the
three-screen requirement.

### Liquid Glass

Every panel is a `GlassCard`, the app's custom component, built on the custom
`GlassCardModifier` (`.nirogiCard()`). Centralising the surface treatment means
the whole app's material can be changed from one file.

```swift
content
    .padding(padding)
    .background { if ensureLegibility { /* opaque scrim */ } }
    .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
```

Two details matter:

- **`ensureLegibility`** paints a faint opaque layer under the glass wherever a
  card sits over a photograph. Liquid Glass refracts what is behind it, so
  verdict text over a busy label photo would otherwise be hard to read.
- **The background gradient** exists so the glass has something to refract. On
  a flat background, Liquid Glass looks grey and lifeless.

### Custom component and modifier

The brief requires at least one of each. Nirogi has:

| Type | Name | Purpose |
|---|---|---|
| Component | `GlassCard` | Titled glass panel used on every screen |
| Modifier | `GlassCardModifier` / `.nirogiCard()` | The surface treatment itself |
| Layout | `FlowLayout` | Wrapping chip layout (a custom `Layout`) |
| Component | `VerdictCard`, `VerdictBadge`, `FindingRow`, `EmptyState` | Result presentation |

`FlowLayout` is a custom `Layout` conformance rather than nested stacks,
specifically so chips reflow correctly at accessibility text sizes where a
fixed-column grid would clip long allergen names.

### Design tokens

`Theme.swift` holds every colour, spacing step, radius, text style and animation
curve. No view hard-codes a value. Colours resolve from the asset catalogue, so
Dark Mode works automatically.

---

## 8. Accessibility

| Requirement | How it is met |
|---|---|
| **Dark Mode** | Every one of the 15 colour tokens has a separate dark variant |
| **Dynamic Type** | All text uses system text styles; `FlowLayout` reflows rather than clipping |
| **Colour independence** | Verdicts pair colour with a distinct symbol outline *and* an explicit word |
| **VoiceOver** | Verdicts and findings announce as a single combined phrase; decorative icons are hidden |
| **Reduce Motion** | The verdict icon only animates when the user has not asked for reduced motion |
| **Contrast** | Verified against WCAG 2.1 |

### Measured contrast ratios

| Token | Light | Dark |
|---|---|---|
| Primary text | 15.35:1 (AAA) | 16.51:1 (AAA) |
| Secondary text | 5.76:1 (AA) | 7.69:1 (AAA) |
| Brand jade (text) | 6.61:1 (AA) | 9.77:1 (AAA) |
| Safe | 6.12:1 (AA) | 10.78:1 (AAA) |
| Caution | 5.08:1 (AA) | 11.23:1 (AAA) |
| Avoid | 6.26:1 (AA) | 7.39:1 (AAA) |

Separate `…Text` tokens exist for light mode precisely because the fill colours
that look right on a badge are too light to pass contrast as body text.

---

## 9. Localization

A String Catalog (`Localizable.xcstrings`) with **92 keys** in English, Sinhala
and Tamil.

One non-obvious pitfall, worth knowing: **SwiftUI only auto-localizes string
literals passed directly into `Text`.** A `String` variable renders verbatim and
silently stays English. Three changes were needed:

1. Component parameters changed from `String` to `LocalizedStringKey`
2. Helper functions likewise
3. Model-supplied strings call `String(localized:)` themselves

---

## 10. Performance

| Decision | Effect |
|---|---|
| Knowledge base parsed once at launch | Not re-parsed per scan or per render |
| Allergen lookups via dictionary index | Not a linear scan of 303 terms |
| Parsing and matching on a detached task | Interface stays responsive during a scan |
| Fuzzy matching only when nothing matched | The expensive path is the rare path |
| Bounded edit-distance with early exit | Never computes a full distance matrix |
| Images JPEG-compressed and externally stored | History queries stay fast |
| Search terms pre-sorted longest-first | Ordering computed once, not per match |

Performance baselines are measured by `XCTest`'s `measure` for parsing, analysis
and app launch.

---

## 11. Testing

**76 tests, all passing.**

| Suite | Count | Covers |
|---|---|---|
| `SafetyEngineTests` | 30 | Per-user verdicts, hidden names, local ingredients, false positives, word boundaries, severity scaling, OCR tolerance, deduplication, diets, nutrient limits |
| `LabelParserTests` | 22 | Ingredient splitting, trace warnings, both nutrition layouts, unit conversion, OCR noise, edge cases |
| `ModelTests` | 15 | Profile mutation, snapshots, persistence round-trips, knowledge-base integrity |
| `NirogiUITests` | 9 | End-to-end journeys through the real app with real Vision OCR |

The UI tests mock nothing. A bundled image goes through Vision, the parser and
the engine, and the verdict is read back off the screen.

See [REPORT.md](REPORT.md) for what the tests found.

---

## 12. Limitations

Stated honestly, because an app that handles allergy information should not
overclaim.

| Limitation | Detail |
|---|---|
| **Script support** | Vision cannot read Sinhala or Tamil script. The app reads the English portion of a trilingual label. |
| **Photo quality** | Curved, glossy or poorly lit packets reduce accuracy. The app reports low confidence rather than hiding it. |
| **Knowledge base coverage** | 303 terms is substantial but not exhaustive. An unlisted synonym will be missed. |
| **Recipe changes** | Manufacturers change formulations without warning. |
| **Single profile** | One profile per device; no family or multi-user support. |
| **Barcode lookup** | Barcodes are detected and stored, but there is no product database behind them yet. |
| **Not medical advice** | The app is an aid to reading a label, never a substitute for it. |
