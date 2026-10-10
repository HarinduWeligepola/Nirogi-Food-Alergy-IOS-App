//
//  VerdictViews.swift
//  Nirogi (IT23257504-PartA)
//
//  Views that present a verdict and the evidence behind it.
//
//  Accessibility note: a verdict is never communicated by colour alone.
//  Each one pairs a distinct colour with a distinct symbol outline (seal,
//  triangle, octagon) and an explicit word, so it remains readable in
//  greyscale and for the roughly 8% of men with colour vision deficiency.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI

// MARK: - Verdict colours

extension Verdict {
    /// Fill colour for badges and icons.
    var fillColor: Color { Color(fillColorName) }
    /// Darker variant for text, which clears WCAG AA contrast in light mode.
    var textColor: Color { Color(textColorName) }

    /// Plain-language summary shown under the verdict word.
    var explanation: String {
        switch self {
        case .safe: return String(localized: "Nothing on this label conflicts with your profile.")
        case .caution: return String(localized: "There is something here you should know about.")
        case .avoid: return String(localized: "This product conflicts with your profile.")
        }
    }
}

// MARK: - Verdict badge

/// Compact verdict indicator used in history rows.
struct VerdictBadge: View {
    let verdict: Verdict
    var compact: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: verdict.symbolName)
                .font(.caption.weight(.bold))
            if !compact {
                Text(verdict.title)
                    .font(.caption.weight(.semibold))
                    // The badge is a fixed-width ornament beside other
                    // content, so its label must never wrap mid-word.
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? Theme.Spacing.xs : Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(verdict.fillColor, in: .capsule)
        .fixedSize()
        // Capped deliberately. Body text must scale all the way up for
        // readability, but a badge that grows without limit breaks out of
        // its capsule and becomes less legible, not more. VoiceOver still
        // announces the verdict in full.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Announced as one phrase rather than icon-then-text.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(verdict.title)
    }
}

// MARK: - Verdict card

/// The large result banner shown at the top of a scan result.
struct VerdictCard: View {
    let verdict: Verdict
    let findingCount: Int

    /// Respects the user's Reduce Motion setting: the icon only pulses for
    /// users who have not asked for reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: verdict.symbolName)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(verdict.fillColor)
                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.6)
                .opacity(hasAppeared || reduceMotion ? 1 : 0)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verdict.title)
                    .font(Theme.Typography.verdict)
                    .foregroundStyle(verdict.textColor)

                Text(verdict.explanation)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if findingCount > 0 {
                    Text(findingCount == 1 ? "1 reason below" : "\(findingCount) reasons below")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
            }

            Spacer(minLength: 0)
        }
        .nirogiCard(tint: verdict.fillColor, ensureLegibility: true)
        .onAppear {
            withAnimation(Theme.Motion.entrance) { hasAppeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verdict.title). \(verdict.explanation)")
    }
}

// MARK: - Finding row

/// One piece of evidence behind a verdict, with its explanation.
struct FindingRow: View {
    let finding: Finding

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: finding.kind.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(finding.impliedVerdict.fillColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(finding.categoryName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Palette.ink)

                    Text(finding.kind.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(finding.impliedVerdict.textColor)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(finding.impliedVerdict.fillColor.opacity(0.18), in: .capsule)
                }

                // The matched words, so the user can find them on the packet.
                Text("Found: \u{201C}\(finding.matchedText)\u{201D}")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.jadeText)

                Text(finding.reason)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                // Warn when a match relied on correcting a likely scan error.
                if finding.matchType == .fuzzy {
                    Label("Possible scan error — please double-check the packet",
                          systemImage: "exclamationmark.magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(Color("VerdictCautionText"))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finding.categoryName), \(finding.kind.title). \(finding.reason)")
    }
}

// MARK: - Empty state

/// Shown when a list has nothing in it yet.
struct EmptyState: View {
    let symbolName: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.jade.opacity(0.7))

            Text(title)
                .font(Theme.Typography.heading)
                .foregroundStyle(Theme.Palette.ink)

            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .nirogiCard()
    }
}

#Preview("Verdicts") {
    ScrollView {
        VStack(spacing: Theme.Spacing.md) {
            VerdictCard(verdict: .avoid, findingCount: 2)
            VerdictCard(verdict: .caution, findingCount: 1)
            VerdictCard(verdict: .safe, findingCount: 0)

            GlassCard(title: "Why") {
                FindingRow(finding: Finding(
                    matchedText: "whey powder", categoryID: "dairy",
                    categoryName: "Dairy", severity: .moderate, kind: .contains,
                    matchType: .synonym,
                    reason: "Whey powder is a form of dairy. Derived from cow's milk.",
                    ingredientIndex: 3))
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
