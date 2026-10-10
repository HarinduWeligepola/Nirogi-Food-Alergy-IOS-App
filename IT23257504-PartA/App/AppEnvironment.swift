//
//  AppEnvironment.swift
//  Nirogi (IT23257504-PartA)
//
//  Composition root. The knowledge base, safety engine and OCR service are
//  created once here and injected into the view tree.
//
//  Constructing them in one place rather than inside individual views keeps
//  the expensive work (parsing a 300-term JSON database) off the rendering
//  path, and lets tests substitute a smaller knowledge base.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import SwiftUI
import SwiftData

/// Shared services for the whole app.
@Observable
final class AppEnvironment {

    /// Allergen definitions, loaded once at launch.
    let knowledgeBase: AllergenKnowledgeBase
    /// Matching engine built on that knowledge base.
    let engine: SafetyEngine
    /// Vision-backed text and barcode reader.
    let ocr: OCRService

    init(knowledgeBase: AllergenKnowledgeBase? = nil) {
        let base = knowledgeBase ?? AllergenKnowledgeBase.loadOrEmpty()
        self.knowledgeBase = base
        self.engine = SafetyEngine(knowledgeBase: base)
        self.ocr = OCRService()
    }

    /// Convenience used by previews and tests.
    static var preview: AppEnvironment { AppEnvironment() }
}

// MARK: - SwiftData container

/// Builds the app's SwiftData container.
enum PersistenceController {

    /// Models stored by the app.
    static let schema = Schema([UserProfile.self, ScanRecord.self])

    /// The on-disk container used by the running app.
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A container that cannot open is unrecoverable, but destroying
            // the user's data silently would be worse. Fall back to an
            // in-memory store so the app still runs and can report the
            // problem, rather than crashing on launch.
            assertionFailure("Persistent container failed to open: \(error)")
            return makeInMemoryContainer()
        }
    }

    /// An ephemeral container, used for previews, tests, and as a last
    /// resort if the on-disk store cannot be opened.
    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Force-unwrapping is acceptable here: an in-memory store has no
        // external dependencies and cannot fail for environmental reasons.
        return try! ModelContainer(for: schema, configurations: [configuration])
    }
}

// MARK: - Profile access

/// Helpers for working with the app's single `UserProfile`.
enum ProfileStore {

    /// Fetches the existing profile, creating one on first launch.
    ///
    /// Nirogi is deliberately single-profile, so this always returns the
    /// same record rather than a list.
    @MainActor
    static func loadOrCreate(in context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }
}
