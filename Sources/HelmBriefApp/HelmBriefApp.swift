//
//  HelmBriefApp.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import SwiftUI
import MarineKit
import RoutingKit
import BriefingKit
import MapKit

@main
struct HelmBriefApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// The top‑level content view hosting the map, input controls, and navigation to the briefing.
struct ContentView: View {
    // A simple default route between Vancouver and Nanaimo to illustrate the UI.  Users can replace
    // these points with their own once full map editing is implemented.
    @State private var route = Route(points: [
        Coordinate(latitude: 49.283, longitude: -123.120), // Vancouver Harbour
        Coordinate(latitude: 49.184, longitude: -123.950)  // Nanaimo Harbour
    ])
    @State private var etd: Date = Date()
    @State private var stw: Double = 10.0
    @State private var briefing: Briefing? = nil
    @State private var showBriefing: Bool = false

    // Providers and solvers.  The default providers can be switched between mock and real.
    // To fetch real weather, wave and current data from Open‑Meteo, uncomment the line below
    // and comment out the mock providers.  The OpenMeteoMarineProvider performs network
    // requests to fetch forecasts based on location and date.
    // private var marineProvider = OpenMeteoMarineProvider()
    // For demonstration, we'll attempt to use the real provider.  If network
    // connectivity is unavailable, consider falling back to the mocks.
    private var marineProvider = OpenMeteoMarineProvider()
    private var passes: [CriticalPass] = {
        // Seed some Pacific Northwest passes.  Coordinates are rough polygons for demonstration.
        return [
            CriticalPass(
                name: "Seymour Narrows",
                polygon: [
                    Coordinate(latitude: 50.106, longitude: -125.246),
                    Coordinate(latitude: 50.110, longitude: -125.236),
                    Coordinate(latitude: 50.120, longitude: -125.234),
                    Coordinate(latitude: 50.120, longitude: -125.250)
                ],
                referenceStationID: "Discovery Passage",
                slackOffsetMinutes: 0,
                safeWindowMinutes: 15,
                ebbHeading: 135.0,
                floodHeading: 315.0
            ),
            CriticalPass(
                name: "Yuculta Rapids",
                polygon: [
                    Coordinate(latitude: 50.246, longitude: -125.070),
                    Coordinate(latitude: 50.250, longitude: -125.058),
                    Coordinate(latitude: 50.256, longitude: -125.060),
                    Coordinate(latitude: 50.250, longitude: -125.074)
                ],
                referenceStationID: "Dent Island",
                slackOffsetMinutes: 10,
                safeWindowMinutes: 20,
                ebbHeading: 140.0,
                floodHeading: 320.0
            )
        ]
    }()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // Map preview
                MapViewWrapper(route: $route)
                    .frame(height: 300)
                    .cornerRadius(8)
                // Speed input
                HStack {
                    Text("Cruise speed (kn)")
                    Spacer()
                    TextField("10", value: $stw, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }
                // ETD input
                HStack {
                    Text("Departure")
                    Spacer()
                    DatePicker("", selection: $etd)
                        .labelsHidden()
                }
                // Generate briefing button
                Button(action: {
                    Task {
                        // Combine all marine data into a single provider.  This provider will
                        // fetch real forecasts if `OpenMeteoMarineProvider` is used, or
                        // generate synthetic data if the mocks are configured.
                        let provider = marineProvider
                        let engine = TATEngine(windProvider: provider, currentProvider: provider, waveProvider: provider)
                        let slackSolver = SlackSolver(passes: passes)
                        let generator = BriefingGenerator(engine: engine, slackSolver: slackSolver)
                        self.briefing = await generator.generateBriefing(for: route, etd: etd, stw: stw)
                        self.showBriefing = true
                    }
                }) {
                    Text("Generate Briefing")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                Spacer()
                // Hidden navigation link triggered when briefing is ready.
                NavigationLink(destination: briefingDestination(), isActive: $showBriefing) {
                    EmptyView()
                }
                .hidden()
            }
            .padding()
            .navigationTitle("HelmBrief")
        }
    }

    @ViewBuilder
    private func briefingDestination() -> some View {
        if let briefing = briefing {
            // Use the same provider for wind, current and waves.  This provider may fetch real
            // data from Open‑Meteo or produce mock values depending on configuration.
            BriefingView(briefing: briefing,
                         stw: stw,
                         engine: TATEngine(windProvider: marineProvider, currentProvider: marineProvider, waveProvider: marineProvider),
                         slackSolver: SlackSolver(passes: passes),
                         route: route)
        } else {
            Text("No briefing available.")
        }
    }
}

/// A UIViewRepresentable wrapper around `MKMapView` that draws the route polyline and annotations.
struct MapViewWrapper: UIViewRepresentable {
    @Binding var route: Route

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        updateOverlays(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        updateOverlays(mapView)
    }

    private func updateOverlays(_ mapView: MKMapView) {
        // Remove existing overlays and annotations.
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        // Draw the polyline if two or more points exist.
        if route.points.count >= 2 {
            let coords = route.points.map { $0.clLocationCoordinate }
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            mapView.addOverlay(polyline)
        }
        // Add start and destination pins.
        if let first = route.points.first {
            let ann = MKPointAnnotation()
            ann.coordinate = first.clLocationCoordinate
            ann.title = "Departure"
            mapView.addAnnotation(ann)
        }
        if let last = route.points.last, route.points.count > 1 {
            let ann = MKPointAnnotation()
            ann.coordinate = last.clLocationCoordinate
            ann.title = "Destination"
            mapView.addAnnotation(ann)
        }
        // Set initial region if not yet set.
        if mapView.region.span.latitudeDelta == 0 {
            if let first = route.points.first {
                let region = MKCoordinateRegion(center: first.clLocationCoordinate, latitudinalMeters: 150_000, longitudinalMeters: 150_000)
                mapView.setRegion(region, animated: false)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        init(_ parent: MapViewWrapper) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}