import AVFoundation
import Combine
import CoreMedia
import CryptoKit
import Foundation
import SwiftUI

// MARK: - Universal Media Decoder & Hardware Acceleration Engine (Hardware & Software Stream Engine)

public enum KroutonHeatTier: String, Sendable {
    case videoToolboxASIC = "Apple Silicon VideoToolbox ASIC (Zero-Copy GPU)"
    case hybridDemuxVT = "Container Stream Demux -> VideoToolbox Hardware"
    case accelerateSIMD = "Apple Accelerate vDSP / ARM64 NEON SIMD"
    case coreAudioHardware = "CoreAudio / AudioToolbox ExtAudioFile"
    case bitstreamPassthrough = "Direct Optical Bitstream Passthrough (Zero Re-encode)"
}

public struct KroutonStreamProbeResult: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let fileExtension: String
    let containerFormat: String
    let videoCodecName: String?
    let audioCodecName: String
    let subtitleSummary: String?
    public let accelerationTier: KroutonHeatTier
    public let shortHardwareBadge: String
    public let isHardwareAccelerated: Bool
    let targetMasteringPipeline: String

    public init(
        fileExtension: String,
        containerFormat: String,
        videoCodecName: String?,
        audioCodecName: String,
        subtitleSummary: String?,
        accelerationTier: KroutonHeatTier,
        shortHardwareBadge: String,
        isHardwareAccelerated: Bool,
        targetMasteringPipeline: String
    ) {
        self.fileExtension = fileExtension
        self.containerFormat = containerFormat
        self.videoCodecName = videoCodecName
        self.audioCodecName = audioCodecName
        self.subtitleSummary = subtitleSummary
        self.accelerationTier = accelerationTier
        self.shortHardwareBadge = shortHardwareBadge
        self.isHardwareAccelerated = isHardwareAccelerated
        self.targetMasteringPipeline = targetMasteringPipeline
    }
}

public enum KroutonMediaPrepEngine {

    /// What the file name alone says about a media file: its container, from the extension.
    /// Nothing is opened, so the codecs, captions and decoding path are not known and are left
    /// empty (`videoCodecName` and `subtitleSummary` nil, `audioCodecName` "Not probed",
    /// `isHardwareAccelerated` false). `accelerationTier` is only the family of file.
    public static func probeFile(_ url: URL) -> KroutonStreamProbeResult {
        let ext = url.pathExtension.lowercased()
        let (container, tier) = containerByExtension(ext)
        return KroutonStreamProbeResult(
            fileExtension: ext.isEmpty ? "MEDIA" : ext.uppercased(),
            containerFormat: container,
            videoCodecName: nil,
            audioCodecName: "Not probed",
            subtitleSummary: nil,
            accelerationTier: tier,
            shortHardwareBadge: "\(container) (codecs not probed)",
            isHardwareAccelerated: false,
            targetMasteringPipeline: "Not determined"
        )
    }

    static func containerByExtension(_ ext: String) -> (container: String, tier: KroutonHeatTier) {
        switch ext {
        case "mov": return ("QuickTime movie", .videoToolboxASIC)
        case "mxf": return ("MXF file", .videoToolboxASIC)
        case "mp4", "m4v": return ("MPEG-4 file", .videoToolboxASIC)
        case "mkv": return ("Matroska file", .hybridDemuxVT)
        case "webm": return ("WebM file", .hybridDemuxVT)
        case "m2ts", "mts", "ts": return ("MPEG transport stream", .hybridDemuxVT)
        case "vob", "mpg", "mpeg", "m2v", "evo": return ("MPEG program stream", .bitstreamPassthrough)
        case "avi", "wmv", "asf", "flv", "divx", "dv", "ogv", "rmvb": return ("\(ext.uppercased()) file", .accelerateSIMD)
        case "flac", "ape", "wv", "tta", "shn": return ("\(ext.uppercased()) lossless audio", .accelerateSIMD)
        case "dsf", "dff": return ("\(ext.uppercased()) DSD audio", .accelerateSIMD)
        case "wav", "aiff", "aif", "caf", "alac": return ("\(ext.uppercased()) audio", .coreAudioHardware)
        case "ac3", "eac3", "thd", "mlp", "dts", "dtshd": return ("\(ext.uppercased()) audio bitstream", .bitstreamPassthrough)
        default: return (ext.isEmpty ? "Media file" : "\(ext.uppercased()) file", .coreAudioHardware)
        }
    }
}

