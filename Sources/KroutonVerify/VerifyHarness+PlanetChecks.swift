import CoreGraphics
import Foundation
import LabelKit
import OpticalCore

// MARK: - VerifyHarness — Panorama Planet and Print Finishing (Suite 15)

/// The planet traces each disc pixel back to the photo: the centre to its bottom row, the
/// horizon radius to its horizon, the rim towards its top; a tunnel the other way round.
extension KroutonTestHarness {
static func verifyPanoramaPlanet(_ h: inout KroutonTestHarness) {
    var s = KroutonPlanetSettings()
    s.projection = .polar
    s.horizonRadius = 0.5
    s.horizonInPhoto = 0.5
    let centre = KroutonPlanetProjection.photoPoint(t: 0, turns: 0, settings: s)
    let horizon = KroutonPlanetProjection.photoPoint(t: 0.5, turns: 0.25, settings: s)
    let rim = KroutonPlanetProjection.photoPoint(t: 1, turns: 0.5, settings: s)
    h.check(abs(centre.v - 1) < 1e-9 && abs(horizon.v - 0.5) < 1e-9 && abs(rim.v) < 1e-9 && abs(horizon.u - 0.25) < 1e-9,
            "Polar planet: centre = photo bottom, horizon radius = photo horizon, rim = photo top, angle = column")
    s.orientation = .tunnel
    h.check(abs(KroutonPlanetProjection.photoPoint(t: 0, turns: 0, settings: s).v) < 1e-9, "Tunnel: the centre is the photo's top")
    s.orientation = .planet
    s.projection = .stereographic
    s.horizonRadius = 0.4
    h.check(abs(KroutonPlanetProjection.photoPoint(t: 0.4, turns: 0, settings: s).v - 0.5) < 1e-9,
            "Little planet: the horizon lands at the horizon radius")

    // A 64 x 32 photo, sky blue above and grass green below, wrapped with no hub.
    var pixels = [UInt8](repeating: 0, count: 64 * 32 * 4)
    for y in 0..<32 { for x in 0..<64 {
        let i = (y * 64 + x) * 4
        pixels[i] = 0; pixels[i + 1] = y < 16 ? 0 : 200; pixels[i + 2] = y < 16 ? 220 : 0; pixels[i + 3] = 255
    } }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let photo: CGImage? = pixels.withUnsafeMutableBytes { raw in
        CGContext(data: raw.baseAddress, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 256, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
    }
    s.startAtHub = false
    s.antialias = 1
    let source = photo.flatMap { KroutonPlanetSource(cgImage: $0, maxWidth: 64) }
    let disc = source.flatMap { KroutonPlanetProjection.render($0, settings: s, pixels: 100, hubRatio: 0.15) }
    func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (Int, Int, Int) {
        var p = [UInt8](repeating: 0, count: 4)
        p.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        }
        return (Int(p[0]), Int(p[1]), Int(p[2]))
    }
    if let disc {
        let middle = pixel(disc, 50, 52), edge = pixel(disc, 50, 2)
        h.check(middle.1 > 150 && middle.2 < 60 && edge.2 > 150 && edge.1 < 60,
                "Rendered planet: grass in the middle of the disc, sky at the rim")
        let light = KroutonLabelGeometryEngine.applyInk(to: disc, density: 0.5, blackLift: 0)
        h.check(pixel(light, 50, 52).0 > 110, "Ink density 50% moves every colour half way to white")
        let bled = KroutonLabelGeometryEngine.addBleed(to: disc, outerMM: 120, innerMM: 18, bleedOuterMM: 1.2, bleedInnerMM: 0.5)
        h.check(bled.width == 102 && bled.height == 102, "A 1.2 mm bleed widens a 120 mm, 100-pixel label by 1 pixel a side")
    } else {
        h.check(false, "The panorama planet must render")
    }
    h.check(KroutonLabelGeometryEngine.alignmentTestPDF(outerMM: 118, innerMM: 22, offsetXMM: 0.5, offsetYMM: -0.3) != nil,
            "The alignment test sheet must draw")
}
}
