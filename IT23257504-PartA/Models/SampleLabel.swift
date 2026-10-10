//
//  SampleLabel.swift
//  Nirogi (IT23257504-PartA)
//
//  Bundled label images used for demonstration and testing.
//
//  These exist for two reasons. First, the iOS Simulator has no camera, so
//  without them the app could not be demonstrated without a physical
//  device. Second, they give the scanning pipeline a fixed, repeatable
//  input — the same image always produces the same OCR text, which makes
//  the app's behaviour reproducible when testing.
//
//  Importantly these are still *real scans*: the image goes through Vision
//  exactly like a photograph taken with the camera. Nothing is faked.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import Foundation
import UIKit

/// A bundled label image the user can scan without a camera.
struct SampleLabel: Identifiable, Hashable, Sendable {
    let id: String
    /// Product name shown in the picker.
    let title: String
    /// Asset catalogue image name.
    let imageName: String
    /// What this sample is useful for demonstrating.
    let note: String

    /// Loads the image from the asset catalogue.
    var image: UIImage? { UIImage(named: imageName) }

    /// Every sample shipped with the app, chosen so that between them they
    /// exercise each verdict and each interesting matching behaviour.
    static let all: [SampleLabel] = [
        SampleLabel(
            id: "biscuit",
            title: "Cream Biscuits",
            imageName: "sample_biscuit",
            note: "Hidden dairy (whey powder) and a peanut trace warning."
        ),
        SampleLabel(
            id: "chocolate",
            title: "Cashew Chocolate Bar",
            imageName: "sample_chocolate",
            note: "Cashew and milk solids, plus very high sugar."
        ),
        SampleLabel(
            id: "chilli",
            title: "Chilli Sambol Paste",
            imageName: "sample_chilli",
            note: "Umbalakada (Maldive fish), which foreign apps miss."
        ),
        SampleLabel(
            id: "coconut",
            title: "Coconut Milk Powder",
            imageName: "sample_coconut",
            note: "Tests that \u{201C}coconut milk\u{201D} is not read as dairy."
        ),
        SampleLabel(
            id: "rice",
            title: "Plain Rice Crackers",
            imageName: "sample_rice",
            note: "A clean label, for a Safe verdict."
        )
    ]
}