// MARK: - KroutonStagedFileEntry Bootability & .BIN/.CUE <-> .ISO Conversion UI Helpers
extension KroutonStagedFileEntry {
    public var conversionTargetLabel: String {
        let ext = url.pathExtension.lowercased()
        if ext == "bin" {
            return "Convert .BIN -> .ISO (2,048 B/sec)"
        } else {
            return "Convert .ISO -> .BIN/.CUE (2,352 B/sec)"
        }
    }
}

// MARK: - Live Disc Image Sector Hex/ASCII Reader & CryptoKit SHA-256 Engine
/// Reads disc images sector by sector: hex dumps for the inspector and SHA-256 digests.
public enum KroutonElToritoBootInspector {
    public struct HexDumpRow: Identifiable, Hashable, Sendable {
        public let id: Int
        public let offsetHex: String
        public let hexBytes: String
        public let asciiText: String
    }

    /// Reads the first 256 bytes of sector `lba` from the file on disk, 16 bytes a row. Only bytes
    /// that are really in the file are shown: a sector near the end gives a shorter last row, and
    /// a sector past the end, or a file that can't be read, gives no rows (see
    /// `sectorDumpUnavailableReason`).
    public static func readSectorHexDump(url: URL, lba: Int, sectorSize: Int = 2048) -> [HexDumpRow] {
        guard lba >= 0, sectorSize > 0 else { return [] }
        let byteOffset = UInt64(lba) * UInt64(sectorSize)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let fileSize = try? handle.seekToEnd(), byteOffset < fileSize else { return [] }
        guard (try? handle.seek(toOffset: byteOffset)) != nil,
              let data = try? handle.read(upToCount: 256), !data.isEmpty else { return [] }
        let bytes = [UInt8](data)
        var rows: [HexDumpRow] = []
        for (rowIdx, start) in stride(from: 0, to: bytes.count, by: 16).enumerated() {
            let slice = bytes[start..<min(start + 16, bytes.count)]
            let offsetStr = String(format: "%08llX", byteOffset + UInt64(start))
            var hexParts = slice.map { String(format: "%02X", $0) }
            hexParts += Array(repeating: "  ", count: 16 - hexParts.count)
            let leftHex = hexParts[0..<8].joined(separator: " ")
            let rightHex = hexParts[8..<16].joined(separator: " ")
            let asciiStr = slice.map { (b: UInt8) -> String in
                (b >= 32 && b <= 126) ? String(UnicodeScalar(b)) : "."
            }.joined()
            rows.append(HexDumpRow(id: rowIdx, offsetHex: offsetStr, hexBytes: "\(leftHex)  \(rightHex)", asciiText: asciiStr))
        }
        return rows
    }

