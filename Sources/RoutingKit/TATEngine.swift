//
//  TATEngine.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit

/// Represents a sampled point along a route with associated oceanographic and meteorological data.
public struct VertexSample: Codable, Identifiable {
    public let id: UUID = UUID()
    public let coordinate: Coordinate
    public let time: Date
    public let sog: Double
    public let current: CurrentSample
    public let wind: WindSample
    public let wave: WaveSample
    public let risk: RiskLevel
}

/// Implements the time‑along‑track (TAT) algorithm.  Given a polyline, departure time, and
/// nominal speed through water, this engine computes the time of arrival at each sampled vertex
/// along the polyline by accounting for tidal currents.  It also samples wind and waves along
/// the track and computes a risk index for steep seas.
public struct TATEngine {
    public let windProvider: WindProvider
    public let currentProvider: CurrentProvider
    public let waveProvider: WaveProvider

    public init(windProvider: WindProvider, currentProvider: CurrentProvider, waveProvider: WaveProvider) {
        self.windProvider = windProvider
        self.currentProvider = currentProvider
        self.waveProvider = waveProvider
    }

    /// Computes the time‑along‑track samples for the given route.  The `deltaNM` parameter controls
    /// the resampling interval used along the route.  Smaller values yield more detailed output at
    /// the expense of execution time.
    public func computeTAT(for route: Route,
                           etd: Date,
                           stw: Double,
                           deltaNM: Double = 1.0) async -> [VertexSample] {
        var samples: [VertexSample] = []
        let coords = route.resample(deltaNM: deltaNM)
        guard coords.count >= 2 else { return samples }
        var t = etd
        for i in 0..<(coords.count - 1) {
            let start = coords[i]
            let end = coords[i + 1]
            // Compute segment length and course.
            let segLengthNM = Geometry.distanceNM(from: start, to: end)
            let bearing = Geometry.bearingDegrees(from: start, to: end)
            // Convert STW to vector using course bearing.
            let stwVec = Vector.vector(speedKnots: stw, headingDegrees: bearing)
            // Sample current at start point and current time.
            let currentStart: CurrentSample
            do {
                currentStart = try await currentProvider.current(at: start, time: t)
            } catch {
                currentStart = CurrentSample(vector: Vector(dx: 0, dy: 0))
            }
            // Combine to compute speed over ground vector.
            let sogVec = stwVec.adding(currentStart.vector)
            let sog = max(0.5, sogVec.magnitude)
            // Compute time increment in hours; avoid division by zero.
            let dtHours = segLengthNM / sog
            // Advance time for end of segment.
            t = t.addingTimeInterval(dtHours * 3600.0)
            // Sample environmental data at end point/time.
            let wind: WindSample
            let currentEnd: CurrentSample
            let wave: WaveSample
            do {
                wind = try await windProvider.wind(at: end, time: t)
            } catch {
                wind = WindSample(speed: 0, direction: 0)
            }
            do {
                currentEnd = try await currentProvider.current(at: end, time: t)
            } catch {
                currentEnd = CurrentSample(vector: Vector(dx: 0, dy: 0))
            }
            do {
                wave = try await waveProvider.wave(at: end, time: t)
            } catch {
                wave = WaveSample(height: 0, period: 0, direction: 0)
            }
            // Compute wind‑against‑current risk.
            let risk = TATEngine.computeRisk(wind: wind, current: currentEnd)
            // Append sample.  We store SOG to allow downstream estimations of fuel/ETA.
            let sample = VertexSample(coordinate: end, time: t, sog: sog, current: currentEnd, wind: wind, wave: wave, risk: risk)
            samples.append(sample)
        }
        return samples
    }

    /// Computes a risk level based on the wind and current samples.  This uses the wind‑against‑current
    /// index defined in the design specification: WA = max(0, cos(angleBetween(wind.dir, -current.dir))) * |W| * |C|.
    /// Thresholds (units knots^2) are 12 (high), 6 (moderate), otherwise low.
    private static func computeRisk(wind: WindSample, current: CurrentSample) -> RiskLevel {
        // Convert wind direction (meteorological) to heading towards which the wind is blowing.
        var windHeading = wind.direction + 180.0
        if windHeading >= 360.0 { windHeading -= 360.0 }
        // Compute angle between windHeading and current's heading.
        let angleDiff = abs(windHeading - current.direction)
        let angle = min(angleDiff, 360.0 - angleDiff)
        let rad = angle * .pi / 180.0
        let oppose = max(0.0, cos(rad))
        let wa = oppose * wind.speed * current.speed
        if wa > 12.0 {
            return .high
        } else if wa > 6.0 {
            return .moderate
        } else {
            return .low
        }
    }
}