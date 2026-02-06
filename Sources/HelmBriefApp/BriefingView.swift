//
//  BriefingView.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import SwiftUI
import MarineKit
import RoutingKit
import BriefingKit
import MapKit

/// A view that displays the details of a generated passage briefing.  It shows a summary of
/// metrics, cautions, remarks, and ETD optimisation recommendations.  Users can export the
/// briefing as a PDF.
struct BriefingView: View {
    let briefing: Briefing
    let stw: Double
    let engine: TATEngine
    let slackSolver: SlackSolver
    let route: Route
    @State private var recommendations: [ETDRecommendation] = []
    @State private var pdfURL: URL? = nil
    @State private var showShareSheet = false
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Passage Briefing")
                    .font(.largeTitle)
                    .bold()
                summarySection
                cautionsSection
                remarksSection
                recommendationsSection
                if let url = pdfURL {
                    ShareLink(item: url) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await computeRecommendations()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Export PDF") {
                    exportPDF()
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distance: \(String(format: "%.1f", briefing.distanceNM)) NM")
            Text("ETD: \(briefing.etd.formatted(date: .abbreviated, time: .shortened))")
            Text("ETA: \(briefing.eta.formatted(date: .abbreviated, time: .shortened))")
            let hours = briefing.duration / 3600.0
            Text(String(format: "Underway: %.1f h", hours))
            Text("Sunrise: \(briefing.sunrise.formatted(date: .omitted, time: .shortened))")
            Text("Sunset: \(briefing.sunset.formatted(date: .omitted, time: .shortened))")
        }
        .font(.headline)
    }

    private var cautionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if briefing.passCautions.isEmpty {
                Text("No critical pass cautions on this route.")
            } else {
                Text("Passage Cautions")
                    .font(.title2)
                    .bold()
                ForEach(briefing.passCautions) { caution in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(caution.message)
                            .font(.subheadline)
                        let start = caution.safeWindow.lowerBound.formatted(date: .abbreviated, time: .shortened)
                        let end = caution.safeWindow.upperBound.formatted(date: .abbreviated, time: .shortened)
                        Text("Safe: \(start) – \(end)")
                            .font(.footnote)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if briefing.remarks.isEmpty {
                EmptyView()
            } else {
                Text("Remarks")
                    .font(.title2)
                    .bold()
                ForEach(briefing.remarks, id: \.self) { remark in
                    Text(remark)
                        .font(.subheadline)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if recommendations.isEmpty {
                Text("Computing optimal departure windows...")
            } else {
                Text("Recommended Departure Windows")
                    .font(.title2)
                    .bold()
                ForEach(recommendations) { rec in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.etd.formatted(date: .omitted, time: .shortened))
                            .font(.headline)
                        Text(rec.description)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 8)
    }

    /// Computes ETD optimisation recommendations asynchronously and updates state.
    private func computeRecommendations() async {
        let optimizer = ETDOptimizer(engine: engine, slackSolver: slackSolver, route: route, stw: stw)
        let recs = await optimizer.optimize(around: briefing.etd, windowHours: 12.0, stepMinutes: 30.0)
        DispatchQueue.main.async {
            self.recommendations = recs
        }
    }

    /// Generates a PDF report for the briefing and stores it in a temporary file.  When finished
    /// the share link becomes active.
    private func exportPDF() {
        let renderer = BriefingPDFRenderer()
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("Briefing_\(UUID().uuidString).pdf")
        do {
            try renderer.render(briefing: briefing, to: fileURL)
            self.pdfURL = fileURL
        } catch {
            print("Failed to render PDF: \(error)")
        }
    }
}