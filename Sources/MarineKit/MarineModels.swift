//
//  MarineModels.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import CoreLocation

/// Represents a geographic coordinate.  Using a simple struct avoids taking a dependency
/// on MapKit in lower layers of the stack.  Higher layers can convert to/from
/// CLLocationCoordinate2D as needed.
public struct Coordinate: Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    public var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A simple two–dimensional vector used for representing current and wind fields.
public struct Vector: Codable {
    public var dx: Double
    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    /// Computes the magnitude of the vector.
    public var magnitude: Double {
        sqrt(dx * dx + dy * dy)
    }

    /// Returns the direction of the vector in degrees from north (0° = north, 90° = east).
    public var direction: Double {
        // atan2 returns radians measured from positive x axis; convert to compass.
        let rad = atan2(dy, dx)
        let deg = rad * 180.0 / .pi
        let compass = 90.0 - deg
        return (compass < 0 ? compass + 360.0 : compass).truncatingRemainder(dividingBy: 360.0)
    }

    /// Adds another vector to this one.
    public func adding(_ other: Vector) -> Vector {
        Vector(dx: dx + other.dx, dy: dy + other.dy)
    }

    /// Subtracts another vector from this one.
    public func subtracting(_ other: Vector) -> Vector {
        Vector(dx: dx - other.dx, dy: dy - other.dy)
    }

    /// Returns a vector scaled by the given factor.
    public func scaled(by factor: Double) -> Vector {
        Vector(dx: dx * factor, dy: dy * factor)
    }
}

/// Represents a sampled wind field at a point in space and time.
public struct WindSample: Codable {
    /// Mean wind speed in knots.
    public var speed: Double
    /// Wind direction in degrees from which the wind is blowing (meteorological).
    public var direction: Double
    /// Maximum gust speed in knots, if available.
    public var gust: Double?
    /// Sea level pressure in millibars or kilopascals, if available.
    public var pressure: Double?
    /// Precipitation rate in mm/h, if available.
    public var precipitation: Double?
    /// Air temperature in degrees Celsius, if available.
    public var temperature: Double?

    public init(speed: Double,
                direction: Double,
                gust: Double? = nil,
                pressure: Double? = nil,
                precipitation: Double? = nil,
                temperature: Double? = nil) {
        self.speed = speed
        self.direction = direction
        self.gust = gust
        self.pressure = pressure
        self.precipitation = precipitation
        self.temperature = temperature
    }
}

/// Represents a sampled wave field.
public struct WaveSample: Codable {
    /// Significant wave height in metres.
    public var height: Double
    /// Peak period in seconds.
    public var period: Double
    /// Wave direction (coming from) in degrees.
    public var direction: Double

    public init(height: Double, period: Double, direction: Double) {
        self.height = height
        self.period = period
        self.direction = direction
    }
}

/// Represents a sampled current vector.
public struct CurrentSample: Codable {
    /// The horizontal current vector.  Positive x points east, positive y points north.
    public var vector: Vector

    public init(vector: Vector) {
        self.vector = vector
    }

    /// Convenience accessors.
    public var speed: Double {
        vector.magnitude
    }
    public var direction: Double {
        vector.direction
    }
}

/// Enumeration describing risk categories for steep seas or wind‑against‑current conditions.
public enum RiskLevel: String, Codable {
    case low
    case moderate
    case high
}

/// Describes a critical tidal gate or rapid.  See SlackSolver in RoutingKit for usage.
public struct CriticalPass: Codable, Identifiable {
    public var id: UUID = UUID()
    /// Human‑readable name of the pass.
    public let name: String
    /// A polygon enclosing the area of the pass.  If any segment of a route intersects this polygon,
    /// the slack solver evaluates timing relative to tidal slack.
    public let polygon: [Coordinate]
    /// Identifier for the reference tide station associated with this pass.
    public let referenceStationID: String
    /// Offset in minutes from the reference slack to the actual pass slack (positive means later).
    public let slackOffsetMinutes: Int
    /// Window in minutes around slack considered “safe” for transit.  Example: 15 = ±15 minutes.
    public let safeWindowMinutes: Int
    /// Nominal ebb flow direction in degrees from north.
    public let ebbHeading: Double
    /// Nominal flood flow direction in degrees from north.
    public let floodHeading: Double

    public init(name: String,
                polygon: [Coordinate],
                referenceStationID: String,
                slackOffsetMinutes: Int,
                safeWindowMinutes: Int,
                ebbHeading: Double,
                floodHeading: Double) {
        self.name = name
        self.polygon = polygon
        self.referenceStationID = referenceStationID
        self.slackOffsetMinutes = slackOffsetMinutes
        self.safeWindowMinutes = safeWindowMinutes
        self.ebbHeading = ebbHeading
        self.floodHeading = floodHeading
    }
}

/// Represents a caution or advisory for a specific pass along the route.
public struct PassCaution: Codable, Identifiable {
    public var id: UUID = UUID()
    public let pass: CriticalPass
    /// Human‑readable message describing the caution (e.g. “Adjust ETD by +58 minutes to hit slack”).
    public let message: String
    /// The recommended time shift (in seconds) to meet the safe window.  Positive values suggest
    /// delaying departure; negative values suggest leaving earlier.
    public let etdAdjustment: TimeInterval
    /// The safe time window in absolute times.
    public let safeWindow: ClosedRange<Date>

    public init(pass: CriticalPass, message: String, etdAdjustment: TimeInterval, safeWindow: ClosedRange<Date>) {
        self.pass = pass
        self.message = message
        self.etdAdjustment = etdAdjustment
        self.safeWindow = safeWindow
    }
}