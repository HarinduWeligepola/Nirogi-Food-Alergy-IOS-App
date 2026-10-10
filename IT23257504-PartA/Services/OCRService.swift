//
//  OCRService.swift
//  Nirogi (IT23257504-PartA)
//
//  Wraps Apple's Vision framework — the emerging technology at the centre
//  of this app. Everything Nirogi does begins with reading the text off a
//  photograph of a food label.
//
//  All recognition happens on-device. No image and no ingredient list ever
//  leaves the phone, which matters for an app handling medical information.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import Vision
import UIKit

/// Reads text and barcodes from label photographs using Vision.
struct OCRService: Sendable {

    // MARK: - Errors

    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "That image could not be read. Please try another photo."
            case .noTextFound:
                return "No text was found on this label. Try moving closer, holding steady, and making sure the ingredient list is well lit."
            case .recognitionFailed(let detail):
                return "Scanning failed: \(detail)"
            }
        }
    }

    // MARK: - Result

    /// What a single scan produced.
    struct ScanOutput: Sendable {
        /// All recognised text, joined in reading order.
        let text: String
        /// Average confidence Vision reported, from 0 to 1. Surfaced to the
        /// user so a poor photo can be retaken rather than trusted.
        let averageConfidence: Double
        /// Barcode payload, if one was visible in the same photo.
        let barcode: String?
        /// Number of separate text blocks found, used to detect a photo
        /// that caught only a word or two.
        let blockCount: Int

        /// True when the scan looks too weak to rely on.
        var isLowQuality: Bool {
            averageConfidence < 0.45 || blockCount < 2
        }
    }

    // MARK: - Text recognition

    /// Reads all text from an image.
    ///
    /// - Parameter image: the label photograph.
    /// - Returns: recognised text plus quality information.
    func scan(image: UIImage) async throws -> ScanOutput {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        async let textTask = recogniseText(in: cgImage)
        async let barcodeTask = detectBarcode(in: cgImage)

        let (lines, confidence) = try await textTask
        // A missing barcode is normal, not an error, so failures are ignored.
        let barcode = try? await barcodeTask

        guard !lines.isEmpty else {
            throw OCRError.noTextFound
        }

        return ScanOutput(text: lines.joined(separator: "\n"),
                          averageConfidence: confidence,
                          barcode: barcode,
                          blockCount: lines.count)
    }

    /// Runs Vision's text recogniser over an image.
    private func recogniseText(in cgImage: CGImage) async throws -> (lines: [String], confidence: Double) {
        var request = RecognizeTextRequest()

        // Accurate rather than fast: ingredient lists are small, dense print
        // and a misread word here could mean a missed allergen.
        request.recognitionLevel = .accurate

        // Language correction is deliberately OFF. It is tuned for ordinary
        // prose and would "helpfully" rewrite unfamiliar technical words —
        // turning "casein" into "casein"-adjacent English. Since those exact
        // words are what we match on, raw output is safer.
        request.usesLanguageCorrection = false

        // Latin script only. Vision cannot read Sinhala or Tamil script, so
        // Nirogi reads the English portion of Sri Lanka's trilingual labels.
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]

        do {
            let observations = try await request.perform(on: cgImage)

            var lines: [String] = []
            var confidenceTotal: Double = 0
            var confidenceCount = 0

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                lines.append(candidate.string)
                confidenceTotal += Double(candidate.confidence)
                confidenceCount += 1
            }

            let average = confidenceCount > 0 ? confidenceTotal / Double(confidenceCount) : 0
            return (lines, average)
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }
    }

    // MARK: - Barcode detection

    /// Looks for a product barcode in the same photograph.
    ///
    /// Finding one lets a repeat scan of a product the user has seen before
    /// be recognised instantly, without re-reading the ingredient list.
    private func detectBarcode(in cgImage: CGImage) async throws -> String? {
        var request = DetectBarcodesRequest()
        request.symbologies = [.ean13, .ean8, .upce, .code128, .code39, .qr]

        let observations = try await request.perform(on: cgImage)
        return observations.compactMap(\.payloadString).first
    }
}
