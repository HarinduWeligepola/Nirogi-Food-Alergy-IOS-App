//
//  OnboardingView.swift
//  Nirogi (IT23257504-PartA)
//
//  First-run experience: explain what the app does, state plainly what it
//  is not, and collect enough of a profile for the first scan to be useful.
//
//  The disclaimer is a deliberate design decision rather than legal
//  boilerplate. Nirogi assists someone with a potentially dangerous allergy,
//  so it must be explicit that an OCR reading is an aid and never a
//  substitute for reading the packet.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {

    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var appEnvironment

    /// Which onboarding page is showing.
    @State private var page = 0
    /// Allergens picked during setup, before they are written to the profile.
    @State private var selected: Set<String> = []

    private let pageCount = 3

    var body: some View {
        ZStack {
            NirogiBackground()

            VStack(spacing: Theme.Spacing.lg) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    allergenPage.tag(1)
                    disclaimerPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                primaryButton
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(.rect(cornerRadius: Theme.Radius.lg))
                    .accessibilityHidden(true)
                    .padding(.top, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Nirogi")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.jadeText)

                    Text("නිරෝගී")
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.inkMuted)

                    Text("Know before you eat")
                        .font(Theme.Typography.heading)
                        .foregroundStyle(Theme.Palette.ink)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        onboardingPoint(
                            symbol: "text.viewfinder",
                            title: "Photograph the label",
                            detail: "Nirogi reads the ingredient list for you, right on your phone.")

                        onboardingPoint(
                            symbol: "person.text.rectangle",
                            title: "Checked against you",
                            detail: "It knows that casein means dairy and umbalakada means fish — even when the label does not say so.")

                        onboardingPoint(
                            symbol: "lock.shield",
                            title: "Private by design",
                            detail: "Nothing is uploaded. Your photos and your allergies never leave this device.")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private var allergenPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What should we watch for?")
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.Palette.ink)

                    Text("Pick anything you need to avoid. You can change these at any time, and set how serious each one is later.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
                .padding(.top, Theme.Spacing.xl)

                SectionHeading(text: "Common in Sri Lanka", symbolName: "mappin.and.ellipse")
                allergenGrid(appEnvironment.knowledgeBase.locallyCommon)

                SectionHeading(text: "Others", symbolName: "ellipsis.circle")
                allergenGrid(appEnvironment.knowledgeBase.others)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private var disclaimerPage: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color("VerdictCaution"))
                    .padding(.top, Theme.Spacing.xxl)
                    .accessibilityHidden(true)

                Text("Please read this")
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.Palette.ink)

                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Nirogi helps you read labels. It is not medical advice.")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.Palette.ink)

                        disclaimerPoint("Scanning can misread blurred, curved or poorly lit text.")
                        disclaimerPoint("Manufacturers change recipes without warning.")
                        disclaimerPoint("Always read the packet yourself before eating, especially for a severe allergy.")
                        disclaimerPoint("In an emergency, follow your doctor's advice and seek medical help.")
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Pieces

    private func onboardingPoint(symbol: String, title: LocalizedStringKey,
                                 detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.Palette.jade)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
                Text(detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func disclaimerPoint(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(Theme.Palette.inkMuted)
                .padding(.top, 7)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allergenGrid(_ allergens: [Allergen]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.xs)],
                  spacing: Theme.Spacing.xs) {
            ForEach(allergens) { allergen in
                allergenChip(allergen)
            }
        }
    }

    private func allergenChip(_ allergen: Allergen) -> some View {
        let isOn = selected.contains(allergen.id)

        return Button {
            withAnimation(Theme.Motion.quick) {
                if isOn { selected.remove(allergen.id) } else { selected.insert(allergen.id) }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isOn ? "checkmark.circle.fill" : allergen.symbolName)
                    .foregroundStyle(isOn ? Theme.Palette.jade : Theme.Palette.inkMuted)
                Text(allergen.name)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(Theme.Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(allergen.name)
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var pageIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.Palette.jade : Theme.Palette.hairline)
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(Theme.Motion.quick, value: page)
            }
        }
        .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button {
            advance()
        } label: {
            Text(page == pageCount - 1 ? "I understand — Start" : "Continue")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.Palette.jade)
    }

    // MARK: - Actions

    /// Moves to the next page, or finishes setup on the last one.
    private func advance() {
        guard page < pageCount - 1 else {
            completeSetup()
            return
        }
        withAnimation(Theme.Motion.standard) { page += 1 }
    }

    /// Writes the chosen allergens to the profile and unlocks the app.
    ///
    /// Everything selected here starts at `.moderate`, which produces an
    /// "Avoid" verdict. Starting cautious and letting the user relax a rule
    /// is safer than the reverse.
    private func completeSetup() {
        for id in selected {
            profile.setRule(categoryID: id, severity: .moderate)
        }
        profile.hasAcceptedDisclaimer = true
        profile.updatedAt = Date()
        try? context.save()
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    let profile = UserProfile()
    container.mainContext.insert(profile)

    return OnboardingView(profile: profile)
        .modelContainer(container)
        .environment(AppEnvironment.preview)
}
