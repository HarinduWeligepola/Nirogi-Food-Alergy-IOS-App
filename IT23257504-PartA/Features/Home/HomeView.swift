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

    /// Lets the main call to action send the user to the Scan tab.
    @Binding var selectedTab: AppTab

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
                GreetingHeader(profile: profile, onAddName: { selectedTab = .profile })

                scanCallToAction

                if !records.isEmpty {
                    StatsRow(records: records)
                }

                profileSummary

                if records.isEmpty {
                    EmptyState(
                        symbolName: "text.viewfinder",
                        title: "No scans yet",
                        message: "Tap Scan a new label above and photograph an ingredient list to get started.")
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
        // Inline, so the greeting is the visual hero of the screen rather
        // than competing with a large navigation title.
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Call to action

    /// The screen's primary action.
    ///
    /// Scanning is what the app is *for*, so the home screen leads with it
    /// rather than making the user find the Scan tab first.
    private var scanCallToAction: some View {
        Button {
            selectedTab = .scan
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 30, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a new label")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Check a product in seconds")
                        .font(Theme.Typography.caption)
                        .opacity(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .opacity(0.7)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.Palette.jade)
        .accessibilityHint("Opens the scanner")
    }

    // MARK: - Profile summary

    private var profileSummary: some View {
        GlassCard(title: profile.isEmpty ? "Set up your profile" : "Checked against",
                  symbolName: profile.isEmpty ? "exclamationmark.circle.fill" : "person.text.rectangle",
                  tint: profile.isEmpty ? Theme.Palette.turmeric : nil) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if profile.isEmpty {
                    Text("You have not added any allergens yet, so every label will come back Safe.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        selectedTab = .profile
                    } label: {
                        Label("Add allergens", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Palette.turmeric)
                } else {
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

// MARK: - Greeting header

/// Time-aware welcome at the top of the home screen.
///
/// The greeting changes through the day and the user's name is the largest
/// text on screen, which makes the app feel like it belongs to them rather
/// than being a generic utility.
struct GreetingHeader: View {

    let profile: UserProfile
    /// Called when a user without a saved name taps to add one.
    let onAddName: () -> Void

    /// Captured once per appearance rather than read repeatedly, so the
    /// greeting cannot change mid-render.
    @State private var now = Date()

    private var name: String {
        profile.displayName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: timeOfDay.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(timeOfDay.tint)
                    .symbolRenderingMode(.hierarchical)

                Text(timeOfDay.greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Palette.inkMuted)
            }

            if name.isEmpty {
                Button(action: onAddName) {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text("Add your name")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Palette.jade)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityHint("Opens your profile so you can add your name")
            } else {
                Text(name)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xxs)
        .padding(.top, Theme.Spacing.xs)
        .onAppear { now = Date() }
        .accessibilityElement(children: .contain)
    }

    private var timeOfDay: TimeOfDay {
        TimeOfDay(hour: Calendar.current.component(.hour, from: now))
    }
}

/// The four parts of the day the greeting recognises.
enum TimeOfDay {
    case morning, afternoon, evening, night

    init(hour: Int) {
        switch hour {
        case 5..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }

    var greeting: LocalizedStringKey {
        switch self {
        case .morning: return "Good morning"
        case .afternoon: return "Good afternoon"
        case .evening: return "Good evening"
        case .night: return "Good night"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning, .afternoon, .evening: return Theme.Palette.turmeric
        case .night: return Theme.Palette.jade
        }
    }
}

// MARK: - Stats

/// A short summary of what the user has scanned so far.
struct StatsRow: View {

    let records: [ScanRecord]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var safeCount: Int { records.count { $0.verdict == .safe } }
    private var avoidCount: Int { records.count { $0.verdict == .avoid } }

    var body: some View {
        let tiles = [
            StatTile(value: records.count, label: "Scanned",
                     symbolName: "doc.text.viewfinder", tint: Theme.Palette.jade),
            StatTile(value: safeCount, label: "Safe",
                     symbolName: "checkmark.seal.fill", tint: Color("VerdictSafe")),
            StatTile(value: avoidCount, label: "Avoided",
                     symbolName: "xmark.octagon.fill", tint: Color("VerdictAvoid"))
        ]

        // Three tiles side by side are too cramped at accessibility sizes,
        // so they stack instead.
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Spacing.xs) { ForEach(tiles) { $0 } }
            } else {
                HStack(spacing: Theme.Spacing.xs) { ForEach(tiles) { $0 } }
            }
        }
    }
}

/// One figure in the stats row.
struct StatTile: View, Identifiable {

    let value: Int
    let label: LocalizedStringKey
    let symbolName: String
    let tint: Color

    var id: String { symbolName }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: symbolName)
                .font(.subheadline)
                .foregroundStyle(tint)

            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.Palette.ink)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .nirogiCard(cornerRadius: Theme.Radius.md, padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - History row

/// One saved scan in the history list.
struct HistoryRow: View {
    let record: ScanRecord

    /// At accessibility text sizes the row stacks vertically instead of
    /// squeezing the title and the badge onto one line, where the title
    /// would break mid-word.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.sm) {
                        thumbnail
                        VerdictBadge(verdict: record.verdict)
                        Spacer(minLength: 0)
                    }
                    details
                }
            } else {
                HStack(spacing: Theme.Spacing.sm) {
                    thumbnail
                    details
                    Spacer(minLength: 0)
                    VerdictBadge(verdict: record.verdict)
                }
            }
        }
        .nirogiCard(cornerRadius: Theme.Radius.md, padding: Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.productName). \(record.verdict.title). \(record.summary)")
    }

    private var details: some View {
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
