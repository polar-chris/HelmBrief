//
//  BriefingGenerator.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit
import RoutingKit

/// Generates a briefing for a given route by performing time‑along‑track sampling, evaluating
/// slack gates, and computing sunrise/sunset.  A Briefing encapsulates all relevant details for
/// presentation to the skipper or export as PDF.
public struct BriefingGenerator {
    public let engine: TATEngine
    public let slackSolver: SlackSolver

    public init(engine: TATEngine, slackSolver: SlackSolver) {
        self.engine = engine
        self.slackSolver = slackSolver
    }

    /// Generates a Briefing for the given route, departure time and cruise speed.  Throws only
    /// if a provider raises an error; any missing data results in placeholder values.
    public func generateBriefing(for route: Route,
                                 etd: Date,
                                 stw: Double) async -> Briefing {
        let samples = await engine.computeTAT(for: route, etd: etd, stw: stw, deltaNM: 1.0)
        // Compute ETA and total duration.
        let eta: Date
        let duration: TimeInterval
        if let last = samples.last {
            eta = last.time
            duration = eta.timeIntervalSince(etd)
        } else {
            eta = etd
            duration = 0
        }
        let distance = route.totalDistanceNM()
        // Evaluate tidal passes.
        let cautions = slackSolver.evaluate(route: route, samples: samples)
        // Approximate sunrise and sunset at departure location and date.
        let coordinate = route.points.first ?? Coordinate(latitude: 0, longitude: 0)
        let (sunrise, sunset) = BriefingGenerator.approximateSunriseSunset(date: etd, coordinate: coordinate)
        // Collect remarks (placeholder warnings or advisories).  In a real implementation
        // these would fetch marine warnings from EC/NWS, compute debris risk, etc.
        var remarks: [String] = []
        if samples.contains(where: { $0.wave.height > 2.5 }) {
            remarks.append("Significant wave heights exceed 2.5 m at some point along the route.")
        }
        if samples.contains(where: { $0.risk == .high }) {
            remarks.append("High wind‑against‑current risk on some segments.  Expect steep seas.")
        }
        return Briefing(route: route,
                        etd: etd,
                        eta: eta,
                        duration: duration,
                        distanceNM: distance,
                        samples: samples,
                        passCautions: cautions,
                        sunrise: sunrise,
                        sunset: sunset,
                        remarks: remarks)
    }

    /// Computes approximate sunrise and sunset times for a given date and coordinate.  This is a
    /// simple heuristic that varies day length over the year as a sine wave.  Real ephemeris
    /// calculations require astronomical algorithms beyond the scope of this mock.
    private static func approximateSunriseSunset(date: Date, coordinate: Coordinate) -> (Date, Date) {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 180
        // Daylight hours oscillate between 8 and 16 hours across the year at mid latitudes.
        let daylightHours = 12.0 + 4.0 * sin(Double(dayOfYear) / 365.0 * 2.0 * .pi)
        let sunriseHour = 12.0 - daylightHours / 2.0
        let sunsetHour = 12.0 + daylightHours / 2.0
        var sunriseComps = calendar.dateComponents([.year, .month, .day], from: date)
        sunriseComps.hour = Int(sunriseHour)
        sunriseComps.minute = Int((sunriseHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        var sunsetComps = sunriseComps
        sunsetComps.hour = Int(sunsetHour)
        sunsetComps.minute = Int((sunsetHour.truncatingRemainder(dividingBy: 1.0)) * 60.0)
        let sunrise = calendar.date(from: sunriseComps) ?? date
        let sunset = calendar.date(from: sunsetComps) ?? date
        return (sunrise, sunset)
    }
}