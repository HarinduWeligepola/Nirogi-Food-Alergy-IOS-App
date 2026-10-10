# AI Usage Log

**SE4041 Assignment 02 Part A · Nirogi · Harindu Weligepola · IT23257504**

The assignment brief requires that any use of AI tools be documented, including
the interactions and an explanation of how they assisted development. This file
is that record.

> **Note to the reader.** This log is written to be accurate rather than
> flattering. Where AI generated code, it says so.

---

## 1. Tool used

| | |
|---|---|
| Tool | **Claude (Anthropic)**, used through Claude Code in the terminal |
| Period | Single extended working session, 10 October 2026 |
| Access | The tool could read and write files in the project, run `xcodebuild`, run the test suite, and drive the iOS Simulator to take screenshots |

No other AI tools (GitHub Copilot, ChatGPT, etc.) were used.

---

## 2. Summary of how it was used

| Phase | My contribution | AI contribution |
|---|---|---|
| Understanding the brief | Supplied the brief, asked for a rubric breakdown | Extracted and tabulated the marking criteria |
| Choosing a technology | Stated constraints (simple, few screens, must be demoable) | Compared Vision / ARKit / HealthKit / MapKit and recommended Vision |
| Choosing the concept | Asked for original ideas; **chose SafeBite** from three options | Proposed three concepts with target audiences |
| Naming and branding | Asked for a Sri Lankan name; **chose Nirogi** from seven options | Proposed names, palette, logo prompt |
| Logo | **Generated the logo myself** with an image generator, using the supplied prompt | Wrote the prompt; converted the image to app-icon variants |
| Scope decisions | **Chose** the four optional features, device availability, sample strategy, git workflow | Presented the options and trade-offs |
| Implementation | Direction and review | **Wrote the majority of the Swift source** |
| Debugging | Direction and review | Diagnosed and fixed the bugs described in the report |
| Documentation | Direction and review | Drafted README, user guide, technical docs, report |

**In plain terms:** the concept, the name, the feature scope and the logo were my
decisions. The Swift implementation was largely AI-generated under my direction,
then verified by building, running and testing it.

---

## 3. Interaction log

### 3.1 Understanding the assignment

> **Prompt:** *"read these carefully before doing anything. From this chat i just
> wanna do the Assignment 02 part A only. So i need u to read and tell me wt do
> i have to do according to marking rubric."*

The tool read the PDF and produced a table of the eight rubric criteria with
their marks, plus the submission requirements. **How it assisted:** it turned a
seven-page brief into a checklist I could work against, and flagged requirements
that are easy to miss — the AI usage log, feature branches, and Dynamic Type.

### 3.2 Choosing the emerging technology

> **Prompt:** *"okay then wt u suggets which emerging technology should i use for
> this"*

Recommended **Core ML / Vision**, with reasoning: it scores well on the rubric,
works in the Simulator (unlike ARKit and HealthKit, which need a device), is
explainable in a viva, and demonstrates instantly.

**How it assisted:** it ruled out ARKit early. I had been considering AR because
it looks impressive, and the point that it cannot be demonstrated without a
physical device — and is fragile in a live demo — changed my decision.

### 3.3 Choosing the concept

> **Prompt:** *"now i want to give me an inovative idea for an app. that no one is
> maybe made for this assignmnet. and has to be simple and few screens"*

Three concepts were proposed: an allergen label scanner, a noise-sensitivity
diary using SoundAnalysis, and a flashcard generator. **I chose the allergen
scanner.**

> **Prompt:** *"safebite is nice. can u tell me more abt that. how it says that it
> will harmful specially for me"*

This produced the explanation of the four-part mechanism — profile, synonym
knowledge base, OCR, matching engine — including the worked example of one
biscuit label giving different verdicts to two users. **That worked example
became the core demonstration of the app**, and the structure it described
became the actual architecture.

### 3.4 Naming and visual identity

> **Prompt:** *"now i want to change the name that matches for our country"*

Seven Sinhala and Tamil names were proposed. **I chose Nirogi** (නිරෝගී).

> **Prompt:** *"can u suggest the best color palette … and for the logo give me a
> prompt to make it using a image generator ai. and i need to make the app in
> liquid glass theme."*

Produced the jade-and-turmeric palette **with contrast ratios computed and
checked against WCAG 2.1**, a logo prompt, and Liquid Glass guidance. The first
palette draft failed AA for body text and was corrected before any code was
written.

**How it assisted:** the contrast checking was genuinely useful. I would not
have known that my first jade was too light for body text, and fixing it before
implementation saved reworking every screen.

