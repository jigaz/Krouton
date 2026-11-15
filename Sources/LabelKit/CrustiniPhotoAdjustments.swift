import RescueKit
import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import OpticalCore

// MARK: - Unified CoreImage GPU Background Adjustment Pipeline (sRGB & Resolution-Independent)

extension KroutonKrustiniModule {

    /// Applies the 5 core graphic adjustments on the GPU with resolution-independent blur scaling
    /// so interactive preview (360pt) and 300-DPI print export (1417px) match identically.
    public static func applyApplePhotosAdjustments(
        to inputImage: CIImage,
        adjustments: KroutonBackgroundAdjustments,
        extentRect: CGRect
    ) -> CIImage {
        guard !adjustments.isIdentity else {
            return inputImage.cropped(to: extentRect)
        }

        var current = inputImage.cropped(to: extentRect)

        // 1. Hue Shift (-180° to +180°)
        if abs(adjustments.hueDegrees) >= 0.1 {
            let hue = CIFilter.hueAdjust()
            hue.inputImage = current
            hue.angle = Float(adjustments.hueDegrees * Double.pi / 180.0)
            if let out = hue.outputImage?.cropped(to: extentRect) {
                current = out
            }
        }

        // 2. Brightness, Contrast & Saturation
        if abs(adjustments.brightness) >= 0.005 ||
           abs(adjustments.contrast - 1.0) >= 0.005 ||
           abs(adjustments.saturation - 1.0) >= 0.005 {
            let cc = CIFilter.colorControls()
            cc.inputImage = current
            cc.brightness = Float(max(-0.5, min(0.5, adjustments.brightness)))
            cc.contrast = Float(max(0.4, min(2.0, adjustments.contrast)))
            cc.saturation = Float(max(0.0, min(2.0, adjustments.saturation)))
            if let out = cc.outputImage?.cropped(to: extentRect) {
                current = out
            }
        }

        // 3. Resolution-Independent Edge-Clamped Gaussian Blur
        if adjustments.blurRadius >= 0.1 {
            let scaleFactor = max(0.25, Double(extentRect.width) / 360.0)
            let scaledRadius = Float(min(120.0, adjustments.blurRadius * scaleFactor))
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = current.clampedToExtent()
            blur.radius = scaledRadius
            if let out = blur.outputImage?.cropped(to: extentRect) {
                current = out
            }
        }

        return current.cropped(to: extentRect)
    }

    // MARK: - Unified sRGB Vector Gradient Rasterizer (Used when CoreImage Adjustments are active)

    internal static func makeSimpleVectorGradientCIImage(
        style: KroutonVectorBackgroundStyle,
        primaryColor: KroutonRGBAColor,
        secondaryColor: KroutonRGBAColor,
        midpoint: Double,
        angleDegrees: Double,
        dimension: CGFloat
    ) -> CIImage {
        let dim = Int(dimension)
        guard let ctx = CGContext(
            data: nil, width: dim, height: dim, bitsPerComponent: 8, bytesPerRow: dim * 4,
            space: sRGBColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CIImage.empty()
        }
        let c1 = CGColor(colorSpace: sRGBColorSpace, components: [CGFloat(primaryColor.r), CGFloat(primaryColor.g), CGFloat(primaryColor.b), 1.0])!
        let c2 = CGColor(colorSpace: sRGBColorSpace, components: [CGFloat(secondaryColor.r), CGFloat(secondaryColor.g), CGFloat(secondaryColor.b), 1.0])!
        let white = CGColor(colorSpace: sRGBColorSpace, components: [1.0, 1.0, 1.0, 1.0])!
        let mid = CGFloat(max(0.1, min(0.9, midpoint)))
        let center = CGPoint(x: dimension * 0.5, y: dimension * 0.5)

        switch style {
        case .templateDefault:
            ctx.setFillColor(white)
            ctx.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))
        case .solidColor:
            ctx.setFillColor(c1)
            ctx.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))
        case .radialGradient, .gpuKaleidoscope, .tinyPlanetGlobe:
            let midCol = CGColor(
                colorSpace: sRGBColorSpace,
                components: [
                    CGFloat(primaryColor.r + (secondaryColor.r - primaryColor.r) * 0.5),
                    CGFloat(primaryColor.g + (secondaryColor.g - primaryColor.g) * 0.5),
                    CGFloat(primaryColor.b + (secondaryColor.b - primaryColor.b) * 0.5),
                    1.0
                ]
            )!
            if let g = CGGradient(colorsSpace: sRGBColorSpace, colors: [c1, midCol, c2] as CFArray, locations: [0.0, mid, 1.0]) {
                ctx.drawRadialGradient(g, startCenter: center, startRadius: dimension * 0.04, endCenter: center, endRadius: dimension * 0.5, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        case .linearGradient, .angularGradient:
            let rad = CGFloat(angleDegrees * .pi / 180.0)
            let startPt = CGPoint(x: center.x - cos(rad) * dimension * 0.5, y: center.y - sin(rad) * dimension * 0.5)
            let endPt = CGPoint(x: center.x + cos(rad) * dimension * 0.5, y: center.y + sin(rad) * dimension * 0.5)
            if let g = CGGradient(colorsSpace: sRGBColorSpace, colors: [c1, c2] as CFArray, locations: [0.0, 1.0]) {
                ctx.drawLinearGradient(g, start: startPt, end: endPt, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        return CIImage(cgImage: cg)
    }

}
