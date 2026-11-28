import CoreGraphics
import CoreImage
import Foundation
import RescueKit
import Vision

// MARK: - Label Geometry

/// Printable disc sizes: the print diameter and the hub left clear. Not used by the label canvas
/// yet (see PENDING_INTEGRATION.md).
public enum KroutonDiscHubGeometry: String, Codable, Sendable, CaseIterable {
    case standard120mmHub41mm     = "Standard 120mm Disc (41mm Clear Hub)"
    case fullFace120mmHub22mm     = "Full-Face Inkjet 120mm (22mm Micro Hub)"
    case miniDisc80mmHub22mm      = "Mini Optical 80mm Disc (22mm Hub)"

    var outerPrintDiameterMM: Double {
        switch self {
        case .standard120mmHub41mm, .fullFace120mmHub22mm: return 118.0
        case .miniDisc80mmHub22mm: return 78.0
        }
    }

    var innerHubDiameterMM: Double {
        switch self {
        case .standard120mmHub41mm: return 41.0
        case .fullFace120mmHub22mm, .miniDisc80mmHub22mm: return 22.0
        }
    }

    /// The side of a square canvas for a 120 mm disc at `dpi`, in pixels (1,417 at 300 dpi).
    public func canvasPixelDimension(dpi: Double = 300.0) -> Int {
        Int(((120.0 / 25.4) * dpi).rounded())
    }
}

/// Where one character of curved text goes.
public struct KroutonPolarArcGlyphPlacement: Sendable, Equatable, Identifiable {
    /// The character's index in the text.
    public let id: Int
    /// The character.
    public let character: String
    let xPoints: Double
    let yPoints: Double
    let angleRadians: Double
    let tangentRotationRadians: Double
}

/// Label geometry: curved text, shapes, shaders, the PDF print sheet and photo adjustments (see its
/// extensions).
public struct KroutonLabelGeometryEngine {
    /// The module version krouton-verify checks.
    public static let version = "0.1.0-alpha.1"

    /// A copy of `KroutonRescueEngine.evaluateSectorRescue` (RescueKit), not a call to it. Only
    /// krouton-verify calls it.
    public static func evaluateSectorRescue(
        lba: Int64,
        c2ErrorCount: Int,
        retryAttempt: Int,
        maxRetries: Int = 5,
        normalSpeedX: Int = 16,
        sectorSizeBytes: Int = 2048,
        fastSkipStepLBA: Int64 = 16
    ) -> KroutonSectorRescueDecision {
        if c2ErrorCount <= 0 {
            return KroutonSectorRescueDecision(
                lba: lba,
                action: .readCleanFullSpeed,
                recommendedSpindleSpeedX: normalSpeedX,
                nextCursorLBA: lba + 1,
                replacementSectorBytes: 0
            )
        }

        if retryAttempt < maxRetries {
            return KroutonSectorRescueDecision(
                lba: lba,
                action: .downshiftRetry2xCLV,
                recommendedSpindleSpeedX: 2,
                nextCursorLBA: lba, // read the same sector again, slower
                replacementSectorBytes: 0
            )
        }

        // Out of retries: substitute zeros so every later sector keeps its offset, and skip ahead.
        let step = max(1, fastSkipStepLBA)
        return KroutonSectorRescueDecision(
            lba: lba,
            action: .substituteZeroSector,
            recommendedSpindleSpeedX: 2,
            nextCursorLBA: lba + step,
            replacementSectorBytes: sectorSizeBytes
        )
    }

    /// Places each character of `text` evenly along an arc of `arcSpanRadians` centred on
    /// `centerAngleRadians` (the top by default), with the rotation that keeps it tangent.
    public static func computePolarArcGlyphLayout(
        text: String,
        centerX: Double,
        centerY: Double,
        radiusPoints: Double,
        centerAngleRadians: Double = -.pi / 2.0, // Top 12-o'clock crown
        arcSpanRadians: Double = .pi * 0.65
    ) -> [KroutonPolarArcGlyphPlacement] {
        let chars = Array(text)
        guard !chars.isEmpty else { return [] }

        if chars.count == 1 {
            let x = centerX + radiusPoints * cos(centerAngleRadians)
            let y = centerY + radiusPoints * sin(centerAngleRadians)
            return [
                KroutonPolarArcGlyphPlacement(
                    id: 0,
                    character: String(chars[0]),
                    xPoints: x,
                    yPoints: y,
                    angleRadians: centerAngleRadians,
                    tangentRotationRadians: centerAngleRadians + (.pi / 2.0)
                )
            ]
        }

        let startAngle = centerAngleRadians - (arcSpanRadians / 2.0)
        let step = arcSpanRadians / Double(chars.count - 1)

        return chars.enumerated().map { idx, ch in
            let theta = startAngle + Double(idx) * step
            let x = centerX + radiusPoints * cos(theta)
            let y = centerY + radiusPoints * sin(theta)
            return KroutonPolarArcGlyphPlacement(
                id: idx,
                character: String(ch),
                xPoints: x,
                yPoints: y,
                angleRadians: theta,
                tangentRotationRadians: theta + (.pi / 2.0)
            )
        }
    }
}

// MARK: - Rescue Map and Archival Grade (pass-throughs to RescueKit)

// These are the only reason LabelKit depends on RescueKit (open question #6).

extension KroutonLabelGeometryEngine {
    /// Calls `KroutonRescueEngine.buildOpticalRescueMap`: a fixed sample pattern, not a disc.
    public static func buildOpticalRescueMap(
        totalSectorsLBA: Int64 = 333_000,
        scratchSeverity: Int = 0
    ) -> KroutonOpticalRescueMapSnapshot {
        KroutonRescueEngine.buildOpticalRescueMap(
            totalSectorsLBA: totalSectorsLBA,
            scratchSeverity: scratchSeverity
        )
    }

    /// Calls `KroutonRescueEngine.evaluateArchivalDiscGrade`. The app passes no measurements, so
    /// the result is always "NOT MEASURED".
    public static func evaluateArchivalDiscGrade(
        driveModel: String,
        mediaType: String,
        sectorsWrittenLBA: Int64,
        c1Rate: Double? = nil,
        c2Count: Int? = nil,
        jitterPercent: Double? = nil
    ) -> KroutonArchivalQualityCertificate {
        KroutonRescueEngine.evaluateArchivalDiscGrade(
            driveModel: driveModel,
            mediaType: mediaType,
            sectorsWrittenLBA: sectorsWrittenLBA,
            c1Rate: c1Rate,
            c2Count: c2Count,
            jitterPercent: jitterPercent
        )
    }
}
