//
//  ResultView.swift
//  Nirogi (IT23257504-PartA)
//
//  Shows the verdict and, crucially, the evidence behind it.
//
//  The guiding principle here is that the app must never say "no" without
//  saying why. Every finding names the exact words found on the label, the
//  rule they triggered, and the connection between them.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

struct ResultView: View {

    @Bindable var viewModel: ScanViewModel
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var productName = ""
    @State private var hasSaved = false
    @State private var showRawText = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let result = viewModel.result {
                    VerdictCard(verdict: result.verdict, findingCount: result.findings.count)

                    if let warning = viewModel.qualityWarning {
                        qualityWarningCard(warning)
                    }

                    if !result.findings.isEmpty {
                        findingsCard(result)
                    } else {
                        noFindingsCard
                    }

                    if !result.nutrition.isEmpty {
                        nutritionCard(result)
                    }

                    ingredientsCard(result)
                    rawTextCard
                    saveCard
                    disclaimerFooter
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .nirogiBackground()
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.reset()
                    dismiss()
                } label: {
                    Label("New scan", systemImage: "arrow.counterclockwise")
                }
            }
        }
        // Re-check against the latest profile whenever this screen appears.
        // This is what lets the user edit their allergies and immediately
        // see the same label judged differently.
        .onAppear {
            viewModel.reanalyse(profile: profile.snapshot)
        }
    }

    // MARK: - Cards

    private func qualityWarningCard(_ message: String) -> some View {
        GlassCard(title: "Low scan quality", symbolName: "camera.metering.unknown",
                  tint: Color("VerdictCaution")) {
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func findingsCard(_ result: AnalysisResult) -> some View {
        GlassCard(title: "Why", symbolName: "list.bullet.rectangle") {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(result.findings) { finding in
                    FindingRow(finding: finding)
                    if finding.id != result.findings.last?.id {
                        Divider().overlay(Theme.Palette.hairline)
                    }
                }
            }
        }
    }

    private var noFindingsCard: some View {
        GlassCard(title: "Nothing flagged", symbolName: "checkmark.seal.fill",
                  tint: Color("VerdictSafe")) {
            Text(profile.isEmpty
                 ? "You have not added any allergens yet, so there was nothing to check against. Add them in the Profile tab for a real verdict."
                 : "None of the ingredients matched anything in your profile.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nutritionCard(_ result: AnalysisResult) -> some View {
        GlassCard(title: "Nutrition per 100g", symbolName: "chart.bar.fill") {
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(result.nutrition) { value in
                    HStack {
                        Image(systemName: value.nutrient.symbolName)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.turmeric)
                            .frame(width: 20)

                        Text(value.nutrient.title)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.ink)

                        Spacer()

                        Text(value.displayAmount)
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isOverLimit(value) ? Color("VerdictCautionText") : Theme.Palette.ink)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(value.nutrient.title), \(value.displayAmount)\(isOverLimit(value) ? ", over your limit" : "")")
                }
            }
        }
    }

    /// Whether a nutrient exceeds one of the user's limits, used to colour
    /// the value.
    private func isOverLimit(_ value: NutrientValue) -> Bool {
        guard let limit = profile.healthLimits.first(where: { $0.nutrient == value.nutrient }) else {
            return false
        }
        return value.amountPer100g > limit.maxPer100g
    }

    private func ingredientsCard(_ result: AnalysisResult) -> some View {
        GlassCard(title: "Ingredients read", symbolName: "list.bullet") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(result.ingredients.count) items found. Flagged ones are highlighted.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)

                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(Array(result.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        ingredientChip(ingredient, isFlagged: isFlagged(index: index, in: result))
                    }
                }
            }
        }
    }

    /// True when a finding points at this ingredient position.
    private func isFlagged(index: Int, in result: AnalysisResult) -> Bool {
        result.findings.contains { $0.ingredientIndex == index }
    }

    private func ingredientChip(_ text: String, isFlagged: Bool) -> some View {
        Text(text)
            .font(.caption.weight(isFlagged ? .semibold : .regular))
            .foregroundStyle(isFlagged ? Color("VerdictAvoidText") : Theme.Palette.inkMuted)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 5)
            .background(
                isFlagged ? Color("VerdictAvoid").opacity(0.16) : Theme.Palette.hairline.opacity(0.5),
                in: .capsule)
            .accessibilityLabel(isFlagged ? "\(text), flagged" : text)
    }

    private var rawTextCard: some View {
        GlassCard {
            DisclosureGroup(isExpanded: $showRawText) {
                Text(viewModel.rawText.isEmpty ? "No text captured." : viewModel.rawText)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.xs)
                    .textSelection(.enabled)
            } label: {
                Label("What the scan saw", systemImage: "doc.text.magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
            }
            .tint(Theme.Palette.jade)
        }
    }

    private var saveCard: some View {
        GlassCard(title: "Save to history", symbolName: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                TextField("Product name", text: $productName)
                    .textFieldStyle(.plain)
                    .padding(Theme.Spacing.xs)
                    .background(Theme.Palette.surface.opacity(0.6), in: .rect(cornerRadius: Theme.Radius.sm))

                if let barcode = viewModel.barcode {
                    Label("Barcode \(barcode)", systemImage: "barcode.viewfinder")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.jadeText)
                }

                Button {
                    save()
                } label: {
                    Label(hasSaved ? "Saved" : "Save scan",
                          systemImage: hasSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xxs)
                }
                .buttonStyle(.glassProminent)
                .tint(hasSaved ? Color("VerdictSafe") : Theme.Palette.jade)
                .disabled(hasSaved)
            }
        }
    }

    private var disclaimerFooter: some View {
        Text("Nirogi assists with label reading and is not medical advice. Always check the packet yourself.")
            .font(.caption2)
            .foregroundStyle(Theme.Palette.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Actions

    private func save() {
        viewModel.save(to: context, productName: productName)
        withAnimation(Theme.Motion.standard) { hasSaved = true }
    }
}

// MARK: - Saved result

/// Read-only view of a scan already in history.
///
/// Opening a saved scan re-runs the engine against the *current* profile,
/// so a product saved before the user added an allergy is re-judged with
/// that allergy in mind rather than showing a stale verdict.
struct SavedResultView: View {

    let record: ScanRecord
    let profile: UserProfile

    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var liveResult: AnalysisResult?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                let result = liveResult ?? storedResult

                VerdictCard(verdict: result.verdict, findingCount: result.findings.count)

                if result.verdict != record.verdict {
                    GlassCard(title: "Profile changed", symbolName: "arrow.triangle.2.circlepath",
                              tint: Theme.Palette.turmeric) {
                        Text("When you saved this scan the verdict was \(record.verdict.title). Your profile has changed since, so it is now \(result.verdict.title).")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let data = record.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(.rect(cornerRadius: Theme.Radius.md))
                        .accessibilityLabel("Photo of the scanned label")
                }

                if !result.findings.isEmpty {
                    GlassCard(title: "Why", symbolName: "list.bullet.rectangle") {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(result.findings) { finding in
                                FindingRow(finding: finding)
                                if finding.id != result.findings.last?.id {
                                    Divider().overlay(Theme.Palette.hairline)
                                }
                            }
                        }
                    }
                }

                GlassCard(title: "Ingredients read", symbolName: "list.bullet") {
                    Text(record.ingredients.joined(separator: " · "))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .nirogiBackground()
        .navigationTitle(record.productName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let parsed = LabelParser.parse(record.rawText)
            liveResult = appEnvironment.engine.analyse(label: parsed, profile: profile.snapshot)
        }
    }

    /// The verdict exactly as it was stored, used until the live re-check
    /// finishes.
    private var storedResult: AnalysisResult {
        AnalysisResult(verdict: record.verdict,
                       findings: record.findings,
                       ingredients: record.ingredients,
                       nutrition: record.nutrition)
    }
}
