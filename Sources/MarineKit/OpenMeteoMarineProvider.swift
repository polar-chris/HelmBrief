//
//  OpenMeteoMarineProvider.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//
//  This provider fetches real marine and weather forecasts from the Open‑Meteo API.
//  The API combines multiple national models and automatically selects the best available
//  forecast for a given location.  See https://open-meteo.com for documentation.
//  The provider makes separate requests to the general forecast API (for wind) and
//  the marine API (for waves and currents), caches results for repeated lookups and
//  extracts values nearest to the requested time.

import Foundation

/// Encapsulates marine and weather forecasts returned by the Open‑Meteo API.  The
/// hourly arrays contain parallel arrays of timestamps and variable values.  Times
/// are represented as UNIX seconds.  Only a subset of variables is decoded.
private struct OpenMeteoMarineResponse: Codable {
    struct Hourly: Codable {
        let time: [Int]
        let wave_height: [Double]?
        let wave_direction: [Double]?
        let ocean_current_velocity: [Double]?
        let ocean_current_direction: [Double]?
    }
    let hourly: Hourly
}

private struct OpenMeteoWeatherResponse: Codable {
    struct Hourly: Codable {
        let time: [Int]
        let wind_speed_10m: [Double]?
        let wind_direction_10m: [Double]?
        let wind_gusts_10m: [Double]?
    }
    let hourly: Hourly
}

/// A live provider that fetches marine and wind data from the Open‑Meteo API.  It
/// conforms to `WindProvider`, `WaveProvider` and `CurrentProvider`.  The provider
/// caches the last fetched forecast per coordinate/day to reduce network traffic.
public actor OpenMeteoMarineProvider: WindProvider, WaveProvider, CurrentProvider {
    /// Shared URL session.
    private let session: URLSession
    /// Cache keyed by "lat,lon,date" to a decoded forecast.  Each entry holds both
    /// marine and weather responses.
    private var cache: [String: (marine: OpenMeteoMarineResponse, weather: OpenMeteoWeatherResponse)] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - WindProvider
    public func wind(at coordinate: Coordinate, time date: Date) async throws -> WindSample {
        let forecast = try await forecastForCoordinate(coordinate, date: date)
        // Find the index of the nearest hour in the time array.
        let unix = Int(date.timeIntervalSince1970)
        let times = forecast.weather.hourly.time
        guard let nearestIndex = nearestIndex(in: times, to: unix),
              let speedArray = forecast.weather.hourly.wind_speed_10m,
              let dirArray = forecast.weather.hourly.wind_direction_10m else {
            throw NSError(domain: "OpenMeteoProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No wind data available"])
        }
        let gustArray = forecast.weather.hourly.wind_gusts_10m
        let speedMS = speedArray[nearestIndex]
        let direction = dirArray[nearestIndex]
        let gustMS = gustArray?[nearestIndex]
        // Convert m/s to knots (1 m/s = 1.94384 kn).
        let speedKn = speedMS * 1.94384
        let gustKn = gustMS != nil ? gustMS! * 1.94384 : nil
        return WindSample(speed: speedKn, direction: direction, gust: gustKn)
    }

    // MARK: - WaveProvider
    public func wave(at coordinate: Coordinate, time date: Date) async throws -> WaveSample {
        let forecast = try await forecastForCoordinate(coordinate, date: date)
        let unix = Int(date.timeIntervalSince1970)
        let times = forecast.marine.hourly.time
        guard let nearestIndex = nearestIndex(in: times, to: unix),
              let waveHeights = forecast.marine.hourly.wave_height,
              let waveDirections = forecast.marine.hourly.wave_direction else {
            throw NSError(domain: "OpenMeteoProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No wave data available"])
        }
        let height = waveHeights[nearestIndex]
        let direction = waveDirections[nearestIndex]
        // The API does not provide wave period directly; return a nominal 8 s.
        let period = 8.0
        return WaveSample(height: height, period: period, direction: direction)
    }

    // MARK: - CurrentProvider
    public func current(at coordinate: Coordinate, time date: Date) async throws -> CurrentSample {
        let forecast = try await forecastForCoordinate(coordinate, date: date)
        let unix = Int(date.timeIntervalSince1970)
        let times = forecast.marine.hourly.time
        guard let nearestIndex = nearestIndex(in: times, to: unix),
              let velocities = forecast.marine.hourly.ocean_current_velocity,
              let directions = forecast.marine.hourly.ocean_current_direction else {
            throw NSError(domain: "OpenMeteoProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current data available"])
        }
        let speedKMH = velocities[nearestIndex]
        let direction = directions[nearestIndex]
        // Convert km/h to knots (1 km/h = 0.539957 kn).
        let speedKn = speedKMH * 0.539957
        // Convert to vector (heading is direction of travel, not from).
        let vector = Vector.vector(speedKnots: speedKn, headingDegrees: direction)
        return CurrentSample(vector: vector)
    }

    // MARK: - Internal Helpers
    /// Returns a forecast record for the given coordinate and date.  Forecasts are
    /// cached by day to prevent redundant network calls.  The API is queried for
    /// the full day of the provided date.
    private func forecastForCoordinate(_ coordinate: Coordinate, date: Date) async throws -> (marine: OpenMeteoMarineResponse, weather: OpenMeteoWeatherResponse) {
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dayStart = calendar.date(from: comps) else {
            throw NSError(domain: "OpenMeteoProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compute day start"])
        }
        let dayKey = String(format: "%.4f,%.4f,%@", coordinate.latitude, coordinate.longitude, dayStart.description)
        if let cached = cache[dayKey] {
            return cached
        }
        // Format ISO date for API.
        let isoDate = ISO8601DateFormatter().string(from: dayStart).prefix(10)
        let dateString = String(isoDate)
        // Build marine API URL.
        var marineURLComponents = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine")!
        marineURLComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,ocean_current_velocity,ocean_current_direction"),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "cell_selection", value: "sea")
        ]
        // Build weather API URL (for winds and gusts).
        var weatherURLComponents = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        weatherURLComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "UTC")
        ]
        // Perform both requests concurrently.
        async let marineData = fetchAndDecode(OpenMeteoMarineResponse.self, from: marineURLComponents.url!)
        async let weatherData = fetchAndDecode(OpenMeteoWeatherResponse.self, from: weatherURLComponents.url!)
        let marineResponse = try await marineData
        let weatherResponse = try await weatherData
        // Cache the result and return.
        cache[dayKey] = (marine: marineResponse, weather: weatherResponse)
        return (marine: marineResponse, weather: weatherResponse)
    }

    /// Fetches data from the specified URL and decodes it as the given type.  Throws
    /// if the network request or decoding fails.
    private func fetchAndDecode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "OpenMeteoProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad HTTP response"])
        }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Returns the index of the element in `array` whose value is nearest to `target`.
    private func nearestIndex(in array: [Int], to target: Int) -> Int? {
        guard !array.isEmpty else { return nil }
        var bestIndex = 0
        var bestDelta = abs(array[0] - target)
        for (i, value) in array.enumerated().dropFirst() {
            let delta = abs(value - target)
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = i
            }
        }
        return bestIndex
    }
}