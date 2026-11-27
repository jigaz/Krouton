import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import OpticalCore
import RescueKit
import os

// MARK: - Stylized Procedural Optical Chamber & CoreImage Kaleidoscope Engine

extension KroutonLabelGeometryEngine {

    internal static let sRGBColorSpace: CGColorSpace = {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }()

    /// `CIContext` is not `Sendable` in the macOS 26 SDK: held behind a lock, as in GPUShaders.
    private static let opticalGPUContext = OSAllocatedUnfairLock(uncheckedState:
        CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true,
            .workingColorSpace: sRGBColorSpace,
            .outputColorSpace: sRGBColorSpace
        ])
    )

    private struct OpticalRenderCacheKey: Equatable {
        let style: KroutonVectorBackgroundStyle
        let seedPattern: KroutonGPUSeedPattern
        let mirrorRig: KroutonKaleidoscopeMirrorRig
        let chamberTumbleQuantized: Int
        let backdropLightnessQuantized: Int
        let primaryRGBA: [Int]
        let secondaryRGBA: [Int]
        let angleQuantized: Int
        let facetCount: Int
        let adjustments: KroutonBackgroundAdjustments
        let dimensionPixels: Int
    }

    private static let maxCacheEntries = 4
    private static let renderCacheLock = OSAllocatedUnfairLock<[(key: OpticalRenderCacheKey, image: CGImage)]>(initialState: [])

    /// Renders stylized procedural chambers (or adjusted vector gradients) with O(1) memoization
    /// so 60Hz foreground text dragging never triggers redundant main-thread GPU->CPU readbacks.
    public static func renderOpticalPlaygroundCGImage(
        style: KroutonVectorBackgroundStyle,
        seedPattern: KroutonGPUSeedPattern,
        mirrorRig: KroutonKaleidoscopeMirrorRig,
        chamberTumble: Double,
        backdropLightness: Double = 0.85,
        primaryColor: KroutonRGBAColor,
        secondaryColor: KroutonRGBAColor,
        angleDegrees: Double,
        facetCount: Int = 8,
        bgAdjustments: KroutonBackgroundAdjustments = KroutonBackgroundAdjustments(),
        dimensionPixels: Int = 460
    ) -> CGImage? {
        let dimInt = max(64, min(1440, dimensionPixels))
        let key = OpticalRenderCacheKey(
            style: style,
            seedPattern: seedPattern,
            mirrorRig: mirrorRig,
            chamberTumbleQuantized: Int((chamberTumble * 1000.0).rounded()),
            backdropLightnessQuantized: Int((backdropLightness * 1000.0).rounded()),
            primaryRGBA: [Int(primaryColor.r * 255), Int(primaryColor.g * 255), Int(primaryColor.b * 255)],
            secondaryRGBA: [Int(secondaryColor.r * 255), Int(secondaryColor.g * 255), Int(secondaryColor.b * 255)],
            angleQuantized: Int((angleDegrees * 10.0).rounded()),
            facetCount: facetCount,
            adjustments: bgAdjustments,
            dimensionPixels: dimInt
        )

        if let hit = renderCacheLock.withLock({ ring in ring.first(where: { $0.key == key })?.image }) {
            return hit
        }

        let dim = CGFloat(dimInt)
        let rect = CGRect(x: 0, y: 0, width: dim, height: dim)
        let center = CGPoint(x: dim * 0.5, y: dim * 0.5)
        let angleRad = Float(angleDegrees * Double.pi / 180.0)

        let baseCI: CIImage
        switch style {
        case .templateDefault, .solidColor, .radialGradient, .linearGradient, .angularGradient, .tinyPlanetGlobe:
            baseCI = makeSimpleVectorGradientCIImage(
                style: style,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                midpoint: backdropLightness,
                angleDegrees: angleDegrees,
                dimension: dim
            )
        case .gpuKaleidoscope:
            let chamberCI = makePhysicalObjectChamberCIImage(
                pattern: seedPattern,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                chamberTumble: chamberTumble,
                backdropLightness: backdropLightness,
                dimension: dim
            )
            baseCI = applyKaleidoscopeMirrorRig(
                chamberCI: chamberCI,
                mirrorRig: mirrorRig,
                chamberTumble: chamberTumble,
                facetCount: facetCount,
                angleRad: angleRad,
                center: center,
                rect: rect
            )
        }

        let adjustedCI = applyApplePhotosAdjustments(to: baseCI, adjustments: bgAdjustments, extentRect: rect)
        guard let cgOut = opticalGPUContext.withLockUnchecked({ $0.createCGImage(adjustedCI, from: rect) }) else {
            return nil
        }

        renderCacheLock.withLock { ring in
            ring.removeAll(where: { $0.key == key })
            ring.append((key: key, image: cgOut))
            if ring.count > maxCacheEntries {
                ring.removeFirst()
            }
        }
        return cgOut
    }

    // MARK: - Stylized Procedural Object Chamber Dispatcher

    static func makePhysicalObjectChamberCIImage(
        pattern: KroutonGPUSeedPattern,
        primaryColor: KroutonRGBAColor,
        secondaryColor: KroutonRGBAColor,
        chamberTumble: Double,
        backdropLightness: Double = 0.85,
        dimension: CGFloat = 480.0
    ) -> CIImage {
        let dim = Int(max(128, min(1440, dimension)))
        let w = CGFloat(dim), h = CGFloat(dim)
        guard let ctx = CGContext(
            data: nil, width: dim, height: dim, bitsPerComponent: 8, bytesPerRow: dim * 4,
            space: sRGBColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CIImage(color: CIColor(red: primaryColor.r, green: primaryColor.g, blue: primaryColor.b))
                .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        }

        let r1 = CGFloat(primaryColor.r), g1 = CGFloat(primaryColor.g), b1 = CGFloat(primaryColor.b)
        let r2 = CGFloat(secondaryColor.r), g2 = CGFloat(secondaryColor.g), b2 = CGFloat(secondaryColor.b)
        let tumblePhase = CGFloat(chamberTumble) * .pi * 2.0

        drawInkSavingChamberBackdrop(ctx: ctx, w: w, h: h, r1: r1, g1: g1, b1: b1, r2: r2, g2: g2, b2: b2, backdropLightness: backdropLightness)

        let gemPalette: [(CGFloat, CGFloat, CGFloat)] = [
            (r1, g1, b1), (r2, g2, b2),
            (0.92, 0.12, 0.30), (0.08, 0.82, 0.52),
            (0.14, 0.48, 0.98), (0.98, 0.74, 0.14),
            (0.72, 0.24, 0.96), (0.15, 0.94, 0.92)
        ]

        switch pattern {
        case .neonLaserPrism:
            drawFacetedGemShardsChamber(ctx: ctx, w: w, h: h, tumblePhase: tumblePhase, palette: gemPalette)
        case .cyberSunburst:
            drawDichroicRibbonsChamber(ctx: ctx, w: w, h: h, tumblePhase: tumblePhase, palette: gemPalette)
        case .holographicFoil:
            drawLiquidInterferenceChamber(ctx: ctx, w: w, h: h, tumblePhase: tumblePhase, palette: gemPalette)
        case .cmykHalftone:
            drawPhyllotaxisLotusChamber(ctx: ctx, w: w, h: h, tumblePhase: tumblePhase, palette: gemPalette)
        }

        guard let cgImg = ctx.makeImage() else {
            return CIImage(color: CIColor(red: r1, green: g1, blue: b1)).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var ciOut = CIImage(cgImage: cgImg)
        let extentRect = CGRect(x: 0, y: 0, width: w, height: h)

        if pattern == .holographicFoil {
            let twirl = CIFilter.twirlDistortion()
            twirl.inputImage = ciOut.clampedToExtent()
            twirl.center = CGPoint(x: w * 0.46, y: h * 0.54)
            twirl.radius = Float(w * 0.44)
            twirl.angle = Float(3.4 + sin(Double(tumblePhase)) * 1.9)
            if let swirled = twirl.outputImage?.cropped(to: extentRect) {
                ciOut = swirled
            }
        }

        let bloom = CIFilter.bloom()
        bloom.inputImage = ciOut.clampedToExtent()
        bloom.radius = Float(w * 0.012)
        bloom.intensity = Float(0.22 * (1.0 - backdropLightness * 0.5))
        if let bloomed = bloom.outputImage?.cropped(to: extentRect) {
            ciOut = bloomed
        }
        return ciOut
    }

    // MARK: - 4 Dedicated Per-Pattern Chamber Renderers

    private static func drawInkSavingChamberBackdrop(
        ctx: CGContext, w: CGFloat, h: CGFloat,
        r1: CGFloat, g1: CGFloat, b1: CGFloat,
        r2: CGFloat, g2: CGFloat, b2: CGFloat,
        backdropLightness: Double
    ) {
        let lift = CGFloat(max(0.0, min(1.0, backdropLightness)))
        let bgR1 = r1 * (1.0 - lift * 0.65) + lift * 0.65
        let bgG1 = g1 * (1.0 - lift * 0.65) + lift * 0.65
        let bgB1 = b1 * (1.0 - lift * 0.65) + lift * 0.65
        let bgR2 = (r2 * 0.65 + r1 * 0.35) * (1.0 - lift * 0.82) + lift * 0.82
        let bgG2 = (g2 * 0.65 + g1 * 0.35) * (1.0 - lift * 0.82) + lift * 0.82
        let bgB2 = (b2 * 0.65 + b1 * 0.35) * (1.0 - lift * 0.82) + lift * 0.82

        let bgColors = [
            CGColor(colorSpace: sRGBColorSpace, components: [bgR1, bgG1, bgB1, 1.0])!,
            CGColor(colorSpace: sRGBColorSpace, components: [bgR2, bgG2, bgB2, 1.0])!
        ] as CFArray
        if let grad = CGGradient(colorsSpace: sRGBColorSpace, colors: bgColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: w * 0.45, y: h * 0.55), startRadius: w * 0.05,
                endCenter: CGPoint(x: w * 0.5, y: h * 0.5), endRadius: w * 0.72,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    private static func drawFacetedGemShardsChamber(
        ctx: CGContext, w: CGFloat, h: CGFloat,
        tumblePhase: CGFloat, palette: [(CGFloat, CGFloat, CGFloat)]
    ) {
        for i in 0..<26 {
            let fi = CGFloat(i)
            let seedA = fi * 1.6180339 + tumblePhase * (0.55 + (fi.truncatingRemainder(dividingBy: 3.0)) * 0.22)
            let seedB = fi * 2.4142135 - tumblePhase * 0.75
            let cx = w * (0.50 + 0.36 * cos(seedA))
            let cy = h * (0.50 + 0.36 * sin(seedB))
            let gemR = w * (0.055 + 0.095 * abs(sin(fi * 0.83)))
            let baseCol = palette[i % palette.count]

            if i % 4 == 0 {
                drawStylizedCabochonSphere(ctx: ctx, center: CGPoint(x: cx, y: cy), radius: gemR * 0.92, color: baseCol)
            } else {
                let symmetry = (i % 3 == 0) ? 8 : ((i % 2 == 0) ? 6 : 10)
                drawStylizedFacetedGemstone(ctx: ctx, center: CGPoint(x: cx, y: cy), radius: gemR, rotation: seedA * 1.15, facets: symmetry, color: baseCol)
            }
        }
    }

    private static func drawDichroicRibbonsChamber(
        ctx: CGContext, w: CGFloat, h: CGFloat,
        tumblePhase: CGFloat, palette: [(CGFloat, CGFloat, CGFloat)]
    ) {
        ctx.setBlendMode(.normal)
        for i in 0..<22 {
            let fi = CGFloat(i)
            let col = palette[i % palette.count]
            let phase = tumblePhase + fi * 0.48
            let startPt = CGPoint(x: w * (0.08 + 0.84 * abs(sin(fi * 0.43))), y: 0)
            let endPt = CGPoint(x: w * (0.92 - 0.84 * abs(cos(fi * 0.39))), y: h)
            let ctrl1 = CGPoint(x: w * (0.5 + 0.44 * cos(phase)), y: h * (0.32 + 0.32 * sin(phase)))
            let ctrl2 = CGPoint(x: w * (0.5 - 0.44 * sin(phase)), y: h * (0.68 + 0.28 * cos(phase)))

            ctx.beginPath()
            ctx.move(to: startPt); ctx.addCurve(to: endPt, control1: ctrl1, control2: ctrl2)
            ctx.setStrokeColor(CGColor(colorSpace: sRGBColorSpace, components: [col.0, col.1, col.2, 0.38])!)
            ctx.setLineWidth(w * 0.042); ctx.setLineCap(.round); ctx.strokePath()

            ctx.beginPath()
            ctx.move(to: startPt); ctx.addCurve(to: endPt, control1: ctrl1, control2: ctrl2)
            ctx.setStrokeColor(CGColor(colorSpace: sRGBColorSpace, components: [col.0, col.1, col.2, 0.88])!)
            ctx.setLineWidth(w * 0.015); ctx.strokePath()

            ctx.beginPath()
            ctx.move(to: startPt); ctx.addCurve(to: endPt, control1: ctrl1, control2: ctrl2)
            ctx.setStrokeColor(CGColor(colorSpace: sRGBColorSpace, components: [1.0, 1.0, 1.0, 0.92])!)
            ctx.setLineWidth(w * 0.004); ctx.strokePath()
        }
    }

    private static func drawLiquidInterferenceChamber(
        ctx: CGContext, w: CGFloat, h: CGFloat,
        tumblePhase: CGFloat, palette: [(CGFloat, CGFloat, CGFloat)]
    ) {
        for i in 0..<24 {
            let fi = CGFloat(i)
            let col = palette[i % palette.count]
            let nextCol = palette[(i + 1) % palette.count]
            let ang = fi * 0.92 + tumblePhase
            let cx = w * (0.50 + 0.34 * cos(ang * 0.75))
            let cy = h * (0.50 + 0.34 * sin(ang * 1.15))
            let rad = w * (0.34 - fi * 0.011)
            let colors = [
                CGColor(colorSpace: sRGBColorSpace, components: [1.0, 1.0, 1.0, 0.85])!,
                CGColor(colorSpace: sRGBColorSpace, components: [col.0, col.1, col.2, 0.85])!,
                CGColor(colorSpace: sRGBColorSpace, components: [nextCol.0 * 0.3, nextCol.1 * 0.3, nextCol.2 * 0.4, 0.92])!
            ] as CFArray
            if let g = CGGradient(colorsSpace: sRGBColorSpace, colors: colors, locations: [0.0, 0.45, 1.0]) {
                ctx.drawRadialGradient(
                    g,
                    startCenter: CGPoint(x: cx - rad * 0.25, y: cy - rad * 0.25), startRadius: rad * 0.04,
                    endCenter: CGPoint(x: cx, y: cy), endRadius: rad, options: []
                )
            }
        }
    }

    private static func drawPhyllotaxisLotusChamber(
        ctx: CGContext, w: CGFloat, h: CGFloat,
        tumblePhase: CGFloat, palette: [(CGFloat, CGFloat, CGFloat)]
    ) {
        let goldenAngle: CGFloat = 2.39996322972865332
        for i in 1..<40 {
            let fi = CGFloat(i)
            let theta = fi * goldenAngle + tumblePhase
            let r = w * 0.060 * sqrt(fi)
            let cx = w * 0.52 + cos(theta) * r
            let cy = h * 0.48 + sin(theta) * r
            let gemR = w * (0.042 + fi * 0.0016)
            let col = palette[i % palette.count]
            drawStylizedFacetedGemstone(ctx: ctx, center: CGPoint(x: cx, y: cy), radius: gemR, rotation: theta, facets: 6, color: col)
        }
    }

    // MARK: - Stylized Faceted Gemstone & Cabochon Primitives

    private static func drawStylizedFacetedGemstone(
        ctx: CGContext, center: CGPoint, radius: CGFloat,
        rotation: CGFloat, facets: Int, color: (CGFloat, CGFloat, CGFloat)
    ) {
        let n = max(5, facets)
        let tableR = radius * 0.54
        ctx.saveGState()
        ctx.beginPath()
        for i in 0..<n {
            let ang = rotation + CGFloat(i) * (.pi * 2.0 / CGFloat(n))
            let pt = CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius)
            if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
        }
        ctx.closePath()
        ctx.setFillColor(CGColor(colorSpace: sRGBColorSpace, components: [color.0 * 0.55, color.1 * 0.55, color.2 * 0.60, 0.94])!)
        ctx.fillPath()

        ctx.beginPath()
        for i in 0..<n {
            let ang = rotation + CGFloat(i) * (.pi * 2.0 / CGFloat(n))
            ctx.move(to: CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius))
            ctx.addLine(to: CGPoint(x: center.x + cos(ang) * tableR, y: center.y + sin(ang) * tableR))
        }
        ctx.setStrokeColor(CGColor(colorSpace: sRGBColorSpace, components: [1.0, 1.0, 1.0, 0.45])!)
        ctx.setLineWidth(1.0)
        ctx.strokePath()
        drawStylizedCabochonSphere(ctx: ctx, center: center, radius: tableR, color: color)
        ctx.restoreGState()
    }

    private static func drawStylizedCabochonSphere(
        ctx: CGContext, center: CGPoint, radius: CGFloat, color: (CGFloat, CGFloat, CGFloat)
    ) {
        let colors = [
            CGColor(colorSpace: sRGBColorSpace, components: [min(1.0, color.0 + 0.48), min(1.0, color.1 + 0.48), min(1.0, color.2 + 0.48), 0.96])!,
            CGColor(colorSpace: sRGBColorSpace, components: [color.0, color.1, color.2, 0.92])!,
            CGColor(colorSpace: sRGBColorSpace, components: [color.0 * 0.18, color.1 * 0.18, color.2 * 0.24, 0.98])!
        ] as CFArray
        if let grad = CGGradient(colorsSpace: sRGBColorSpace, colors: colors, locations: [0.0, 0.50, 1.0]) {
            ctx.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.28),
                startRadius: radius * 0.04, endCenter: center, endRadius: radius, options: []
            )
        }
    }

    // MARK: - CoreImage Kaleidoscope Filter Stage

    private static func applyKaleidoscopeMirrorRig(
        chamberCI: CIImage, mirrorRig: KroutonKaleidoscopeMirrorRig,
        chamberTumble: Double, facetCount: Int, angleRad: Float,
        center: CGPoint, rect: CGRect
    ) -> CIImage {
        let dim = rect.width
        let shiftX = CGFloat(cos(chamberTumble * Double.pi * 2.0)) * (dim * 0.16)
        let shiftY = CGFloat(sin(chamberTumble * Double.pi * 2.0)) * (dim * 0.16)
        let shiftedSeed = chamberCI.clampedToExtent().transformed(by: CGAffineTransform(translationX: shiftX, y: shiftY))

        switch mirrorRig {
        case .twoMirrorRosette:
            let kal = CIFilter.kaleidoscope()
            kal.inputImage = shiftedSeed
            kal.count = max(3, min(24, facetCount))
            kal.center = center
            kal.angle = angleRad
            return kal.outputImage?.cropped(to: rect) ?? chamberCI
        case .threeMirrorPrism:
            let tri = CIFilter.triangleKaleidoscope()
            tri.inputImage = shiftedSeed
            tri.point = center
            tri.size = Float(dim * (0.40 - Double(min(16, facetCount)) * 0.015))
            tri.rotation = angleRad
            tri.decay = 0.94
            return tri.outputImage?.cropped(to: rect) ?? chamberCI
        case .eightFoldStarTile:
            let tri = CIFilter.triangleKaleidoscope()
            tri.inputImage = shiftedSeed
            tri.point = CGPoint(x: center.x + dim * 0.08, y: center.y - dim * 0.06)
            tri.size = Float(dim * (0.34 - Double(min(16, facetCount)) * 0.011))
            tri.rotation = angleRad
            tri.decay = 0.96
            let lattice = (tri.outputImage ?? shiftedSeed).clampedToExtent()

            let starKal = CIFilter.kaleidoscope()
            starKal.inputImage = lattice
            starKal.count = max(4, min(24, facetCount))
            starKal.center = center
            starKal.angle = angleRad + 0.3926991
            return starKal.outputImage?.cropped(to: rect) ?? chamberCI
        }
    }
}
