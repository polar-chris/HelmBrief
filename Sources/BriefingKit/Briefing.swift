//
//  Briefing.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit
import RoutingKit

/// A comprehensive summary of a planned passage.  The Briefing contains high‑level metrics
/// (distance, ETA, total underway time), environmental snapshots, and any cautions for
/// tidal gates encountered along the route.  It can be rendered as a report or PDF.
public struct Briefing: Identifiable {
    public let id: UUID = UUID()
    /// Original route.
    public let route: Route
    /// Scheduled departure time.
    public let etd: Date
    /// Estimated time of arrival at the destination.
    public let eta: Date
    /// Total duration underway in seconds.
    public let duration: TimeInterval
    /// Total distance of the route in nautical miles.
    public let distanceNM: Double
    /// Samples along the track.
    public let samples: [VertexSample]
    /// Any cautions triggered by critical passes on the route.
    public let passCautions: [PassCaution]
    /// Approximate sunrise at departure location on departure day.
    public let sunrise: Date
    /// Approximate sunset at departure location on departure day.
    public let sunset: Date
    /// Additional remarks (warnings, advisory notes, etc.).
    public let remarks: [String]
}