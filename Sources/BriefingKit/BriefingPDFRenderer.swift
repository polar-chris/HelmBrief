//
//  BriefingPDFRenderer.swift
//  HelmBrief
//
//  Created by ChatGPT on 2026-01-20.
//

import Foundation
import MarineKit
import RoutingKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// A simple PDF renderer that converts a Briefing into a PDF document.  The resulting PDF
/// contains a summary header followed by caution messages and remarks.  For a richer layout,
/// consider using SwiftUIʼs `PDFRenderer` in conjunction with views or `PDFKit` page composition.
public final class BriefingPDFRenderer {
    public init() {}

    /// Renders the given briefing to the specified file URL.  If the directory does not exist,
    /// it will be created.  Throws if writing fails.
    public func render(briefing: Briefing, to url: URL) throws {
        // Ensure parent directory exists.
        let dirURL = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
#if canImport(UIKit) && canImport(PDFKit)
        // Define page size (A4 portrait).
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        let meta: [String: Any] = [
            kCGPDFContextCreator as String: "HelmBrief",
            kCGPDFContextTitle as String: "Passage Plan"
        ]
        format.documentInfo = meta
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var yPos: CGFloat = 36
            let xMargin: CGFloat = 36
            // Title
            let title = "HelmBrief Passage Plan"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            title.draw(at: CGPoint(x: xMargin, y: yPos), withAttributes: titleAttributes)
            yPos += 32
            // Summary
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let etdStr = dateFormatter.string(from: briefing.etd)
            let etaStr = dateFormatter.string(from: briefing.eta)
            let durationHours = briefing.duration / 3600.0
            let summaryLines = [
                String(format: "Distance: %.1f NM", briefing.distanceNM),
                "ETD: \(etdStr)",
                "ETA: \(etaStr)",
                String(format: "Underway: %.1f h", durationHours),
                "Sunrise: \(dateFormatter.string(from: briefing.sunrise))",
                "Sunset: \(dateFormatter.string(from: briefing.sunset))"
            ]
            let bodyFont = UIFont.systemFont(ofSize: 14)
            for line in summaryLines {
                line.draw(at: CGPoint(x: xMargin, y: yPos), withAttributes: [.font: bodyFont])
                yPos += 18
            }
            yPos += 10
            // Pass cautions
            if !briefing.passCautions.isEmpty {
                let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
                "Passage Cautions:".draw(at: CGPoint(x: xMargin, y: yPos), withAttributes: subtitleAttributes)
                yPos += 22
                for caution in briefing.passCautions {
                    caution.message.draw(at: CGPoint(x: xMargin + 12, y: yPos), withAttributes: [.font: bodyFont])
                    yPos += 18
                    // Show safe window times.
                    let startStr = dateFormatter.string(from: caution.safeWindow.lowerBound)
                    let endStr = dateFormatter.string(from: caution.safeWindow.upperBound)
                    let windowLine = "Safe: \(startStr) – \(endStr)"
                    windowLine.draw(at: CGPoint(x: xMargin + 24, y: yPos), withAttributes: [.font: UIFont.italicSystemFont(ofSize: 12)])
                    yPos += 16
                }
                yPos += 10
            }
            // Remarks
            if !briefing.remarks.isEmpty {
                let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
                "Remarks:".draw(at: CGPoint(x: xMargin, y: yPos), withAttributes: subtitleAttributes)
                yPos += 22
                for remark in briefing.remarks {
                    remark.draw(at: CGPoint(x: xMargin + 12, y: yPos), withAttributes: [.font: bodyFont])
                    yPos += 18
                }
                yPos += 10
            }
        }
#else
        // Fallback implementation: write a plain‑text representation to the file.
        var lines: [String] = []
        lines.append("HelmBrief Passage Plan")
        lines.append(String(format: "Distance: %.1f NM", briefing.distanceNM))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        lines.append("ETD: \(dateFormatter.string(from: briefing.etd))")
        lines.append("ETA: \(dateFormatter.string(from: briefing.eta))")
        let durationHours = briefing.duration / 3600.0
        lines.append(String(format: "Underway: %.1f h", durationHours))
        lines.append("Sunrise: \(dateFormatter.string(from: briefing.sunrise))")
        lines.append("Sunset: \(dateFormatter.string(from: briefing.sunset))")
        for caution in briefing.passCautions {
            lines.append("Caution: \(caution.message)")
        }
        for remark in briefing.remarks {
            lines.append("Note: \(remark)")
        }
        let text = lines.joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
#endif
    }
    }
}