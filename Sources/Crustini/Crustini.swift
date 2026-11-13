import Vision
import CoreGraphics
import Foundation
import CoreGraphics
import OpticalDough

// MARK: - Part A: Optical Rescue & Adaptive Sector Copy Engine
public enum KroutonSectorRescueAction: String, Codable, Sendable, Equatable {
    case readCleanFullSpeed    = "CLEAN_BURST"
    case downshiftRetry2xCLV   = "DOWNSHIFT_2X_RETRY"
    case substituteZeroSector  = "ZERO_PAD_SUBSTITUTE"
}

public struct KroutonSectorRescueDecision: Sendable, Equatable {
    public let lba: Int64
    public let action: KroutonSectorRescueAction
    public let recommendedSpindleSpeedX: Int
    public let nextCursorLBA: Int64
    public let replacementSectorBytes: Int
}

// MARK: - Part B: Polar-Coordinate Mini Graphics Layout & 300-DPI Disc Label Engine
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

public struct KroutonKrustiniModule {
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

    /// Converts millimeters to pixels at a target DPI (default 300 DPI print master)
    public static func mmToPixels(_ mm: Double, dpi: Double = 300.0) -> Double {
        (mm / 25.4) * dpi
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

    // MARK: - Freehand Drawn Shape -> Automatic Crisp Vector Shape Recognizer

    public static func recognizeAndVectorizeDrawnStroke(
        rawPoints: [KroutonNormalizedPoint],
        autoSnapGeometry: Bool = true,
        strokeColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.25, g: 0.88, b: 0.96, a: 1.0)
    ) -> KroutonVectorShapeLayer {
        guard rawPoints.count >= 3 else {
            return KroutonVectorShapeLayer(name: "Vector Line", kind: .smoothBezier, points: rawPoints, isClosed: false, strokeColor: strokeColor)
        }

        let xs = rawPoints.map(\.nx)
        let ys = rawPoints.map(\.ny)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let width = max(0.02, maxX - minX)
        let height = max(0.02, maxY - minY)
        let cx = (minX + maxX) * 0.5
        let cy = (minY + maxY) * 0.5
        let diag = hypot(width, height)

        let firstPt = rawPoints.first!
        let lastPt = rawPoints.last!
        let closureDist = hypot(lastPt.nx - firstPt.nx, lastPt.ny - firstPt.ny)
        let isClosedStroke = (closureDist < diag * 0.32) && rawPoints.count >= 8

        if autoSnapGeometry && isClosedStroke {
            let avgR = (width + height) * 0.25
            let radialErrors = rawPoints.map { abs(hypot($0.nx - cx, $0.ny - cy) - avgR) / max(0.01, avgR) }
            let meanRadialError = radialErrors.reduce(0.0, +) / Double(radialErrors.count)
            let aspect = min(width, height) / max(width, height)

            if meanRadialError < 0.22 && aspect > 0.72 {
                let circlePts = (0..<36).map { i -> KroutonNormalizedPoint in
                    let ang = Double(i) * (2.0 * Double.pi / 36.0)
                    return KroutonNormalizedPoint(nx: cx + cos(ang) * avgR, ny: cy + sin(ang) * avgR)
                }
                let isHubRing = hypot(cx, cy) < 0.14
                return KroutonVectorShapeLayer(
                    name: isHubRing ? "Concentric Ring" : "Snapped Circle",
                    kind: isHubRing ? .concentricRing : .circle,
                    points: circlePts,
                    isClosed: true,
                    strokeColor: strokeColor,
                    fillColor: KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.14)
                )
            }

            let simplified = simplifyPointsRDP(rawPoints, epsilon: diag * 0.065)
            if simplified.count >= 4 && simplified.count <= 6 {
                let rectPts = [
                    KroutonNormalizedPoint(nx: minX, ny: minY),
                    KroutonNormalizedPoint(nx: maxX, ny: minY),
                    KroutonNormalizedPoint(nx: maxX, ny: maxY),
                    KroutonNormalizedPoint(nx: minX, ny: maxY)
                ]
                return KroutonVectorShapeLayer(
                    name: "Snapped Rectangle",
                    kind: .rectangle,
                    points: rectPts,
                    isClosed: true,
                    strokeColor: strokeColor,
                    fillColor: KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.14)
                )
            }

