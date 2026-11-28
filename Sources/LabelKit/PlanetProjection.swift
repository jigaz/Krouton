import CoreGraphics
import Foundation
import ImageIO
import OpticalCore
import os

// MARK: - Panorama source

/// A panorama decoded once into 8-bit RGBA, at most `maxWidth` wide (previews use a smaller
/// copy than prints, so dragging a slider stays quick).
public final class KroutonPlanetSource: Sendable {
    /// The decoded width in pixels.
    public let width: Int
    /// The decoded height in pixels.
    public let height: Int
    let pixels: [UInt8]
    /// Changes with every decode, for render caches.
    public let identity = UUID()

    /// Decodes `cgImage` scaled down to at most `maxWidth`; nil when it can't be drawn.
    public init?(cgImage: CGImage, maxWidth: Int) {
        let scale = min(1.0, Double(maxWidth) / Double(max(1, cgImage.width)))
        let w = max(2, Int((Double(cgImage.width) * scale).rounded()))
        let h = max(2, Int((Double(cgImage.height) * scale).rounded()))
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: KroutonLabelGeometryEngine.sRGBColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        pixels = buffer
    }

    /// Reads a photo from disk (any format ImageIO opens), oriented as it was shot, at most
    /// `maxPixel` on its longer side.
    public static func loadImage(at url: URL, maxPixel: Int = 16_384) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Bilinear sample; x wraps round the panorama, y stops at the top and bottom rows.
    @inline(__always)
    func sample(x: Double, y: Double, into out: inout (Double, Double, Double)) {
        let fx = x - 0.5, fy = min(Double(height - 1), max(0, y - 0.5))
        let x0f = fx.rounded(.down), y0 = Int(fy.rounded(.down))
        let tx = fx - x0f, ty = fy - Double(y0)
        var x0 = Int(x0f) % width
        if x0 < 0 { x0 += width }
        let x1 = (x0 + 1) % width, y1 = min(height - 1, y0 + 1)
        pixels.withUnsafeBufferPointer { p in
            let a = (y0 * width + x0) * 4, b = (y0 * width + x1) * 4
            let c = (y1 * width + x0) * 4, d = (y1 * width + x1) * 4
            let w00 = (1 - tx) * (1 - ty), w10 = tx * (1 - ty), w01 = (1 - tx) * ty, w11 = tx * ty
            out.0 += Double(p[a]) * w00 + Double(p[b]) * w10 + Double(p[c]) * w01 + Double(p[d]) * w11
            out.1 += Double(p[a + 1]) * w00 + Double(p[b + 1]) * w10 + Double(p[c + 1]) * w01 + Double(p[d + 1]) * w11
            out.2 += Double(p[a + 2]) * w00 + Double(p[b + 2]) * w10 + Double(p[c + 2]) * w01 + Double(p[d + 2]) * w11
        }
    }
}

// MARK: - Projection

/// Wraps a panorama into the disc with polar coordinates. Every disc pixel is traced back to
/// the photo: its angle round the centre picks the column, its distance from the centre the
/// row, so the bottom of the photo meets in the middle and the top runs round the rim.
public enum KroutonPlanetProjection {
    /// Where on the photo (as fractions of its width and height) the disc point at `t` lands:
    /// `t` is 0 at the centre (or hub edge) and 1 at the rim, `turns` the angle (0 at 12 o'clock,
    /// clockwise, in whole turns). The width fraction is before the seam is applied.
    public static func photoPoint(t: Double, turns: Double, settings s: KroutonPlanetSettings) -> (u: Double, v: Double) {
        let h = min(0.98, max(0.02, s.horizonRadius))
        let hp = min(0.98, max(0.02, s.horizonInPhoto))
        let tc = max(0, t)
        // `inner` runs 0→1 from the centre to the horizon, `outer` 0→1 from the horizon outwards.
        let inner: Double, outer: Double
        switch s.projection {
        case .polar:
            let gc = min(4, max(0.25, s.groundCurve))
            inner = tc <= h ? pow(tc / h, 1 / gc) : 1
            outer = tc <= h ? 0 : (tc - h) / (1 - h)
        case .stereographic:
            let theta = 2 * atan(tc / h)          // π/2 at the horizon
            inner = min(1, theta / (Double.pi / 2))
            outer = max(0, (theta - Double.pi / 2) / (Double.pi / 2))
        }
        var v: Double
        if s.orientation == .planet {
            v = tc <= h ? hp + (1 - hp) * (1 - inner) : hp * (1 - outer)
        } else {
            v = tc <= h ? hp * inner : hp + (1 - hp) * outer
        }
        v = min(1, max(0, v))
        let crop = min(0.9, max(0, s.cropTop) + max(0, s.cropBottom))
        v = max(0, s.cropTop) + v * (1 - crop)
        var u = turns + s.rotationDegrees / 360 + s.twistDegrees / 360 * tc
        if s.flipHorizontal { u = -u }
        u -= u.rounded(.down)
        return (u, v)
    }

