//
//  Route.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit

/// Represents a route as a polyline of geographic coordinates.  The first point is the
/// departure location, the last point is the destination, and intermediate points are
/// via points (rubber‑band handles) inserted by the user.  A `Route` is immutable;
/// modifications yield a new route.
public struct Route: Codable, Equatable {
    public let points: [Coordinate]

    public init(points: [Coordinate]) {
        self.points = points
    }

    /// Returns the total great–circle distance of the route in nautical miles.
    public func totalDistanceNM() -> Double {
        guard points.count >= 2 else { return 0 }
        var distance: Double = 0
        for i in 0..<points.count - 1 {
            distance += Geometry.distanceNM(from: points[i], to: points[i + 1])
        }
        return distance
    }

    /// Returns a new list of coordinates sampled along this route at approximately equal
    /// distance spacing.  The caller specifies the desired sampling interval in nautical miles.
    /// At least the endpoints are returned.  This method performs linear interpolation
    /// on latitude/longitude pairs, which is acceptable for short segments (sub‑degree).
    public func resample(deltaNM: Double) -> [Coordinate] {
        guard points.count >= 2 else { return points }
        var sampled: [Coordinate] = []
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]
            let segDistance = Geometry.distanceNM(from: start, to: end)
            let numSegments = max(1, Int(ceil(segDistance / deltaNM)))
            for j in 0..<numSegments {
                let t = Double(j) / Double(numSegments)
                let lat = start.latitude + (end.latitude - start.latitude) * t
                let lon = start.longitude + (end.longitude - start.longitude) * t
                let coord = Coordinate(latitude: lat, longitude: lon)
                if sampled.isEmpty || sampled.last != coord {
                    sampled.append(coord)
                }
            }
        }
        // Append final destination.
        if let last = points.last {
            sampled.append(last)
        }
        return sampled
    }
}