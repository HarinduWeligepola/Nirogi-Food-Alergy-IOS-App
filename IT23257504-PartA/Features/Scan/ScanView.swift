//
//  ScanView.swift
//  Nirogi (IT23257504-PartA)
//
//  The scanning screen: choose an image source, watch Vision read it, then
//  move to the result.
//
//  The camera button is shown only when a camera actually exists, so the
//  same build runs correctly on a device and in the Simulator.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ScanView: View {

    let profile: UserProfile

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var context

    @State private var viewModel: ScanViewModel?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showSamples = false
    @State private var showResult = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let viewModel, viewModel.phase.isBusy {
                    progressCard(viewModel)
                } else if let viewModel, case .failed(let message) = viewModel.phase {
                    failureCard(message, viewModel: viewModel)
                } else {
                    introCard
                    sourceButtons
                    tipsCard
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)
            .animation(Theme.Motion.standard, value: viewModel?.phase)
        }
        .nirogiBackground()
        .navigationTitle("Scan a Label")
        .task {
            // Created once the environment is available, then reused.
            if viewModel == nil {
                viewModel = ScanViewModel(environment: appEnvironment)
            }
        }
        .photosPicker(isPresented: .constant(false), selection: $photoItem)
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await run(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSamples) {
            SampleLabelPicker { sample in
                guard let image = sample.image else { return }
                Task { await run(image) }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPickedPhoto(newItem) }
        }
        .navigationDestination(isPresented: $showResult) {
            if let viewModel, viewModel.result != nil {
                ResultView(viewModel: viewModel, profile: profile)
            }
        }
    }

    // MARK: - Cards

    private var introCard: some View {
        GlassCard {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.Palette.jade)
                    .accessibilityHidden(true)

                Text("Point at the ingredients")
                    .font(Theme.Typography.heading)
                    .foregroundStyle(Theme.Palette.ink)

                Text("Nirogi reads the ingredient list on your device and checks every word against your profile.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private var sourceButtons: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // Only offered when the hardware exists — false in the Simulator.
            if CameraPicker.isAvailable {
                sourceButton(.camera, prominent: true) { showCamera = true }
            }

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                sourceButtonLabel(.photoLibrary)
            }
            .buttonStyle(.glass)

            sourceButton(.sample, prominent: false) { showSamples = true }
        }
    }

    private func sourceButton(_ source: ImageSource, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sourceButtonLabel(source)
        }
        .buttonStyle(prominent ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
        .tint(Theme.Palette.jade)
    }

    private func sourceButtonLabel(_ source: ImageSource) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: source.symbolName)
                .font(.title3)
            Text(source.title)
                .font(.body.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.Palette.inkMuted)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: .infinity)
    }

    private var tipsCard: some View {
        GlassCard(title: "For the best reading", symbolName: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                tip("Fill the frame with the ingredients panel.")
                tip("Flatten curved packets as much as you can.")
                tip("Avoid glare and harsh shadows.")
                tip("Nirogi reads the English text on trilingual labels.")
            }
        }
    }

    private func tip(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.Palette.jade)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func progressCard(_ viewModel: ScanViewModel) -> some View {
        GlassCard {
            VStack(spacing: Theme.Spacing.md) {
                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(.rect(cornerRadius: Theme.Radius.md))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Palette.jade.opacity(0.5), lineWidth: 2)
                        }
                        .accessibilityHidden(true)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text(viewModel.phase.progressMessage ?? "Working…")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func failureCard(_ message: String, viewModel: ScanViewModel) -> some View {
        GlassCard(title: "Could not read that", symbolName: "exclamationmark.triangle.fill",
                  tint: Color("VerdictCaution")) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Try again") {
                    withAnimation(Theme.Motion.standard) { viewModel.reset() }
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Palette.jade)
            }
        }
    }

    // MARK: - Actions

    /// Runs a scan and navigates to the result when it succeeds.
    private func run(_ image: UIImage) async {
        guard let viewModel else { return }
        await viewModel.scan(image: image, profile: profile.snapshot)
        if viewModel.phase == .finished {
            showResult = true
        }
    }

    /// Loads the image chosen from the photo library and scans it.
    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await run(image)
    }
}

// MARK: - Button style erasure

/// Allows choosing between two button styles at runtime.
///
/// SwiftUI's `buttonStyle` takes a concrete generic type, so the prominent
/// and plain glass styles cannot be selected with a plain ternary without
/// erasing them first.
struct AnyButtonStyle: PrimitiveButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(Button(configuration).buttonStyle(style))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}

// MARK: - Sample picker

/// Lets the user scan one of the bundled label images.
struct SampleLabelPicker: View {
    let onSelect: (SampleLabel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("These are real scans: each image is read by Vision exactly like a photo from the camera.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Theme.Spacing.xxs)

                    ForEach(SampleLabel.all) { sample in
                        Button {
                            dismiss()
                            onSelect(sample)
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                if let image = sample.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.Palette.ink)
                                    Text(sample.note)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Palette.inkMuted)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .nirogiCard(cornerRadius: Theme.Radius.md, padding: Theme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .nirogiBackground()
            .navigationTitle("Sample Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
