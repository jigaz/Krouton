import CoreGraphics
import CoreImage
import CoreText
import Foundation
import OpticalCore
import os

// MARK: - Print finishing for printable discs

extension KroutonLabelGeometryEngine {
    /// `CIContext` is not `Sendable`: held behind a lock.
    private static let finishingContext = OSAllocatedUnfairLock(uncheckedState: CIContext(options: [
        .workingColorSpace: sRGBColorSpace, .outputColorSpace: sRGBColorSpace,
    ]))

    /// The Adjust tool's corrections, applied to a finished bitmap such as the planet.
    public static func applyAdjustments(to image: CGImage, _ adjustments: KroutonBackgroundAdjustments) -> CGImage {
        guard !adjustments.isIdentity else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let adjusted = applyApplePhotosAdjustments(to: CIImage(cgImage: image), adjustments: adjustments, extentRect: rect)
        return finishingContext.withLockUnchecked { $0.createCGImage(adjusted, from: rect) } ?? image
    }

    /// Lightens the artwork for the disc surface: `density` below 1 moves every colour towards
    /// the white disc, and `blackLift` raises the darkest tones most (a curve, so mid-tones and
    /// highlights barely move) so large dark areas don't flood the coating.
    public static func applyInk(to image: CGImage, density: Double, blackLift: Double) -> CGImage {
        let d = min(1, max(0.3, density)), lift = min(0.4, max(0, blackLift))
        guard d < 0.999 || lift > 0.001 else { return image }
        var table = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            let inked = 255 - (255 - Double(i)) * d
            let dark = 1 - inked / 255
            table[i] = UInt8(min(255, max(0, inked + lift * 255 * dark * dark)).rounded())
        }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: sRGBColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return image }
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] == 255 {
            pixels[i] = table[Int(pixels[i])]
            pixels[i + 1] = table[Int(pixels[i + 1])]
            pixels[i + 2] = table[Int(pixels[i + 2])]
        }
        return makeImage(pixels, width: w, height: h) ?? image
    }

    /// Carries the artwork past the rim and into the hub so a print a little off centre leaves no
    /// white edge: the image is drawn once enlarged (filling the outer bleed with what is at the
    /// rim) and once reduced (filling the inner bleed with what is at the hub's edge), then
    /// itself on top. The result is wider by the outer bleed on each side, at the same scale.
    public static func addBleed(to image: CGImage, outerMM: Double, innerMM: Double,
                                bleedOuterMM: Double, bleedInnerMM: Double) -> CGImage {
        let bo = min(3, max(0, bleedOuterMM)), bi = min(3, max(0, min(bleedInnerMM, innerMM / 2 - 1)))
        guard bo > 0.01 || bi > 0.01 else { return image }
        let n = CGFloat(image.width), pxPerMM = n / CGFloat(outerMM)
        let size = Int((n + 2 * CGFloat(bo) * pxPerMM).rounded())
        let full = CGFloat(size), c = full / 2
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: sRGBColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        func draw(scale: CGFloat) {
            let side = n * scale
            ctx.draw(image, in: CGRect(x: c - side / 2, y: c - side / 2, width: side, height: side))
        }
        func ring(_ r1: CGFloat, _ r2: CGFloat) {
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: c - r2, y: c - r2, width: r2 * 2, height: r2 * 2))
            ctx.addEllipse(in: CGRect(x: c - r1, y: c - r1, width: r1 * 2, height: r1 * 2))
            ctx.clip(using: .evenOdd)
        }
        let outerR = n / 2, innerR = CGFloat(innerMM) / 2 * pxPerMM
        draw(scale: (CGFloat(outerMM) + 2 * CGFloat(bo)) / CGFloat(outerMM))
        if bi > 0.01 {
            ctx.saveGState()
            ring(innerR - CGFloat(bi) * pxPerMM, innerR + 1)
            draw(scale: (innerR - CGFloat(bi) * pxPerMM) / innerR)
            ctx.restoreGState()
        }
        ctx.saveGState()
        ring(innerR, outerR)
        draw(scale: 1)
        ctx.restoreGState()
        return ctx.makeImage() ?? image
    }

    static func makeImage(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: sRGBColorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    // MARK: - Alignment test

    /// A one-page PDF of thin rings and crosshairs at 1:1, to print on a spare disc (or paper in
    /// the tray) and read how far the printer is off: the rings are 1 mm apart near the rim and
    /// the hub, and the crosshair marks the centre the tray offset should hit.
    public static func alignmentTestPDF(outerMM: Double, innerMM: Double, offsetXMM: Double, offsetYMM: Double) -> Data? {
        guard let data = CFDataCreateMutable(nil, 0), let consumer = CGDataConsumer(data: data) else { return nil }
        var media = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &media, nil) else { return nil }
        ctx.beginPDFPage(nil)
        let k = pointsPerMillimeter
        let cx = media.width / 2 + CGFloat(offsetXMM) * k, cy = media.height * 0.54 - CGFloat(offsetYMM) * k
        func circle(_ diameterMM: Double, width: CGFloat, gray: CGFloat) {
            let r = CGFloat(diameterMM) / 2 * k
            ctx.setStrokeColor(CGColor(gray: gray, alpha: 1))
            ctx.setLineWidth(width)
            ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        for step in 0...4 {
            circle(outerMM - Double(step) * 2, width: step == 0 ? 0.6 : 0.25, gray: step == 0 ? 0 : 0.45)
            circle(innerMM + Double(step) * 2, width: step == 0 ? 0.6 : 0.25, gray: step == 0 ? 0 : 0.45)
        }
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(0.3)
        let arm = CGFloat(outerMM) / 2 * k
        ctx.move(to: CGPoint(x: cx - arm, y: cy)); ctx.addLine(to: CGPoint(x: cx + arm, y: cy))
        ctx.move(to: CGPoint(x: cx, y: cy - arm)); ctx.addLine(to: CGPoint(x: cx, y: cy + arm))
        ctx.strokePath()
        let note = String(format: "Krouton alignment test · %.0f / %.0f mm · rings 1 mm apart · offset X %+.1f Y %+.1f mm",
                          outerMM, innerMM, offsetXMM, offsetYMM)
        let font = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: note, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ]))
        ctx.textPosition = CGPoint(x: 42, y: 36)
        CTLineDraw(line, ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}
