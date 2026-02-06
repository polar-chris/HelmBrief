//
//  Geometry.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit

/// Utilities for spherical geometry and navigation.
enum Geometry {
    /// Earth's mean radius in metres.
    private static let earthRadiusMetres: Double = 6_371_000.0
    /// Conversion factor from metres to nautical miles.
    private static let metresPerNauticalMile: Double = 1852.0

    /// Computes the great–circle distance between two coordinates using the Haversine formula.
    /// - Returns: The distance in nautical miles.
    static func distanceNM(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0
        let dlat = (b.latitude - a.latitude) * .pi / 180.0
        let dlon = (b.longitude - a.longitude) * .pi / 180.0
        let sinDlat = sin(dlat / 2.0)
        let sinDlon = sin(dlon / 2.0)
        let h = sinDlat * sinDlat + cos(lat1) * cos(lat2) * sinDlon * sinDlon
        let c = 2.0 * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h)))
        let distanceMetres = Geometry.earthRadiusMetres * c
        return distanceMetres / Geometry.metresPerNauticalMile
    }

    /// Computes the initial true heading from coordinate `a` to coordinate `b`.
    /// The result is expressed in degrees, where 0° is north and 90° is east.
    static func bearingDegrees(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180.0
        let lat2 = b.latitude * .pi / 180.0
        let dlon = (b.longitude - a.longitude) * .pi / 180.0
        let y = sin(dlon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)
        let rad = atan2(y, x)
        var deg = rad * 180.0 / .pi
        deg = (deg < 0 ? deg + 360.0 : deg)
        return deg
    }
}

extension Vector {
    /// Creates a velocity vector from a speed in knots and a heading in degrees.
    /// A heading of 0° points north and 90° points east.  The resulting vector's units are knots.
    static func vector(speedKnots: Double, headingDegrees: Double) -> Vector {
        let rad = headingDegrees * .pi / 180.0
        let dx = speedKnots * sin(rad)
        let dy = speedKnots * cos(rad)
        return Vector(dx: dx, dy: dy)
    }
}