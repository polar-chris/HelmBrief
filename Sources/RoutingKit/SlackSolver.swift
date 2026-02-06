//
//  SlackSolver.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit

/// The SlackSolver is responsible for determining whether a route intersects any critical passes
/// (tidal gates) and, if so, computing whether the predicted arrival times fall within the safe
/// window around slack.  The solver uses simplified heuristics in this implementation: it checks
/// for intersections using bounding boxes and uses a rudimentary slack schedule (midday) since
/// real‑world slack times require harmonic constituents not available in this mock implementation.
public struct SlackSolver {
    public let passes: [CriticalPass]

    public init(passes: [CriticalPass]) {
        self.passes = passes
    }

    /// Evaluates the route for interactions with critical passes and produces an array of cautions
    /// if the arrival time at a pass lies outside the safe slack window.  The supplied samples must
    /// correspond to the TAT results for the same route; they are used to extract arrival times.
    public func evaluate(route: Route, samples: [VertexSample]) -> [PassCaution] {
        var cautions: [PassCaution] = []
        guard !passes.isEmpty else { return cautions }
        // Precompute bounding boxes for speed.
        for pass in passes {
            // Build simple bounding box from pass polygon.
            guard let minLat = pass.polygon.map({ $0.latitude }).min(),
                  let maxLat = pass.polygon.map({ $0.latitude }).max(),
                  let minLon = pass.polygon.map({ $0.longitude }).min(),
                  let maxLon = pass.polygon.map({ $0.longitude }).max() else { continue }
            // Find the earliest sample index that enters the bounding box.
            var arrivalIndex: Int? = nil
            for (idx, sample) in samples.enumerated() {
                let lat = sample.coordinate.latitude
                let lon = sample.coordinate.longitude
                if lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon {
                    arrivalIndex = idx
                    break
                }
            }
            guard let index = arrivalIndex else { continue }
            let arrivalTime = samples[index].time
            // Determine the nearest slack time by rounding to noon of the arrival day plus offset.
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month, .day], from: arrivalTime)
            let noon = calendar.date(from: comps)!.addingTimeInterval(12 * 3600)
            // Apply offset for this pass.
            let slack = noon.addingTimeInterval(TimeInterval(pass.slackOffsetMinutes * 60))
            // Safe window boundaries.
            let halfWindow = TimeInterval(pass.safeWindowMinutes * 60)
            let windowStart = slack.addingTimeInterval(-halfWindow)
            let windowEnd = slack.addingTimeInterval(halfWindow)
            let safeRange: ClosedRange<Date> = windowStart...windowEnd
            // Check if arrival is within window.
            if safeRange.contains(arrivalTime) {
                // No caution necessary.
                continue
            } else {
                // Compute the minimal time shift to bring arrival into the safe window.
                let adjustment: TimeInterval
                if arrivalTime < windowStart {
                    adjustment = windowStart.timeIntervalSince(arrivalTime)
                } else {
                    adjustment = windowEnd.timeIntervalSince(arrivalTime)
                }
                let minutes = Int(adjustment / 60.0)
                let sign = minutes >= 0 ? "+" : "−"
                let absMinutes = abs(minutes)
                let message = "Adjust ETD by \(sign)\(absMinutes) min to meet slack at \(pass.name)"
                let caution = PassCaution(pass: pass, message: message, etdAdjustment: adjustment, safeWindow: safeRange)
                cautions.append(caution)
            }
        }
        return cautions
    }
}