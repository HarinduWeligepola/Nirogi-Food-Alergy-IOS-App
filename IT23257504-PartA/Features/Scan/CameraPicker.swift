//
//  CameraPicker.swift
//  Nirogi (IT23257504-PartA)
//
//  Bridges UIKit's camera into SwiftUI.
//
//  SwiftUI has no native camera capture view, so `UIImagePickerController`
//  is wrapped here. It is kept deliberately small: capture an image, hand
//  it back, and let the view model do everything else.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import UIKit

/// Presents the system camera and returns the captured photo.
struct CameraPicker: UIViewControllerRepresentable {

    /// Called with the captured image.
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Whether this device has a camera at all.
    ///
    /// This is false in the Simulator, which is why the Scan screen hides
    /// the camera button there rather than offering a control that cannot
    /// work.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.allowsEditing = true   // lets the user crop to the panel
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Nothing to update: the controller is configured once at creation.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onFinish: { dismiss() })
    }

    /// Receives delegate callbacks from `UIImagePickerController`.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let onCapture: (UIImage) -> Void
        private let onFinish: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onFinish: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer the cropped image when the user adjusted the frame.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            onFinish()
            if let image {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish()
        }
    }
}
