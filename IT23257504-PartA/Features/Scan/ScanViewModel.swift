//
//  ScanViewModel.swift
//  Nirogi (IT23257504-PartA)
//
//  Drives one scan from image to verdict, following MVVM: the view owns no
//  logic, and this type owns no view code.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import SwiftUI
import SwiftData

/// Where an image came from. Kept explicit because the camera is
/// unavailable in the simulator, so the UI must adapt at runtime.
enum ImageSource: String, Identifiable, CaseIterable {
    case camera
    case photoLibrary
    case sample

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: return String(localized: "Take Photo")
        case .photoLibrary: return String(localized: "Choose Photo")
        case .sample: return String(localized: "Try a Sample")
        }
    }

    var symbolName: String {
        switch self {
        case .camera: return "camera.fill"
        case .photoLibrary: return "photo.on.rectangle"
        case .sample: return "doc.text.magnifyingglass"
        }
    }
}

/// Manages the scanning workflow and exposes its state to the view.
@MainActor
@Observable
final class ScanViewModel {

    /// The stages a scan passes through.
    enum Phase: Equatable {
        case idle
        case reading
        case analysing
        case finished
        case failed(String)

        /// Message shown beside the progress indicator, so the user knows
        /// the app is working rather than stuck.
        var progressMessage: String? {
            switch self {
            case .reading: return "Reading the label…"
            case .analysing: return "Checking against your profile…"
            default: return nil
            }
        }

        var isBusy: Bool {
            self == .reading || self == .analysing
        }
    }

    // MARK: Observable state

    private(set) var phase: Phase = .idle
    /// The image currently being scanned.
    var image: UIImage?
    /// The analysis produced by the engine, once finished.
    private(set) var result: AnalysisResult?
    /// Raw OCR text, shown in the "what the scan saw" section.
    private(set) var rawText: String = ""
    /// Barcode found alongside the text, if any.
    private(set) var barcode: String?
    /// Set when Vision reported low confidence, prompting a retake.
    private(set) var qualityWarning: String?

    // MARK: Dependencies

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // MARK: - Workflow

    /// Runs a full scan: Vision reads the image, the parser structures the
    /// text, and the engine produces a verdict for this user.
    ///
    /// - Parameters:
    ///   - image: the label photograph.
    ///   - profile: immutable snapshot of the user's rules.
    func scan(image: UIImage, profile: ProfileSnapshot) async {
        self.image = image
        self.qualityWarning = nil
        self.result = nil
        phase = .reading

        do {
            let output = try await environment.ocr.scan(image: image)
            rawText = output.text
            barcode = output.barcode

            if output.isLowQuality {
                qualityWarning = "This photo was hard to read, so some ingredients may have been missed. Consider retaking it in better light."
            }

            phase = .analysing

            // Parsing and matching are pure CPU work on value types, so they
            // run off the main actor to keep the interface responsive.
            let engine = environment.engine
            let analysis = await Task.detached(priority: .userInitiated) {
                let parsed = LabelParser.parse(output.text)
                return engine.analyse(label: parsed, profile: profile)
            }.value

            guard !analysis.ingredients.isEmpty || !analysis.nutrition.isEmpty else {
                phase = .failed("No ingredient list was found on this label. Make sure the ingredients panel is fully inside the frame.")
                return
            }

            result = analysis
            phase = .finished

        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Clears everything, ready for another scan.
    func reset() {
        phase = .idle
        image = nil
        result = nil
        rawText = ""
        barcode = nil
        qualityWarning = nil
    }

    // MARK: - Saving

    /// Persists the finished scan to the user's history.
    ///
    /// - Returns: the saved record, or `nil` if there was nothing to save.
    @discardableResult
    func save(to context: ModelContext, productName: String) -> ScanRecord? {
        guard let result else { return nil }

        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = ScanRecord(
            productName: trimmedName.isEmpty ? ScanRecord.defaultName() : trimmedName,
            rawText: rawText,
            ingredients: result.ingredients,
            verdict: result.verdict,
            findings: result.findings,
            nutrition: result.nutrition,
            // Compressed rather than stored raw: a full-resolution capture is
            // several megabytes, and history would grow unmanageably.
            imageData: image?.jpegData(compressionQuality: 0.6),
            barcode: barcode
        )

        context.insert(record)
        try? context.save()
        return record
    }

    /// Re-runs the engine against a changed profile without re-reading the
    /// image.
    ///
    /// This powers the demonstration that the verdict is personal: edit the
    /// profile, come back, and the same label is judged differently —
    /// without paying for OCR a second time.
    func reanalyse(profile: ProfileSnapshot) {
        guard !rawText.isEmpty else { return }
        let parsed = LabelParser.parse(rawText)
        result = environment.engine.analyse(label: parsed, profile: profile)
    }
}
