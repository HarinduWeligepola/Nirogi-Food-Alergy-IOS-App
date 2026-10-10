# Nirogi · නිරෝගී

**Know before you eat.**

An iOS app that reads the ingredient list on a food packet with Apple's Vision
framework and judges it against *your* allergen profile — so the same label can
come back **Safe** for one person and **Avoid** for another.

Built for **SE4041 Mobile Application Design and Development**, Assignment 02
Part A, by **Harindu Weligepola (IT23257504)**, SLIIT Faculty of Computing.

<p align="center">
  <img src="docs/screenshots/06-result-avoid.png" width="240" alt="An Avoid verdict explaining that whey powder is dairy">
  <img src="docs/screenshots/07-result-safe.png" width="240" alt="A Safe verdict on a clean label">
  <img src="docs/screenshots/09-profile.png" width="240" alt="The allergen profile screen">
</p>

---

## The problem

Someone with a food allergy in a Sri Lankan supermarket has to read a tiny,
trilingual ingredient list and work out whether it is safe. That is harder than
it sounds, because allergens hide behind names that never mention the allergen:

| The label says | It actually contains |
|---|---|
| Sodium caseinate, whey, ghee | **Dairy** |
| Arachis oil, groundnut | **Peanut** |
| Umbalakada | **Maldive fish** |
| Semolina, maida, malt extract | **Gluten** |

International allergen apps do not know the local ones. **Umbalakada** appears
in a great many Sri Lankan savoury products and no foreign database lists it.

## What Nirogi does

1. You set your allergens once, with a severity for each.
2. You photograph the ingredients panel.
3. **Vision** reads the text on the device.
4. A matching engine checks every ingredient against **303 known names**,
   including the hidden ones.
5. You get a verdict — **Safe**, **Caution** or **Avoid** — and, crucially,
   *the reason*: which word was found, which rule it hit, and why they connect.

Nothing is uploaded. Photos, allergies and history never leave the phone.

---

## Requirements

| | |
|---|---|
| Xcode | 26.1 or later |
| iOS | 26.1 or later (simulator or device) |
| Swift | 5.0 language mode |
| Dependencies | **None** — Apple frameworks only |

## Build and run

```bash
git clone <repository-url>
cd IT23257504-PartA
open IT23257504-PartA.xcodeproj
```

Select the **IT23257504-PartA** scheme and an **iPhone 17 Pro** simulator, then
press **⌘R**.

Or from the command line:

```bash
xcodebuild -project IT23257504-PartA.xcodeproj -scheme IT23257504-PartA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

### Trying it without a camera

The simulator has no camera, so the app ships with **five sample labels**. Open
the **Scan** tab → **Try a Sample**. These are genuine scans: each image goes
through Vision exactly like a photograph, nothing is faked.

| Sample | What it demonstrates |
|---|---|
| Cream Biscuits | Hidden dairy (whey powder) plus a peanut trace warning |
| Cashew Chocolate Bar | Cashew and milk solids, very high sugar |
| Chilli Sambol Paste | Umbalakada — the local allergen foreign apps miss |
| Coconut Milk Powder | Proves "coconut milk" is **not** read as dairy |
| Plain Rice Crackers | A clean label, for a Safe verdict |

On a real device the **Take Photo** button appears and you can scan an actual
packet.

## Running the tests

```bash
xcodebuild test -project IT23257504-PartA.xcodeproj -scheme IT23257504-PartA -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**76 tests, all passing** — 67 unit tests and 9 UI tests. The UI tests drive the
real app with real Vision OCR; nothing is mocked.

---

## How it is built

```
IT23257504-PartA/
├── App/              Entry point, theme tokens, composition root, root view
├── Models/           Value types + SwiftData models
├── Services/         Knowledge base, label parser, safety engine, OCR
├── Components/       GlassCard, verdict views, custom layout
├── Features/         One folder per screen (MVVM)
│   ├── Onboarding/   Disclaimer and first-run setup
│   ├── Home/         Scan history
│   ├── Scan/         Image capture and OCR
│   ├── Result/       Verdict and evidence
│   ├── Profile/      Allergen rules
│   └── Map/          Where safe products were found
├── Resources/        allergens.json, Localizable.xcstrings
├── NirogiTests/      67 unit tests
└── NirogiUITests/    9 end-to-end tests
```

**Architecture: MVVM.** The one decision that shaped everything else is that
`SafetyEngine` has **no UI, SwiftData or Vision dependency**. It takes value
types in and returns value types out, which means the app's core logic can be
tested exhaustively without a simulator and run off the main actor.

### Apple frameworks used

| Framework | Used for |
|---|---|
| **Vision** | On-device text recognition and barcode detection |
| **SwiftUI** | The whole interface, including iOS 26 Liquid Glass |
| **SwiftData** | Profile and scan history persistence |
| **MapKit / CoreLocation** | Tagging where a product was found |
| **PhotosUI** | Choosing a label from the photo library |

## Accessibility

- **Dark Mode** throughout, with a separate colour set for every token
- **Dynamic Type** — all text uses system text styles, and a custom `FlowLayout`
  reflows chips rather than clipping them at accessibility sizes
- **Never colour alone** — each verdict pairs a colour with a distinct symbol
  outline (seal / triangle / octagon) and an explicit word, so it survives
  greyscale and colour vision deficiency
- **VoiceOver** labels on verdicts, findings and controls
- **Reduce Motion** respected on the verdict animation
- Contrast verified against WCAG 2.1: body text **5.76:1 or better** in light
  mode, **AAA** throughout in dark mode

## Languages

English, **Sinhala (සිංහල)** and **Tamil (தமிழ்)**, via a String Catalog.

> **Known limitation.** Vision cannot recognise Sinhala or Tamil *script*, so
> Nirogi reads the **English** portion of a trilingual label while presenting
> its own interface in the user's language. This is documented honestly rather
> than hidden.

## Documentation

| Document | What's in it |
|---|---|
| [User Guide](docs/USER_GUIDE.md) | How to use the app, screen by screen |
| [Technical Documentation](docs/TECHNICAL_DOCUMENTATION.md) | Architecture, the matching algorithm, data model |
| [Report](docs/REPORT.md) | Design decisions, challenges, testing, reflections |
| [AI Usage Log](docs/AI_USAGE_LOG.md) | How AI assistance was used, as required by the brief |

---

## ⚠️ Safety notice

**Nirogi assists with reading labels. It is not medical advice.**

Scanning can misread blurred, curved or poorly lit text, and manufacturers
change recipes without warning. Always check the packet yourself, especially
for a severe allergy. The app states this on first launch and on every result.

---

## Licence and attribution

Original work by Harindu Weligepola for SE4041. No third-party libraries are
used. The allergen knowledge base in `Resources/allergens.json` was compiled for
this project from publicly documented allergen synonyms and common Sri Lankan
ingredient names.
