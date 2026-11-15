import CoreGraphics
import CoreImage
import Foundation
import Vision
import OpticalCore
import RescueKit

public enum KroutonDiscHubGeometry: String, Codable, Sendable, CaseIterable {
    case standard120mmHub41mm     = "Standard 120mm Disc (41mm Clear Hub)"
    case fullFace120mmHub22mm     = "Full-Face Inkjet 120mm (22mm Micro Hub)"
    case miniDisc80mmHub22mm      = "Mini Optical 80mm Disc (22mm Hub)"

    public var outerPrintDiameterMM: Double {
        switch self {
        case .standard120mmHub41mm, .fullFace120mmHub22mm: return 118.0
        case .miniDisc80mmHub22mm: return 78.0
        }
    }

    public var innerHubDiameterMM: Double {
        switch self {
        case .standard120mmHub41mm: return 41.0
        case .fullFace120mmHub22mm, .miniDisc80mmHub22mm: return 22.0
        }
    }

    /// Standard 120mm physical canvas @ 300 DPI = 1417 x 1417 px (120mm / 25.4mm * 300 dpi)
    public func canvasPixelDimension(dpi: Double = 300.0) -> Int {
        Int(((120.0 / 25.4) * dpi).rounded())
    }
}

public struct KroutonPolarArcGlyphPlacement: Sendable, Equatable, Identifiable {
    public let id: Int
    public let character: String
    public let xPoints: Double
    public let yPoints: Double
    public let angleRadians: Double
    public let tangentRotationRadians: Double
}

public struct KroutonLabelGeometryEngine {
    public static let version = "0.1.0-alpha.1"

    /// Evaluates what the optical rescue reader should do when encountering a sector at `lba`
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
                nextCursorLBA: lba, // stay on current LBA for low-speed CLV re-read
                replacementSectorBytes: 0
            )
        }

        // Retries exhausted on radial scratch -> zero-pad sector to maintain exact LBA alignment and skip
        let step = max(1, fastSkipStepLBA)
        return KroutonSectorRescueDecision(
            lba: lba,
            action: .substituteZeroSector,
            recommendedSpindleSpeedX: 2,
            nextCursorLBA: lba + step,
            replacementSectorBytes: sectorSizeBytes
        )
    }

    /// Hit-tests whether a Cartesian point (x, y) relative to disc center lies strictly within the printable ink annulus
    public static func isPointInsidePrintableAnnulus(
        dxMM: Double,
        dyMM: Double,
        geometry: KroutonDiscHubGeometry = .fullFace120mmHub22mm,
        bleedMarginMM: Double = 1.0
    ) -> Bool {
        let r = hypot(dxMM, dyMM)
        let rMin = (geometry.innerHubDiameterMM / 2.0) + bleedMarginMM
        let rMax = (geometry.outerPrintDiameterMM / 2.0) - bleedMarginMM
        return r >= rMin && r <= rMax
    }

    /// Computes polar-to-Cartesian (x, y) coordinates and tangent angles for curved disc label typography
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

// MARK: - Sprint 3: Unified Bad-Sector Optical Rescue Map & Post-Burn Archival Grading

extension KroutonLabelGeometryEngine {
    public static func buildOpticalRescueMap(
        totalSectorsLBA: Int64 = 333_000,
        scratchSeverity: Int = 0
    ) -> KroutonOpticalRescueMapSnapshot {
        KroutonRescueEngine.buildOpticalRescueMap(
            totalSectorsLBA: totalSectorsLBA,
            scratchSeverity: scratchSeverity
        )
    }

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