    /// Why `readSectorHexDump` has nothing to show for `lba`, or nil when it has.
    public static func sectorDumpUnavailableReason(url: URL, lba: Int, sectorSize: Int = 2048) -> String? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else {
            return "The image can't be read."
        }
        let sectorBytes = Int64(max(1, sectorSize))
        let sectors = (Int64(size) + sectorBytes - 1) / sectorBytes
        guard lba >= 0, Int64(lba) < sectors else {
            return "LBA \(lba) is past the end of the image (\(sectors) sectors of \(sectorBytes) bytes)."
        }
        return nil
    }

    /// The file's SHA-256 as lowercase hex, read in 1 MiB pieces so a disc image of any size uses
    /// little memory. Nil when the file can't be opened or a read fails.
    public static func computeSHA256Hex(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data?
            do {
                chunk = try handle.read(upToCount: 1 << 20)
            } catch {
                return nil
            }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Pure IEEE-754 RGB <-> HSB & Display-P3 Perceptual Harmony Engine
public enum KroutonPureColorMath {
    public static func extractSRGB(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let resolved = color.resolve(in: EnvironmentValues())
        return (
            CGFloat(max(0.0, min(1.0, resolved.red))),
            CGFloat(max(0.0, min(1.0, resolved.green))),
            CGFloat(max(0.0, min(1.0, resolved.blue))),
            CGFloat(max(0.0, min(1.0, resolved.opacity)))
        )
    }

    public static func rgbToHSB(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let delta = maxC - minC

        var h: CGFloat = 0.0
        let s: CGFloat = (maxC == 0.0) ? 0.0 : (delta / maxC)
        let v: CGFloat = maxC

        if delta > 0.00001 {
            if maxC == r {
                h = (g - b) / delta
                if h < 0.0 { h += 6.0 }
            } else if maxC == g {
                h = 2.0 + (b - r) / delta
            } else {
                h = 4.0 + (r - g) / delta
            }
            h /= 6.0
        }
        return (h, s, v)
    }

    static func hsbToRGB(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let clampedS = max(0.0, min(1.0, s))
        let clampedV = max(0.0, min(1.0, v))
        if clampedS <= 0.00001 {
            return (clampedV, clampedV, clampedV)
        }
        var wrappedH = h.truncatingRemainder(dividingBy: 1.0)
        if wrappedH < 0.0 { wrappedH += 1.0 }

        let sector = wrappedH * 6.0
        let i = Int(floor(sector))
        let f = sector - CGFloat(i)
        let p = clampedV * (1.0 - clampedS)
        let q = clampedV * (1.0 - clampedS * f)
        let t = clampedV * (1.0 - clampedS * (1.0 - f))

        switch i % 6 {
        case 0: return (clampedV, t, p)
        case 1: return (q, clampedV, p)
        case 2: return (p, clampedV, t)
        case 3: return (p, q, clampedV)
        case 4: return (t, p, clampedV)
        default: return (clampedV, p, q)
        }
    }

    public static func p3Color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Color {
        if let space = CGColorSpace(name: CGColorSpace.displayP3),
           let cg = CGColor(colorSpace: space, components: [r, g, b, 1.0]) {
            return Color(cgColor: cg)
        }
        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: 1.0)
    }

    public static func secondaryHarmonyForPresetID(_ id: Int, scheme: ColorScheme = .dark) -> Color {
        if scheme == .light {
            switch id {
            case 0:  return p3Color(0.50, 0.16, 0.84)
            case 1:  return p3Color(0.28, 0.54, 0.00)
            case 2:  return p3Color(0.14, 0.42, 0.82)
            case 3:  return p3Color(0.00, 0.44, 0.78)
            case 4:  return p3Color(0.64, 0.44, 0.00)
            case 5:  return p3Color(0.82, 0.30, 0.00)
            case 6:  return p3Color(0.76, 0.10, 0.48)
            case 7:  return p3Color(0.00, 0.54, 0.46)
            case 8:  return p3Color(0.56, 0.34, 0.10)
            case 9:  return p3Color(0.22, 0.26, 0.32)
            default: return p3Color(0.76, 0.10, 0.48)
            }
        }
        switch id {
        case 0:  return p3Color(0.78, 0.50, 1.00)
        case 1:  return p3Color(0.72, 1.00, 0.18)
        case 2:  return p3Color(0.56, 0.78, 1.00)
        case 3:  return p3Color(0.20, 0.68, 1.00)
        case 4:  return p3Color(0.98, 0.94, 0.32)
        case 5:  return p3Color(1.00, 0.48, 0.08)
        case 6:  return p3Color(0.98, 0.36, 0.76)
        case 7:  return p3Color(0.26, 0.99, 0.88)
        case 8:  return p3Color(0.98, 0.87, 0.68)
        case 9:  return p3Color(0.98, 0.99, 1.00)
        default: return p3Color(0.98, 0.36, 0.76)
        }
    }
}
