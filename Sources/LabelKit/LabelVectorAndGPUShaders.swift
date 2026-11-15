import RescueKit
import Foundation
import Vision
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import OpticalCore

extension KroutonKrustiniModule {
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
        centerY: Double = -0.42,
        radius: Double = 0.16,
        strokeColor: KroutonRGBAColor = KroutonRGBAColor(r: 0.98, g: 0.78, b: 0.18, a: 1.0)
    ) -> KroutonVectorShapeLayer {
        let softFill = KroutonRGBAColor(r: strokeColor.r, g: strokeColor.g, b: strokeColor.b, a: 0.20)
        switch kind {
        case .line:
            let pts = [
                KroutonNormalizedPoint(nx: centerX - radius, ny: centerY + radius),
                KroutonNormalizedPoint(nx: centerX + radius, ny: centerY - radius)
            ]
            return KroutonVectorShapeLayer(name: "Vector Line", kind: .line, points: pts, strokeWidthPoints: 2.6, isClosed: false, strokeColor: strokeColor)
        case .curveArc:
            let pts = (0...20).map { i -> KroutonNormalizedPoint in
                let t = Double(i) / 20.0
                let ang = -Double.pi * 0.85 + t * (Double.pi * 0.70)
                return KroutonNormalizedPoint(nx: cos(ang) * 0.54, ny: sin(ang) * 0.54)
            }
            return KroutonVectorShapeLayer(name: "Polar Curve Arc", kind: .curveArc, points: pts, strokeWidthPoints: 2.6, isClosed: false, strokeColor: strokeColor)
        case .circle:
            let pts = (0..<36).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 36.0)
                return KroutonNormalizedPoint(nx: centerX + cos(ang) * radius, ny: centerY + sin(ang) * radius)
            }
            return KroutonVectorShapeLayer(name: "Circle", kind: .circle, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .triangle:
            let pts = (0..<3).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 3.0) - (Double.pi / 2.0)
                return KroutonNormalizedPoint(nx: centerX + cos(ang) * radius, ny: centerY + sin(ang) * radius)
            }
            return KroutonVectorShapeLayer(name: "Triangle", kind: .triangle, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .pentagon:
            let pts = (0..<5).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 5.0) - (Double.pi / 2.0)
                return KroutonNormalizedPoint(nx: centerX + cos(ang) * radius, ny: centerY + sin(ang) * radius)
            }
            return KroutonVectorShapeLayer(name: "Pentagon", kind: .pentagon, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .diamond:
            let pts = [
                KroutonNormalizedPoint(nx: centerX, ny: centerY - radius),
                KroutonNormalizedPoint(nx: centerX + radius * 0.82, ny: centerY),
                KroutonNormalizedPoint(nx: centerX, ny: centerY + radius),
                KroutonNormalizedPoint(nx: centerX - radius * 0.82, ny: centerY)
            ]
            return KroutonVectorShapeLayer(name: "Diamond", kind: .diamond, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .rectangle, .roundedRect:
            let r = radius * 0.82
            let pts = [
                KroutonNormalizedPoint(nx: centerX - r, ny: centerY - r),
                KroutonNormalizedPoint(nx: centerX + r, ny: centerY - r),
                KroutonNormalizedPoint(nx: centerX + r, ny: centerY + r),
                KroutonNormalizedPoint(nx: centerX - r, ny: centerY + r)
            ]
            return KroutonVectorShapeLayer(name: kind == .roundedRect ? "Rounded Square" : "Square", kind: kind, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .capsule:
            var pts: [KroutonNormalizedPoint] = []
            let w = radius * 0.95, h = radius * 0.48
            for i in 0...12 {
                let ang = -Double.pi / 2.0 + Double(i) * (Double.pi / 12.0)
                pts.append(KroutonNormalizedPoint(nx: centerX + w * 0.5 + cos(ang) * h, ny: centerY + sin(ang) * h))
            }
            for i in 0...12 {
                let ang = Double.pi / 2.0 + Double(i) * (Double.pi / 12.0)
                pts.append(KroutonNormalizedPoint(nx: centerX - w * 0.5 + cos(ang) * h, ny: centerY + sin(ang) * h))
            }
            return KroutonVectorShapeLayer(name: "Capsule Badge", kind: .capsule, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .parallelogram:
            let w = radius * 0.95, h = radius * 0.62, skew = radius * 0.32
            let pts = [
                KroutonNormalizedPoint(nx: centerX - w + skew, ny: centerY - h),
                KroutonNormalizedPoint(nx: centerX + w + skew, ny: centerY - h),
                KroutonNormalizedPoint(nx: centerX + w - skew, ny: centerY + h),
                KroutonNormalizedPoint(nx: centerX - w - skew, ny: centerY + h)
            ]
            return KroutonVectorShapeLayer(name: "Parallelogram", kind: .parallelogram, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .arrow:
            let r = radius
            let pts = [
                KroutonNormalizedPoint(nx: centerX - r, ny: centerY - r * 0.35),
                KroutonNormalizedPoint(nx: centerX + r * 0.15, ny: centerY - r * 0.35),
                KroutonNormalizedPoint(nx: centerX + r * 0.15, ny: centerY - r * 0.80),
                KroutonNormalizedPoint(nx: centerX + r, ny: centerY),
                KroutonNormalizedPoint(nx: centerX + r * 0.15, ny: centerY + r * 0.80),
                KroutonNormalizedPoint(nx: centerX + r * 0.15, ny: centerY + r * 0.35),
                KroutonNormalizedPoint(nx: centerX - r, ny: centerY + r * 0.35)
            ]
            return KroutonVectorShapeLayer(name: "Arrow", kind: .arrow, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .star:
            var pts: [KroutonNormalizedPoint] = []
            for i in 0..<10 {
                let r = (i % 2 == 0) ? radius : (radius * 0.42)
                let ang = (Double(i) * Double.pi / 5.0) - (Double.pi / 2.0)
                pts.append(KroutonNormalizedPoint(nx: centerX + cos(ang) * r, ny: centerY + sin(ang) * r))
            }
            return KroutonVectorShapeLayer(name: "5-Point Star", kind: .star, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        case .concentricRing:
            let pts = (0..<48).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 48.0)
                return KroutonNormalizedPoint(nx: cos(ang) * 0.62, ny: sin(ang) * 0.62)
            }
            return KroutonVectorShapeLayer(name: "Concentric Ring", kind: .concentricRing, points: pts, strokeWidthPoints: 2.0, isClosed: true, strokeColor: strokeColor)
        default:
            let pts = (0..<6).map { i -> KroutonNormalizedPoint in
                let ang = Double(i) * (2.0 * Double.pi / 6.0) - (Double.pi / 2.0)
                return KroutonNormalizedPoint(nx: centerX + cos(ang) * radius, ny: centerY + sin(ang) * radius)
            }
            return KroutonVectorShapeLayer(name: "Hexagon", kind: .polygon, points: pts, isClosed: true, strokeColor: strokeColor, fillColor: softFill)
        }
    }

    /// Scales, rotates, or flips a KroutonVectorShapeLayer around its local centroid (Apple Pages Arrange tab)
    public static func transformVectorShape(
        _ shape: KroutonVectorShapeLayer,
        scaleFactor: Double = 1.0,
        rotateDegrees: Double = 0.0,
        translateX: Double = 0.0,
        translateY: Double = 0.0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false
    ) -> KroutonVectorShapeLayer {
        guard !shape.points.isEmpty else { return shape }
        let cx = shape.points.map(\.nx).reduce(0.0, +) / Double(shape.points.count)
        let cy = shape.points.map(\.ny).reduce(0.0, +) / Double(shape.points.count)
        let rad = rotateDegrees * Double.pi / 180.0
        let cosT = cos(rad), sinT = sin(rad)
        let sx = (flipHorizontal ? -1.0 : 1.0) * scaleFactor
        let sy = (flipVertical ? -1.0 : 1.0) * scaleFactor

        var copy = shape
        copy.points = shape.points.map { pt in
            let dx = (pt.nx - cx) * sx
            let dy = (pt.ny - cy) * sy
            let rx = dx * cosT - dy * sinT
            let ry = dx * sinT + dy * cosT
            return KroutonNormalizedPoint(
                nx: max(-0.98, min(0.98, cx + rx + translateX)),
                ny: max(-0.98, min(0.98, cy + ry + translateY))
            )
        }
        return copy
    }

    /// Returns the ID of the vector shape closest to (normalizedX, normalizedY) in [-1, 1] disc coordinates.
    public static func nearestVectorShapeID(
        in shapes: [KroutonVectorShapeLayer],
        normalizedX nx: Double,
        normalizedY ny: Double
    ) -> UUID? {
        guard !shapes.isEmpty else { return nil }
        return shapes.min { a, b in
            shapeHitDistance(a, nx: nx, ny: ny) < shapeHitDistance(b, nx: nx, ny: ny)
        }?.id
    }

    private static func shapeHitDistance(_ shape: KroutonVectorShapeLayer, nx: Double, ny: Double) -> Double {
        guard !shape.points.isEmpty else { return 999.0 }
        let cx = shape.points.map(\.nx).reduce(0.0, +) / Double(shape.points.count)
        let cy = shape.points.map(\.ny).reduce(0.0, +) / Double(shape.points.count)
        let centroidDist = hypot(cx - nx, cy - ny)
        let vertexDist = shape.points.map { hypot($0.nx - nx, $0.ny - ny) }.min() ?? centroidDist
        return min(centroidDist, vertexDist)
    }

    /// Translates a vector shape so its centroid moves to (toNormalizedX, normalizedY) while staying within the disc rim.
    public static func recenterVectorShape(
        _ shape: KroutonVectorShapeLayer,
        toNormalizedX targetNX: Double,
        normalizedY targetNY: Double
    ) -> KroutonVectorShapeLayer {
        guard !shape.points.isEmpty else { return shape }
        let cx = shape.points.map(\.nx).reduce(0.0, +) / Double(shape.points.count)
        let cy = shape.points.map(\.ny).reduce(0.0, +) / Double(shape.points.count)
        let clampedX = max(-0.88, min(0.88, targetNX))
        let clampedY = max(-0.88, min(0.88, targetNY))
        return transformVectorShape(shape, translateX: clampedX - cx, translateY: clampedY - cy)
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

    // MARK: - Apple Silicon Metal GPU Kaleidoscope, 360° Tiny Planet Globe & Vision Foreground Lifter

    private static let sharedMetalCIContext: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false, .workingColorSpace: KroutonKrustiniModule.sRGBColorSpace, .outputColorSpace: KroutonKrustiniModule.sRGBColorSpace])
    }()

    /// Replicates a drawn vector shape N times radially around the (0,0) spindle center
    public static func replicateShapeWithPolarSymmetry(
        baseShape: KroutonVectorShapeLayer,
        symmetryCount: Int
    ) -> [KroutonVectorShapeLayer] {
        let count = max(1, min(16, symmetryCount))
        guard count > 1 else { return [baseShape] }
        var results: [KroutonVectorShapeLayer] = []
        for idx in 0..<count {
            let theta = Double(idx) * (2.0 * Double.pi / Double(count))
            let cosT = cos(theta)
            let sinT = sin(theta)
            let rotatedPts = baseShape.points.map { pt in
                KroutonNormalizedPoint(
                    nx: pt.nx * cosT - pt.ny * sinT,
                    ny: pt.nx * sinT + pt.ny * cosT
                )
            }
            var copy = baseShape
            copy.id = UUID()
            copy.name = "\(baseShape.name) [Sym \(idx + 1)/\(count)]"
            copy.points = rotatedPts
            results.append(copy)
        }
        return results
    }

    /// Generates a smooth, tasteful workspace seed CIImage (no harsh checkerboard or blinding white starshine)
    public static func makeGPUSeedCIImage(
        pattern: KroutonGPUSeedPattern,
        primaryColor: KroutonRGBAColor,
        secondaryColor: KroutonRGBAColor,
        dimension: CGFloat = 420.0
    ) -> CIImage {
        let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
        let c1 = CIColor(red: primaryColor.r, green: primaryColor.g, blue: primaryColor.b, alpha: 1.0)
        let c2 = CIColor(red: secondaryColor.r, green: secondaryColor.g, blue: secondaryColor.b, alpha: 1.0)
        let darkCore = CIColor(red: primaryColor.r * 0.28, green: primaryColor.g * 0.28, blue: primaryColor.b * 0.32, alpha: 1.0)

        let linear = CIFilter.linearGradient()
        linear.point0 = CGPoint(x: 0, y: 0)
        linear.point1 = CGPoint(x: dimension, y: dimension)
        linear.color0 = c1
        linear.color1 = c2
        var base = (linear.outputImage ?? CIImage(color: c1)).cropped(to: rect)

        switch pattern {
        case .neonLaserPrism:
            // Smooth multi-stop radial + diagonal silk waves (zero harsh checkerboards!)
            let rad1 = CIFilter.radialGradient()
            rad1.center = CGPoint(x: dimension * 0.32, y: dimension * 0.68)
            rad1.radius0 = Float(dimension * 0.04)
            rad1.radius1 = Float(dimension * 0.48)
            rad1.color0 = c2
            rad1.color1 = CIColor(red: c1.red, green: c1.green, blue: c1.blue, alpha: 0.0)
            if let rOut = rad1.outputImage?.cropped(to: rect) {
                base = rOut.composited(over: base)
            }
            let rad2 = CIFilter.radialGradient()
            rad2.center = CGPoint(x: dimension * 0.68, y: dimension * 0.34)
            rad2.radius0 = Float(dimension * 0.02)
            rad2.radius1 = Float(dimension * 0.36)
            rad2.color0 = darkCore
            rad2.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            if let r2Out = rad2.outputImage?.cropped(to: rect) {
                base = r2Out.composited(over: base)
            }
        case .cyberSunburst:
            let stripes = CIFilter.stripesGenerator()
            stripes.center = CGPoint(x: dimension * 0.5, y: dimension * 0.5)
            stripes.color0 = c1
            stripes.color1 = c2
            stripes.width = Float(dimension * 0.045)
            stripes.sharpness = 0.35
            if let st = stripes.outputImage?.cropped(to: rect) {
                base = st
            }
        case .holographicFoil:
            let halo = CIFilter.lenticularHaloGenerator()
            halo.center = CGPoint(x: dimension * 0.5, y: dimension * 0.5)
            halo.color = c2
            halo.haloRadius = Float(dimension * 0.24)
            halo.haloWidth = Float(dimension * 0.14)
            halo.striationStrength = 0.65
            halo.striationContrast = 0.85
            if let hOut = halo.outputImage?.cropped(to: rect) {
                base = hOut.composited(over: base)
            }
        case .cmykHalftone:
            let dot = CIFilter.dotScreen()
            dot.inputImage = base
            dot.center = CGPoint(x: dimension * 0.5, y: dimension * 0.5)
            dot.width = 8.0
            dot.sharpness = 0.55
            if let dOut = dot.outputImage?.cropped(to: rect) {
                base = dOut.composited(over: base)
            }
        }
        return base.cropped(to: rect)
    }

    /// Executes Apple Silicon Metal GPU Kaleidoscope or a True 360° Tiny Planet Globe
    public static func renderGPUKaleidoscopeOrTinyPlanetCGImage(
        style: KroutonVectorBackgroundStyle,
        seedPattern: KroutonGPUSeedPattern,
        primaryColor: KroutonRGBAColor,
        secondaryColor: KroutonRGBAColor,
        angleDegrees: Double,
        facetCount: Int = 8,
        planetRadiusRatio: Double = 0.72,
        dimensionPixels: Int = 420
    ) -> CGImage? {
        let dim = CGFloat(max(64, min(1024, dimensionPixels)))
        let rect = CGRect(x: 0, y: 0, width: dim, height: dim)
        let center = CGPoint(x: dim * 0.5, y: dim * 0.5)
        let angleRad = Float(angleDegrees * Double.pi / 180.0)

        let seed = makeGPUSeedCIImage(
            pattern: seedPattern,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            dimension: dim
        )

        var outputCI: CIImage = seed

        if style == .gpuKaleidoscope {
            let kal = CIFilter.kaleidoscope()
            kal.inputImage = seed.clampedToExtent()
            kal.count = max(2, min(24, facetCount))
            kal.center = center
            kal.angle = angleRad
            if let kOut = kal.outputImage?.cropped(to: rect) {
                outputCI = kOut
            }
        } else if style == .tinyPlanetGlobe {
            // Build a true 360° Tiny Planet Globe:
            // Inner planet core + equatorial horizon ring + outer space atmosphere
            let planetR = Float(dim * 0.44 * max(0.30, min(0.95, planetRadiusRatio)))
            let c2 = CIColor(red: secondaryColor.r, green: secondaryColor.g, blue: secondaryColor.b, alpha: 1.0)
            let deepSpace = CIColor(red: primaryColor.r * 0.15, green: primaryColor.g * 0.16, blue: primaryColor.b * 0.22, alpha: 1.0)

            let globeGrad = CIFilter.radialGradient()
            globeGrad.center = center
            globeGrad.radius0 = planetR * 0.55
            globeGrad.radius1 = planetR * 1.18
            globeGrad.color0 = c2
            globeGrad.color1 = deepSpace

            let wrap = CIFilter.circularWrap()
            wrap.inputImage = seed.clampedToExtent()
            wrap.center = center
            wrap.radius = planetR * 0.75
            wrap.angle = angleRad

            if let wrapped = wrap.outputImage?.cropped(to: rect),
               let atmosphere = globeGrad.outputImage?.cropped(to: rect) {
                let blend = CIFilter.softLightBlendMode()
                blend.inputImage = wrapped
                blend.backgroundImage = atmosphere
                outputCI = (blend.outputImage ?? atmosphere).cropped(to: rect)
            }
        }

        return sharedMetalCIContext.createCGImage(outputCI, from: rect)
    }
}
