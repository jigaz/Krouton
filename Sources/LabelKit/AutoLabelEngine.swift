import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import OpticalCore
import Vision

// MARK: - Pure Auto-Label Artwork Harvester, Vision Center-Hole Avoidance & Palette Extractor

public struct AutoLabelInputItem: Sendable {
    public let url: URL?
    public let title: String
    public let performer: String
    public let durationSeconds: Double

    public init(url: URL?, title: String, performer: String = "", durationSeconds: Double = 0) {
        self.url = url
        self.title = title
        self.performer = performer
        self.durationSeconds = durationSeconds
    }
}

public struct AutoLabelComposition: Sendable {
    public let titleText: String
    public let subtitleText: String
    let rimBannerText: String
    let tracklistLines: [String]
    let artworkPNGData: Data?
    let artworkOffsetNormalized: CGSize
    let artworkScale: Double
    let primaryHex: String
    let secondaryHex: String
    public let summary: String

    public init(
        titleText: String,
        subtitleText: String,
        rimBannerText: String,
        tracklistLines: [String],
        artworkPNGData: Data?,
        artworkOffsetNormalized: CGSize,
        artworkScale: Double,
        primaryHex: String,
        secondaryHex: String,
        summary: String
    ) {
        self.titleText = titleText
        self.subtitleText = subtitleText
        self.rimBannerText = rimBannerText
        self.tracklistLines = tracklistLines
        self.artworkPNGData = artworkPNGData
        self.artworkOffsetNormalized = artworkOffsetNormalized
        self.artworkScale = artworkScale
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.summary = summary
    }
}

public enum AutoLabelComposer {
    public static func compose(
        albumTitle: String,
        albumPerformer: String,
        formatBadge: String,
        items: [AutoLabelInputItem]
    ) async -> AutoLabelComposition {
        let resolvedTitle = albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "KROUTON MASTER DISC"
            : albumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedArtist = albumPerformer.trimmingCharacters(in: .whitespacesAndNewlines)

        let lines: [String] = items.enumerated().prefix(16).map { idx, item in
            let clean = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.durationSeconds > 0 {
                let mins = Int(item.durationSeconds) / 60
                let secs = Int(item.durationSeconds) % 60
                return String(format: "%02d. %@ (%d:%02d)", idx + 1, clean, mins, secs)
            }
            return String(format: "%02d. %@", idx + 1, clean)
        }

        let yearStr = String(Calendar.current.component(.year, from: Date()))
        let rim = "\(resolvedTitle.uppercased()) • \(formatBadge.uppercased()) • \(yearStr) • MASTERED WITH KROUTON"

        let harvestedImage = await harvestBestArtwork(from: items.compactMap(\.url))
        var pngData: Data? = nil
        var offset = CGSize.zero
        var scale = 1.0
        var priHex = "#E85D2A"
        var secHex = "#2A9D8F"

        if let cgImg = harvestedImage {
            pngData = encodePNG(cgImg)
            let placement = computeCenterHoleSafePlacement(for: cgImg)
            offset = placement.offset
            scale = placement.scale
            let palette = extractDominantHexPair(from: cgImg)
            priHex = palette.primary
            secHex = palette.secondary
        }

        let artDesc = harvestedImage != nil ? "embedded/folder artwork + Vision center-hole framing" : "procedural studio palette"
        let summary = "Auto-composed disc label (\(lines.count) items, \(artDesc))"

        return AutoLabelComposition(
            titleText: resolvedTitle,
            subtitleText: resolvedArtist,
            rimBannerText: rim,
            tracklistLines: lines,
            artworkPNGData: pngData,
            artworkOffsetNormalized: offset,
            artworkScale: scale,
            primaryHex: priHex,
            secondaryHex: secondaryHex(from: secHex),
            summary: summary
        )
    }

    private static func secondaryHex(from hex: String) -> String { hex }

    static func harvestBestArtwork(from urls: [URL]) async -> CGImage? {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "heic", "tiff", "webp"].contains(ext),
               let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                return img
            }
            if ["mp3", "m4a", "flac", "wav", "aiff", "aif", "mp4", "mov", "m4v"].contains(ext) {
                let asset = AVURLAsset(url: url)
                if let metaList = try? await asset.load(.commonMetadata) {
                    for item in metaList where item.commonKey == .commonKeyArtwork {
                        if let data = try? await item.load(.dataValue),
                           let src = CGImageSourceCreateWithData(data as CFData, nil),
                           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                            return img
                        }
                    }
                }
            }
            let dir = url.deletingLastPathComponent()
            for candidate in ["cover.jpg", "cover.png", "folder.jpg", "front.jpg", "artwork.jpg"] {
                let artURL = dir.appendingPathComponent(candidate)
                if FileManager.default.fileExists(atPath: artURL.path),
                   let src = CGImageSourceCreateWithURL(artURL as CFURL, nil),
                   let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    return img
                }
            }
        }
        return nil
    }

    static func computeCenterHoleSafePlacement(for image: CGImage) -> (offset: CGSize, scale: Double) {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let req = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([req])
        guard let obs = req.results?.first,
              let salient = obs.salientObjects?.first else {
            return (.zero, 1.0)
        }
        let box = salient.boundingBox
        let center = CGPoint(x: box.midX, y: box.midY)
        let dx = center.x - 0.5
        let dy = center.y - 0.5
        let distFromCenter = hypot(dx, dy)
        // If primary subject lands inside the 19% spindle center hole radius, shift outward gently
        if distFromCenter < 0.16 {
            let shiftY: CGFloat = dy >= 0 ? 0.14 : -0.14
            return (CGSize(width: 0, height: shiftY), 1.08)
        }
        return (.zero, 1.0)
    }

    static func extractDominantHexPair(from image: CGImage) -> (primary: String, secondary: String) {
        let w = 16, h = 16
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: &pixels,
                  width: w,
                  height: h,
                  bitsPerComponent: 8,
                  bytesPerRow: w * 4,
                  space: cs,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return ("#E85D2A", "#2A9D8F")
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var r1 = 0, g1 = 0, b1 = 0, c1 = 0
        var r2 = 0, g2 = 0, b2 = 0, c2 = 0
        for i in 0..<(w * h) {
            let r = Int(pixels[i * 4])
            let g = Int(pixels[i * 4 + 1])
            let b = Int(pixels[i * 4 + 2])
            if i < (w * h) / 2 {
                r1 += r; g1 += g; b1 += b; c1 += 1
            } else {
                r2 += r; g2 += g; b2 += b; c2 += 1
            }
        }
        let p = String(format: "#%02X%02X%02X", r1 / max(1, c1), g1 / max(1, c1), b1 / max(1, c1))
        let s = String(format: "#%02X%02X%02X", r2 / max(1, c2), g2 / max(1, c2), b2 / max(1, c2))
        return (p, s)
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
