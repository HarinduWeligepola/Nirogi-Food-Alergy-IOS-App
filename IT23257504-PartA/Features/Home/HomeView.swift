//
//  HomeView.swift
//  Nirogi (IT23257504-PartA)
//
//  The history screen: previously scanned products, newest first, with a
//  summary of the profile they were judged against.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    let profile: UserProfile

    @Environment(\.modelContext) private var context

    /// History, newest first. SwiftData keeps this in sync automatically, so
    /// a scan saved on another tab appears here without any manual refresh.
    @Query(sort: \ScanRecord.createdAt, order: .reverse)
    private var records: [ScanRecord]

    @State private var searchText = ""
    /// Record awaiting delete confirmation.
    @State private var pendingDeletion: ScanRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                profileSummary

                if records.isEmpty {
                    EmptyState(
                        symbolName: "text.viewfinder",
                        title: "No scans yet",
                        message: "Open the Scan tab and photograph an ingredient label to get started.")
                } else {
                    SectionHeading(text: "Recent scans", symbolName: "clock.arrow.circlepath")

                    ForEach(filteredRecords) { record in
                        NavigationLink {
                            SavedResultView(record: record, profile: profile)
                        } label: {
                            HistoryRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDeletion = record
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if filteredRecords.isEmpty {
                        EmptyState(
                            symbolName: "magnifyingglass",
                            title: "No matches",
                            message: "No saved scan matches \u{201C}\(searchText)\u{201D}.")
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .nirogiBackground()
        .navigationTitle("Nirogi")
        .searchable(text: $searchText, prompt: "Search saved scans")
        // Deletion is irreversible, so it is always confirmed explicitly.
        .confirmationDialog("Delete this scan?",
                            isPresented: .constant(pendingDeletion != nil),
                            titleVisibility: .visible,
                            presenting: pendingDeletion) { record in
            Button("Delete", role: .destructive) { delete(record) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { record in
            Text("\(record.productName) will be removed from your history.")
        }
    }

    // MARK: - Profile summary

    private var profileSummary: some View {
        GlassCard(title: greeting, symbolName: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if profile.isEmpty {
                    Text("You have not set up any allergens yet, so every label will come back Safe. Add them in the Profile tab.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Labels are checked against:")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)

                    // Wraps naturally at larger Dynamic Type sizes rather
                    // than truncating.
                    FlowLayout(spacing: Theme.Spacing.xs) {
                        ForEach(profile.rules) { rule in
                            RuleChip(rule: rule)
                        }
                        ForEach(profile.dietaryPreferences) { preference in
                            PreferenceChip(preference: preference)
                        }
                        ForEach(profile.healthLimits) { limit in
                            LimitChip(limit: limit)
                        }
                    }
                }
            }
        }
    }

    private var greeting: String {
        let name = profile.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Your profile" : "Hello, \(name)"
    }

    // MARK: - Data

    /// History filtered by the search field, matching product names,
    /// ingredients and flagged allergens.
    private var filteredRecords: [ScanRecord] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return records }

        return records.filter { record in
            if record.productName.lowercased().contains(query) { return true }
            if record.ingredients.contains(where: { $0.contains(query) }) { return true }
            return record.findings.contains { $0.categoryName.lowercased().contains(query) }
        }
    }

    private func delete(_ record: ScanRecord) {
        withAnimation(Theme.Motion.standard) {
            context.delete(record)
            try? context.save()
        }
        pendingDeletion = nil
    }
}

// MARK: - History row

/// One saved scan in the history list.
struct HistoryRow: View {
    let record: ScanRecord

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(record.productName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)

                Text(record.summary)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineLimit(1)

                Text(record.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }

            Spacer(minLength: 0)

            VerdictBadge(verdict: record.verdict)
        }
        .nirogiCard(cornerRadius: Theme.Radius.md, padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.productName). \(record.verdict.title). \(record.summary)")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = record.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(Theme.Palette.jade.opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Theme.Palette.jade)
                }
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Chips

struct RuleChip: View {
    let rule: AllergenRule
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        chipLabel(
            text: appEnvironment.knowledgeBase.name(for: rule.categoryID),
            symbol: appEnvironment.knowledgeBase.allergen(id: rule.categoryID)?.symbolName ?? "exclamationmark.triangle",
            tint: rule.severity == .severe ? Color("VerdictAvoid") : Theme.Palette.jade)
    }
}

struct PreferenceChip: View {
    let preference: DietaryPreference

    var body: some View {
        chipLabel(text: preference.title, symbol: preference.symbolName, tint: Theme.Palette.jade)
    }
}

struct LimitChip: View {
    let limit: HealthLimit

    var body: some View {
        chipLabel(text: "\(limit.nutrient.title) ≤ \(limit.displayLimit)",
                  symbol: limit.nutrient.symbolName,
                  tint: Theme.Palette.turmeric)
    }
}

/// Shared chip styling used by the three chip types above.
@ViewBuilder
func chipLabel(text: String, symbol: String, tint: Color) -> some View {
    HStack(spacing: 4) {
        Image(systemName: symbol)
            .font(.caption2)
        Text(text)
            .font(.caption.weight(.medium))
    }
    .foregroundStyle(Theme.Palette.ink)
    .padding(.horizontal, Theme.Spacing.xs)
    .padding(.vertical, 5)
    .background(tint.opacity(0.16), in: .capsule)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
}

// MARK: - Flow layout

/// A simple wrapping layout for chips.
///
/// Written as a custom `Layout` rather than nested stacks so that chips
/// reflow correctly when the user increases Dynamic Type — a fixed-column
/// grid would clip long allergen names at accessibility text sizes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight

        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
