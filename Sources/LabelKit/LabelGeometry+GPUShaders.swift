import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import OpticalCore
import RescueKit
import Vision

extension KroutonLabelGeometryEngine {
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

    static func simplifyPointsRDP(_ points: [KroutonNormalizedPoint], epsilon: Double) -> [KroutonNormalizedPoint] {
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

    /// `CIContext` is documented as thread-safe but is not annotated `Sendable` in every SDK,
    /// so it is held in a box rather than relying on `nonisolated(unsafe)` (which warns on newer SDKs).
    private struct SendableCIContext: @unchecked Sendable {
        let context: CIContext
    }

    private static let sharedMetalCIContext = SendableCIContext(context:
        CIContext(options: [.useSoftwareRenderer: false, .workingColorSpace: KroutonLabelGeometryEngine.sRGBColorSpace, .outputColorSpace: KroutonLabelGeometryEngine.sRGBColorSpace])
    )

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

        return sharedMetalCIContext.context.createCGImage(outputCI, from: rect)
    }
}