            return KroutonVectorShapeLayer(
                name: "Vector Polygon (\(simplified.count) pts)",
                kind: .polygon,
                points: simplified,
                isClosed: true,
                strokeColor: strokeColor,
                fillColor: KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.12)
            )
        }

        let smoothed = simplifyPointsRDP(rawPoints, epsilon: max(0.008, diag * 0.025))
        return KroutonVectorShapeLayer(
            name: "Freehand Vector Curve",
            kind: .smoothBezier,
            points: smoothed,
            isClosed: isClosedStroke,
            strokeColor: strokeColor
        )
    }

    public static func makeParametricVectorShape(
        kind: KroutonVectorShapeKind,
        centerX: Double = 0.0,
        centerY: Double = -0.45,
        radius: Double = 0.16,
        strokeColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.98, g: 0.78, b: 0.18, a: 1.0)
    ) -> KroutonVectorShapeLayer {
        switch kind {
        case .star:
            var pts: [KroutonNormalizedPoint] = []
            for i in 0..<10 {
                let r = (i % 2 == 0) ? radius : (radius * 0.42)
                let ang = (Double(i) * Double.pi / 5.0) - (Double.pi / 2.0)
                pts.append(KroutonNormalizedPoint(nx: centerX + cos(ang) * r, ny: centerY + sin(ang) * r))
            }
            return KroutonVectorShapeLayer(
                name: "Vector Star Crest",
                kind: .star,
                points: pts,
                isClosed: true,
                strokeColor: strokeColor,
                fillColor: KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.22)
            )
        case .concentricRing:
            let pts = (0..<48).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 48.0)
                return KroutonNormalizedPoint(nx: cos(ang) * 0.62, ny: sin(ang) * 0.62)
            }
            return KroutonVectorShapeLayer(
                name: "Concentric Accent Ring",
                kind: .concentricRing,
                points: pts,
                strokeWidthPoints: 1.8,
                isClosed: true,
                strokeColor: strokeColor
            )
        default:
            let pts = (0..<6).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 6.0) - (Double.pi / 2.0)
                return KroutonNormalizedPoint(nx: centerX + cos(ang) * radius, ny: centerY + sin(ang) * radius)
            }
            return KroutonVectorShapeLayer(
                name: "Hexagon Emblem",
                kind: .polygon,
                points: pts,
                isClosed: true,
                strokeColor: strokeColor,
                fillColor: KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.16)
            )
        }
    }

    public static func traceImageContoursWithVision(
        cgImage: CGImage,
        contrastAdjustment: Float = 2.0,
        epsilon: Float = 0.012,
        strokeColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.35, g: 0.92, b: 1.0, a: 1.0)
    ) -> [KroutonVectorShapeLayer] {
        let req = VNDetectContoursRequest()
        req.contrastAdjustment = contrastAdjustment
        req.detectsDarkOnLight = true
        req.maximumImageDimension = 512

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([req])) != nil,
              let obs = req.results?.first as? VNContoursObservation else {
            return []
        }

        var layers: [KroutonVectorShapeLayer] = []
        for idx in 0..<min(12, obs.topLevelContourCount) {
            guard let contour = try? obs.topLevelContours[idx].polygonApproximation(epsilon: epsilon) else { continue }
            let rawPts = contour.normalizedPoints
            guard rawPts.count >= 3 else { continue }
            let mapped = rawPts.map { pt in
                KroutonNormalizedPoint(
                    nx: (Double(pt.x) - 0.5) * 1.35,
                    ny: (0.5 - Double(pt.y)) * 1.35
                )
            }
            layers.append(
                KroutonVectorShapeLayer(
                    name: "Vision Contour #\(idx + 1)",
                    kind: .visionContour,
                    points: mapped,
                    strokeWidthPoints: 1.8,
                    isClosed: true,
                    strokeColor: strokeColor
                )
            )
        }
        return layers
    }

    public static func simplifyPointsRDP(_ points: [KroutonNormalizedPoint], epsilon: Double) -> [KroutonNormalizedPoint] {
        guard points.count > 2 else { return points }
        var maxDist = 0.0
        var index = 0
        let first = points.first!
        let last = points.last!

        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(points[i], lineStart: first, lineEnd: last)
            if d > maxDist {
                index = i
                maxDist = d
            }
        }
        if maxDist > epsilon {
            let left = simplifyPointsRDP(Array(points[0...index]), epsilon: epsilon)
            let right = simplifyPointsRDP(Array(points[index..<points.count]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    private static func perpendicularDistance(_ pt: KroutonNormalizedPoint, lineStart: KroutonNormalizedPoint, lineEnd: KroutonNormalizedPoint) -> Double {
        let dx = lineEnd.nx - lineStart.nx
        let dy = lineEnd.ny - lineStart.ny
        let mag = hypot(dx, dy)
        guard mag > 1e-9 else { return hypot(pt.nx - lineStart.nx, pt.ny - lineStart.ny) }
        return abs(dy * pt.nx - dx * pt.ny + lineEnd.nx * lineStart.ny - lineEnd.ny * lineStart.nx) / mag
    }
}