**I then generated the logo myself** using the supplied prompt and an image
generator, and supplied the result.

### 3.5 Scope decisions

Before implementation the tool asked four questions rather than assuming:
which optional features to build, whether a physical iPhone was available, how
to source test labels, and whether to use feature branches.

**I chose** all four optional features, confirmed I have an iPhone, chose both
synthetic and real sample labels, and chose feature branches.

### 3.6 Implementation

> **Prompt:** *"now u can proceed with the full app creation."*

The tool wrote the Swift source, building and running after each stage. Written
output included: the design tokens, the data models, the allergen knowledge base
(20 allergens, 303 synonyms), the label parser, the matching engine, the Vision
service, six screens, the component library, the test suites and the
localization catalogue.

It also generated the five sample label images programmatically, installed the
app icon variants, and patched the Xcode project file to add the test targets.

**How it assisted:** this is where the bulk of the time saving was. It is also
the part I must be able to explain in the viva, so I have read through the
engine and parser in detail — those are the files where the actual thinking is.

### 3.7 Debugging — the most valuable part

Five bugs were found and fixed during development. These interactions were the
most useful, because they involved reasoning about *why* real OCR output differs
from what you expect.

**Bug 1 — "coconut milk" flagged as dairy.** Caught by a test the tool wrote
against its own code. Fixed with exclusion phrases and longest-match resolution.

**Bug 2 — `milk powder` overlapping an exclusion.** A unit test
(`testLongestMatchWins`) failed and exposed that a *containment* check was not
enough; the check had to be *overlap*. Worth noting: the test caught a genuine
logic error, not a typo.

**Bug 3 — salt reported as `322` from `E322`.** An additive code in the
ingredient list was being read as a nutrition value.

**Bug 4 — 620 g of sugar.** Found by running the app and reading the "What the
scan saw" panel, which revealed Vision had returned the nutrition table
**column by column**. This is the bug I understand best and would most want to
be asked about, because the cause is not a coding mistake — it is a mismatch
between how a table looks and how OCR reports it.

**Bug 5 — a vanishing peanut warning.** Scanning a real sample label showed the
trace warning was being silently discarded because it sat under an
`ALLERGEN ADVICE:` heading, which the parser treated as the end of the
ingredient list.

**How it assisted:** bugs 4 and 5 were only found by *running the app against
real Vision output*, not by inspecting code. The lesson recorded in the report —
that my own invented test fixtures encoded my own assumptions — came from this.

### 3.8 Localization

Sinhala and Tamil translations for 92 interface strings were drafted by the
tool. It also diagnosed why part of the interface stayed English after the
catalogue was added (SwiftUI only auto-localizes literals passed directly into
`Text`).

> ⚠️ **Verification required.** The Sinhala and Tamil translations are
> machine-generated. I am reviewing the **Sinhala** myself as a native speaker,
> and the **Tamil** needs checking by a Tamil speaker before submission. They
> should not be presented as verified translations until that is done.

### 3.9 Documentation

The README, user guide, technical documentation and the report were drafted by
the tool from the actual state of the code and the actual test results. The
reflections in the report reflect the real sequence of problems encountered in
this session.

---

## 4. What AI did *not* do

- It did not choose the app concept, the name, the feature scope or the logo
- It did not invent the test results — every figure quoted (76 tests, contrast
  ratios, verdicts) comes from a command that was actually run
- It did not claim anything was working without building and running it; each
  of the five bugs above was found *because* the app was actually executed

---

## 5. Honest assessment

The tool was most valuable in two places: **breadth** — producing a 303-term
knowledge base and a 76-test suite far faster than I could have by hand — and
**the debugging loop**, where running the app, reading the raw OCR output and
reasoning about the mismatch produced the genuine engineering content of this
project.

It was least valuable where judgement was needed. Every decision that shaped the
app — reading labels rather than building AR, a Sri Lankan allergen scanner
rather than a note-taking app, Nirogi rather than SafeBite, including Maldive
fish because foreign apps miss it — was a human decision.

For the viva I have focused my own study on the files where the real logic
lives: `SafetyEngine.swift`, `LabelParser.swift` and `OCRService.swift`, and in
particular the longest-match resolution, the overlap-based exclusion check, the
Damerau-Levenshtein fuzzy matching, and the two nutrition table layouts.

---

*Prepared by Harindu Weligepola (IT23257504) in accordance with the
AI-Assisted Development clause of the SE4041 Assignment 02 brief.*