    /// The photo column for `u` after the seam: wrapped, crossfaded or mirrored. Returns up to
    /// two columns with their weights.
    static func seamColumns(u: Double, width: Int, settings s: KroutonPlanetSettings) -> (Double, Double, Double) {
        let w = Double(width)
        switch s.seam {
        case .wrap:
            return (u * w, 0, 0)
        case .mirror:
            let x = u * 2 * w
            return (x <= w ? x : 2 * w - x, 0, 0)
        case .blend:
            let band = min(0.45, max(0.005, s.seamBlend))
            let x = u * (1 - band) * w
            let bandPixels = band * w
            guard x < bandPixels else { return (x, 0, 0) }
            let weight = x / bandPixels
            return (x, x + (1 - band) * w, 1 - weight)
        }
    }

    // MARK: - Rendering

    private struct CacheKey: Hashable {
        let source: UUID
        let settings: KroutonPlanetSettings
        let pixels: Int
        let hubRatio: Double
    }
    private static let cache = OSAllocatedUnfairLock<[(CacheKey, CGImage)]>(initialState: [])

    /// Renders the disc as a square `pixels` wide. `hubRatio` is the hub diameter over the disc
    /// diameter (used when `startAtHub` is on).
    public static func render(_ source: KroutonPlanetSource, settings s: KroutonPlanetSettings,
                              pixels: Int, hubRatio: Double) -> CGImage? {
        let n = max(16, min(8_192, pixels))
        let key = CacheKey(source: source.identity, settings: s, pixels: n, hubRatio: hubRatio)
        if let hit = cache.withLock({ $0.first { $0.0 == key }?.1 }) { return hit }

        let aa = max(1, min(3, s.antialias))
        let hub = s.startAtHub ? min(0.6, max(0, hubRatio)) : 0
        let fade = (r: s.fadeColor.r * 255, g: s.fadeColor.g * 255, b: s.fadeColor.b * 255)
        var output = [UInt8](repeating: 255, count: n * n * 4)
        output.withUnsafeMutableBufferPointer { out in
            // Rows are written by separate threads, each to its own bytes; the address goes
            // across as an integer.
            guard let start = out.baseAddress else { return }
            let address = Int(bitPattern: start)
            DispatchQueue.concurrentPerform(iterations: n) { row in
                guard let rowBase = UnsafeMutablePointer<UInt8>(bitPattern: address) else { return }
                for col in 0..<n {
                    var acc = (0.0, 0.0, 0.0)
                    for sy in 0..<aa {
                        for sx in 0..<aa {
                            let x = (Double(col) + (Double(sx) + 0.5) / Double(aa)) / Double(n) * 2 - 1 - s.centerOffsetX
                            let y = (Double(row) + (Double(sy) + 0.5) / Double(aa)) / Double(n) * 2 - 1 - s.centerOffsetY
                            let rho = (x * x + y * y).squareRoot()
                            let t = (rho - hub) / (1 - hub)
                            let point = photoPoint(t: t, turns: atan2(x, -y) / (2 * Double.pi), settings: s)
                            let py = point.v * Double(source.height)
                            let (x1, x2, weight2) = seamColumns(u: point.u, width: source.width, settings: s)
                            var c = (0.0, 0.0, 0.0)
                            source.sample(x: x1, y: py, into: &c)
                            if weight2 > 0 {
                                var d = (0.0, 0.0, 0.0)
                                source.sample(x: x2, y: py, into: &d)
                                c = (c.0 + (d.0 - c.0) * weight2, c.1 + (d.1 - c.1) * weight2, c.2 + (d.2 - c.2) * weight2)
                            }
                            var f = 0.0
                            if s.rimFade > 0 { f = max(f, smoothstep(1 - s.rimFade, 1, rho)) }
                            if s.centerFade > 0 { f = max(f, 1 - smoothstep(0, s.centerFade, t)) }
                            acc.0 += c.0 + (fade.r - c.0) * f
                            acc.1 += c.1 + (fade.g - c.1) * f
                            acc.2 += c.2 + (fade.b - c.2) * f
                        }
                    }
                    let samples = Double(aa * aa)
                    let i = (row * n + col) * 4
                    rowBase[i] = UInt8(min(255, max(0, acc.0 / samples)).rounded())
                    rowBase[i + 1] = UInt8(min(255, max(0, acc.1 / samples)).rounded())
                    rowBase[i + 2] = UInt8(min(255, max(0, acc.2 / samples)).rounded())
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let image = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                                  space: KroutonLabelGeometryEngine.sRGBColorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        cache.withLock { entries in
            entries.removeAll { $0.0 == key }
            entries.append((key, image))
            if entries.count > 3 { entries.removeFirst() }
        }
        return image
    }

    @inline(__always)
    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard b > a else { return x >= b ? 1 : 0 }
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}
