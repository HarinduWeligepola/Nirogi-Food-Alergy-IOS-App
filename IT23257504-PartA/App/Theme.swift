//
//  Theme.swift
//  Nirogi (IT23257504-PartA)
//
//  Central design tokens for the app: colour, spacing, radius, typography
//  and motion. Every view reads from here rather than hard-coding values,
//  so the whole app can be re-themed from a single file.
//
//  Colour values live in Assets.xcassets as colour sets with both light and
//  dark variants, which is what gives the app automatic Dark Mode support.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI

/// Namespace for all design tokens. Deliberately an `enum` with no cases so
/// it can never be instantiated — it exists purely as a namespace.
enum Theme {

    // MARK: - Colour

    /// Semantic colour tokens. Each one resolves to a different value in
    /// light and dark mode automatically via the asset catalogue.
    enum Palette {
        /// Primary brand colour, used for fills, tints and controls.
        static let jade = Color("BrandJade")
        /// Darker jade reserved for *text*, so it clears WCAG AA (6.61:1).
        static let jadeText = Color("BrandJadeText")
        /// Warm secondary accent drawn from Sri Lankan turmeric.
        static let turmeric = Color("Turmeric")

        /// App-wide background behind all content.
        static let background = Color("AppBackground")
        /// Opaque card surface, used behind glass where legibility matters.
        static let surface = Color("Surface")

        /// Primary text colour (15.35:1 light, 16.51:1 dark).
        static let ink = Color("Ink")
        /// Secondary text for captions and supporting labels.
        static let inkMuted = Color("InkMuted")
        /// Thin separators and card borders.
        static let hairline = Color("Hairline")
    }

    // MARK: - Spacing

    /// A 4-point spacing scale. Using a fixed scale keeps rhythm consistent
    /// across screens and avoids arbitrary magic numbers in layout code.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner radius

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    /// Text styles are built on the system text styles (`.largeTitle`,
    /// `.body`, …) rather than fixed point sizes. That is what gives the app
    /// Dynamic Type support for free — text scales with the user's setting.
    enum Typography {
        /// Screen titles. Rounded design matches the organic, leafy branding.
        static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        /// Card and section headings.
        static let heading = Font.system(.title2, design: .rounded, weight: .semibold)
        /// The verdict word itself ("Safe", "Caution", "Avoid").
        static let verdict = Font.system(.title, design: .rounded, weight: .heavy)
        /// Standard body copy.
        static let body = Font.system(.body, design: .default)
        /// Supporting captions and metadata.
        static let caption = Font.system(.footnote, design: .default)
        /// Monospaced, for raw OCR text where character alignment helps.
        static let mono = Font.system(.footnote, design: .monospaced)
    }

    // MARK: - Motion

    /// Shared animation curves. Centralising these keeps motion coherent:
    /// everything in the app accelerates and settles the same way.
    enum Motion {
        /// Default for most state changes.
        static let standard = Animation.smooth(duration: 0.35)
        /// Springy curve for elements that appear, such as the verdict card.
        static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.75)
        /// Quick feedback for taps and toggles.
        static let quick = Animation.smooth(duration: 0.2)
    }
}
