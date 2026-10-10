//
//  ScanMapView.swift
//  Nirogi (IT23257504-PartA)
//
//  Shows where safe products were found, using MapKit.
//
//  The practical value: having established that a particular brand of
//  biscuit is safe, it is useful to remember which shop sells it.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import SwiftUI
import SwiftData
import MapKit

struct ScanMapView: View {

    @Environment(\.modelContext) private var context

    /// Only scans that have a saved location can appear on the map.
    @Query(sort: \ScanRecord.createdAt, order: .reverse)
    private var records: [ScanRecord]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedRecord: ScanRecord?
    @State private var locationProvider = LocationProvider()

    /// Scans with coordinates attached.
    private var mapped: [ScanRecord] {
        records.filter(\.hasLocation)
    }

    var body: some View {
        Group {
            if mapped.isEmpty {
                emptyState
            } else {
                mapContent
            }
        }
        .navigationTitle("Places")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    attachCurrentLocationToLatestScan()
                } label: {
                    Label("Tag latest scan here", systemImage: "mappin.and.ellipse")
                }
                .disabled(records.isEmpty)
            }
        }
    }

    // MARK: - Content

    private var mapContent: some View {
        Map(position: $position, selection: $selectedRecord) {
            ForEach(mapped) { record in
                Marker(record.productName, systemImage: record.verdict.symbolName,
                       coordinate: coordinate(for: record))
                    .tint(record.verdict.fillColor)
                    .tag(record)
            }

            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedRecord {
                selectionCard(selectedRecord)
                    .padding(Theme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.standard, value: selectedRecord)
    }

    private func selectionCard(_ record: ScanRecord) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.productName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ink)

                if let place = record.placeName {
                    Text(place)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                Text(record.summary)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VerdictBadge(verdict: record.verdict)
        }
        .nirogiCard(ensureLegibility: true)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                EmptyState(
                    symbolName: "map",
                    title: "No places saved yet",
                    message: records.isEmpty
                        ? "Scan a product first, then come back here to pin where you found it."
                        : "Tap the pin button above while you are at the shop to tag your most recent scan with this location.")
            }
            .padding(Theme.Spacing.md)
        }
        .nirogiBackground()
    }

    // MARK: - Actions

    private func coordinate(for record: ScanRecord) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: record.latitude ?? 0,
                               longitude: record.longitude ?? 0)
    }

    /// Attaches the device's current position to the newest scan.
    ///
    /// Location is requested only at this moment, rather than tracked
    /// continuously, which is both better for battery and the minimum
    /// amount of data needed for the feature.
    private func attachCurrentLocationToLatestScan() {
        guard let latest = records.first else { return }

        locationProvider.requestLocation { coordinate in
            guard let coordinate else { return }
            latest.latitude = coordinate.latitude
            latest.longitude = coordinate.longitude
            latest.placeName = "Tagged location"
            try? context.save()

            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        }
    }
}

// MARK: - Location

/// Thin wrapper over CoreLocation for one-shot position requests.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Asks for permission if needed, then returns a single fix.
    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            // Denied or restricted: report failure rather than hanging.
            completion(nil)
            self.completion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            completion?(nil)
            completion = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.last?.coordinate)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}
