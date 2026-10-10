//
//  GlassCard.swift
//  Nirogi (IT23257504-PartA)
//
//  The app's custom SwiftUI component and custom view modifier.
//
//  Every panel in Nirogi is a GlassCard, which is what gives the app a
//  single consistent surface treatment built on iOS 26's Liquid Glass.
//  Centralising it here means the entire app's material can be changed
//  from one place.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI

// MARK: - Custom view modifier

/// Applies the app's standard glass surface to any view.
///
/// Liquid Glass refracts whatever sits behind it, so a card placed on a
/// plain background would be nearly invisible. `ensureLegibility` paints a
/// faint opaque layer underneath, which is switched on wherever a card sits
/// over a photograph and readability must be guaranteed.
struct GlassCardModifier: ViewModifier {

    /// Corner radius of the card.
    var cornerRadius: CGFloat = Theme.Radius.lg
    /// Inner padding around the content.
    var padding: CGFloat = Theme.Spacing.md
    /// Optional tint pulled through the glass, used for verdict cards.
    var tint: Color?
    /// Adds an opaque backing layer for text over busy imagery.
    var ensureLegibility: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if ensureLegibility {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.Palette.surface.opacity(0.72))
                }
            }
            .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    }

    /// Builds the glass style, tinting it only when a tint was supplied.
    private var glass: Glass {
        if let tint {
            return .regular.tint(tint.opacity(0.28))
        }
        return .regular
    }
}

extension View {
    /// Wraps the view in the app's standard glass card surface.
    ///
    /// - Parameters:
    ///   - cornerRadius: corner radius of the card.
    ///   - padding: inner padding around the content.
    ///   - tint: optional colour pulled through the glass.
    ///   - ensureLegibility: adds an opaque backing for text over photos.
    func nirogiCard(cornerRadius: CGFloat = Theme.Radius.lg,
                    padding: CGFloat = Theme.Spacing.md,
                    tint: Color? = nil,
                    ensureLegibility: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius,
                                   padding: padding,
                                   tint: tint,
                                   ensureLegibility: ensureLegibility))
    }
}

// MARK: - Custom component

/// A titled glass panel, the standard building block for Nirogi's screens.
struct GlassCard<Content: View>: View {

    /// Optional heading shown above the content.
    ///
    /// Typed as `LocalizedStringKey` rather than `String` so that literals
    /// written at the call site are picked up by the string catalogue.
    /// SwiftUI only auto-localises literals passed straight into `Text`;
    /// a `String` variable is rendered verbatim.
    var title: LocalizedStringKey?
    /// Optional SF Symbol shown beside the heading.
    var symbolName: String?
    /// Optional tint pulled through the glass.
    var tint: Color?
    /// Adds an opaque backing for use over photographs.
    var ensureLegibility: Bool = false

    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let title {
                Label {
                    Text(title)
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Palette.ink)
                } icon: {
                    if let symbolName {
                        Image(systemName: symbolName)
                            .foregroundStyle(tint ?? Theme.Palette.jade)
                    }
                }
                // The heading already reads as a header to VoiceOver, so the
                // icon beside it is decorative and should not be announced.
                .accessibilityAddTraits(.isHeader)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nirogiCard(tint: tint, ensureLegibility: ensureLegibility)
    }
}

// MARK: - Section heading

/// A small heading used between cards on a screen.
struct SectionHeading: View {
    let text: LocalizedStringKey
    var symbolName: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.footnote.weight(.semibold))
            }
            Text(text)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
        }
        .foregroundStyle(Theme.Palette.inkMuted)
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, Theme.Spacing.xxs)
    }
}

#Preview("Glass cards") {
    ZStack {
        LinearGradient(colors: [Theme.Palette.jade.opacity(0.35), Theme.Palette.turmeric.opacity(0.2)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        VStack(spacing: Theme.Spacing.md) {
            SectionHeading(text: "Recent", symbolName: "clock")

            GlassCard(title: "Munchee Lemon Puff", symbolName: "leaf.fill") {
                Text("Contains dairy and gluten.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }

            GlassCard(title: "Avoid", symbolName: "xmark.octagon.fill",
                      tint: Color("VerdictAvoid")) {
                Text("Whey powder is a milk protein.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
        }
        .padding()
    }
}
