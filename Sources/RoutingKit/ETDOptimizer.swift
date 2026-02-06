//
//  ETDOptimizer.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit

/// Represents a recommended departure time window with an associated objective score and
/// human‑readable justification.
public struct ETDRecommendation: Identifiable {
    public let id: UUID = UUID()
    public let etd: Date
    public let objective: Double
    public let description: String
}

/// An optimizer that sweeps candidate ETDs over a window around the user’s chosen ETD and
/// evaluates a simple objective function: minimise average steep sea risk.  This implementation
/// deliberately keeps the algorithm straightforward and synchronous for demonstration; it can be
/// extended to include fuel consumption, tidal current adverse time and other factors.
public struct ETDOptimizer {
    public let engine: TATEngine
    public let slackSolver: SlackSolver
    public let route: Route
    public let stw: Double

    public init(engine: TATEngine, slackSolver: SlackSolver, route: Route, stw: Double) {
        self.engine = engine
        self.slackSolver = slackSolver
        self.route = route
        self.stw = stw
    }

    /// Generates up to three recommended ETDs within ±`windowHours` around the provided initial ETD.
    /// The step size controls the granularity (in minutes) of the search.
    public func optimize(around initialETD: Date,
                         windowHours: Double = 12.0,
                         stepMinutes: Double = 15.0) async -> [ETDRecommendation] {
        let halfRange = TimeInterval(windowHours * 3600.0)
        let step = TimeInterval(stepMinutes * 60.0)
        var candidates: [ETDRecommendation] = []
        var candidateTime = initialETD - halfRange
        let endTime = initialETD + halfRange
        while candidateTime <= endTime {
            // Compute TAT with coarser sampling to improve performance.
            let samples = await engine.computeTAT(for: route, etd: candidateTime, stw: stw, deltaNM: 2.0)
            guard !samples.isEmpty else {
                candidateTime = candidateTime.addingTimeInterval(step)
                continue
            }
            // Compute average risk score.
            var totalRisk: Double = 0
            for sample in samples {
                switch sample.risk {
                case .low: totalRisk += 1
                case .moderate: totalRisk += 2
                case .high: totalRisk += 4
                }
            }
            let avgRisk = totalRisk / Double(samples.count)
            // Evaluate slack cautions; penalise by adding the absolute time shift in hours.
            let cautions = slackSolver.evaluate(route: route, samples: samples)
            var slackPenalty: Double = 0
            for caution in cautions {
                slackPenalty += abs(caution.etdAdjustment) / 3600.0
            }
            let objective = avgRisk + slackPenalty
            // Build a description summarising why this ETD is beneficial.
            let desc = String(format: "Avg risk %.2f, slack penalty %.1f h", avgRisk, slackPenalty)
            let rec = ETDRecommendation(etd: candidateTime, objective: objective, description: desc)
            candidates.append(rec)
            candidateTime = candidateTime.addingTimeInterval(step)
        }
        // Select the three best candidates by objective.
        let sorted = candidates.sorted { $0.objective < $1.objective }
        return Array(sorted.prefix(3))
    }
}