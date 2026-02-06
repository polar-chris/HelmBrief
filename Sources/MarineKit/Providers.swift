//
//  Providers.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation

/// Protocol describing an asynchronous provider of wind fields.  Implementations may
/// return deterministic values, fetch from remote web services, or pull from local caches.
public protocol WindProvider {
    /// Returns a wind sample for the given coordinate and time.
    func wind(at coordinate: Coordinate, time: Date) async throws -> WindSample
}

/// Protocol describing an asynchronous provider of current fields.
public protocol CurrentProvider {
    /// Returns a current sample for the given coordinate and time.
    func current(at coordinate: Coordinate, time: Date) async throws -> CurrentSample
}

/// Protocol describing an asynchronous provider of wave fields.
public protocol WaveProvider {
    /// Returns a wave sample for the given coordinate and time.
    func wave(at coordinate: Coordinate, time: Date) async throws -> WaveSample
}

/// A mock implementation of wind provider that generates plausible values without hitting a network.
public final class MockWindProvider: WindProvider {
    public init() {}

    public func wind(at coordinate: Coordinate, time: Date) async throws -> WindSample {
        // Synthesize a wind pattern based on latitude and hour of day.
        let hour = Calendar.current.component(.hour, from: time)
        // Base speed increases slightly in the afternoon (e.g., sea breeze).
        let baseSpeed = 10.0 + Double(hour - 12) * 0.5
        // Use a simple sine wave over the year to vary direction.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: time) ?? 1
        let direction = 180.0 + 60.0 * sin(Double(dayOfYear) / 365.0 * 2.0 * .pi)
        // Gusts 50% higher than mean.
        let gust = baseSpeed * 1.5
        return WindSample(speed: max(0, baseSpeed), direction: direction, gust: gust)
    }
}

/// A mock implementation of current provider that synthesizes tidal currents.
public final class MockCurrentProvider: CurrentProvider {
    public init() {}

    public func current(at coordinate: Coordinate, time: Date) async throws -> CurrentSample {
        // Compute a synthetic current that oscillates sinusoidally with the tidal cycle (12.42 h).
        let secondsPerTide: TimeInterval = 12.42 * 3600.0
        let t0 = Date(timeIntervalSince1970: 0)
        let phase = (time.timeIntervalSince(t0).truncatingRemainder(dividingBy: secondsPerTide)) / secondsPerTide * 2.0 * .pi
        // Magnitude peaks at 3 knots.
        let magnitude = 3.0 * sin(phase)
        // Direction rotates slowly with latitude to give variation.
        let directionRad = (coordinate.latitude + coordinate.longitude) * .pi / 180.0 * 0.1 + phase
        let dx = magnitude * cos(directionRad)
        let dy = magnitude * sin(directionRad)
        return CurrentSample(vector: Vector(dx: dx, dy: dy))
    }
}

/// A mock implementation of wave provider that generates a background swell.
public final class MockWaveProvider: WaveProvider {
    public init() {}

    public func wave(at coordinate: Coordinate, time: Date) async throws -> WaveSample {
        // Create a gentle swell pattern with periodic modulation.
        let secondsPerCycle: TimeInterval = 8.0 * 3600.0
        let t0 = Date(timeIntervalSince1970: 0)
        let phase = (time.timeIntervalSince(t0).truncatingRemainder(dividingBy: secondsPerCycle)) / secondsPerCycle * 2.0 * .pi
        let height = 1.0 + 0.5 * sin(phase)
        let period = 8.0 + 1.0 * cos(phase)
        let direction = 225.0 // constant south‑west swell
        return WaveSample(height: height, period: period, direction: direction)
    }
}