import Foundation
import OpticalDough

public enum KroutonRawSectorMode: String, Codable, Sendable, Equatable {
    case mode1_2352      = "MODE1/2352"
    case mode2Form1_2352 = "MODE2/2352"
    case iso2048         = "MODE1/2048"
    case audio2352       = "AUDIO"
}

public struct KroutonGaletteCueTrack: Sendable, Equatable, Identifiable {
    public var id: Int { trackNumber }
    public let trackNumber: Int
    public let mode: KroutonRawSectorMode
    public let title: String
    public let index00LBA: Int64?
    public let index01LBA: Int64
}

public struct KroutonGaletteDepotClassification: Sendable, Equatable {
    public let detectedFilesystems: [String]
    public let isBootable: Bool
    public let bootStandard: String
    public let recommendedMediaBadge: String
    public let totalSectors2048: Int64
}

public struct KroutonGaletteModule {
    public static let version = "0.1.0-alpha.1"

    /// Canonical 12-byte CD-ROM sync header: 00 FF FF FF FF FF FF FF FF FF FF 00
    public static let cdRomSyncPattern: [UInt8] = [
        0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00
    ]

    /// Converts MM:SS:FF string into a Red Book / Yellow Book LBA sector index (75 frames/sec)
    public static func parseMMSSFFToLBA(_ mmssff: String) -> Int64? {
        let parts = mmssff.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 3,
              let mm = Int64(parts[0]),
              let ss = Int64(parts[1]),
              let ff = Int64(parts[2]) else { return nil }
        return ((mm * 60) + ss) * 75 + ff
    }

    /// Parses a .cue sheet into structured track layout entries with exact LBA sector addresses
    public static func parseCueSheet(_ cueText: String) -> [KroutonGaletteCueTrack] {
        var tracks: [KroutonGaletteCueTrack] = []
        var currentNum: Int? = nil
        var currentMode: KroutonRawSectorMode = .audio2352
        var currentTitle: String = ""
        var currentIdx00: Int64? = nil
        var currentIdx01: Int64 = 0

        let flushCurrent = {
            if let num = currentNum {
                tracks.append(
                    KroutonGaletteCueTrack(
                        trackNumber: num,
                        mode: currentMode,
                        title: currentTitle.isEmpty ? String(format: "Track %02d", num) : currentTitle,
                        index00LBA: currentIdx00,
                        index01LBA: currentIdx01
                    )
                )
            }
        }

        for rawLine in cueText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let tokens = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard let head = tokens.first?.uppercased() else { continue }

            if head == "TRACK", tokens.count >= 3, let tNum = Int(tokens[1]) {
                flushCurrent()
                currentNum = tNum
                let modeStr = String(tokens[2]).uppercased()
                currentMode = KroutonRawSectorMode(rawValue: modeStr) ?? .audio2352
                currentTitle = ""
                currentIdx00 = nil
                currentIdx01 = 0
            } else if head == "TITLE", currentNum != nil {
                if let firstQuote = line.firstIndex(of: "\""),
                   let lastQuote = line.lastIndex(of: "\""),
                   firstQuote < lastQuote {
                    currentTitle = String(line[line.index(after: firstQuote)..<lastQuote])
                }
            } else if head == "INDEX", tokens.count >= 3, currentNum != nil {
                let idxType = String(tokens[1])
                if let lba = parseMMSSFFToLBA(String(tokens[2])) {
                    if idxType == "00" {
                        currentIdx00 = lba
                    } else if idxType == "01" {
                        currentIdx01 = lba
                    }
                }
            }
        }
        flushCurrent()
        return tracks
    }

    /// Extracts the 2048-byte ISO payload from a 2352-byte raw CD-ROM sector (Mode 1 or XA Mode 2 Form 1)
    public static func extractISO2048SectorFromRaw2352(_ rawSector: Data) -> Data? {
        guard rawSector.count == 2352 else {
            return rawSector.count == 2048 ? rawSector : nil
        }
        let bytes = [UInt8](rawSector)
        let hasSync = Array(bytes[0..<12]) == cdRomSyncPattern
        let modeByte = bytes[15]

        if hasSync && modeByte == 0x02 {
            // Mode 2 Form 1: 12B sync + 4B header + 8B subheader -> 2048B payload at [24..<2072]
            return Data(bytes[24..<(24 + 2048)])
        } else {
            // Mode 1: 12B sync + 4B header -> 2048B payload at [16..<2064]
            return Data(bytes[16..<(16 + 2048)])
        }
    }

    /// Classifies an optical image's bootability, filesystem signatures, and recommended target blank media
    public static func classifyDepotImage(byteSize: Int64, signatureSampleASCII: String) -> KroutonGaletteDepotClassification {
        var fs: [String] = []
        if signatureSampleASCII.contains("CD001") { fs.append("ISO-9660") }
        if signatureSampleASCII.contains("NSR02") || signatureSampleASCII.contains("NSR03") || signatureSampleASCII.contains("UDF") {
            fs.append("UDF")
        }
        if signatureSampleASCII.contains("Apple_partition_map") || signatureSampleASCII.contains("HFS") {
            fs.append("Apple Partition Map / HFS+")
        }
        if fs.isEmpty { fs.append("Raw Sector Image") }

        let hasElTorito = signatureSampleASCII.contains("EL TORITO")
        let hasAPMBoot = signatureSampleASCII.contains("Apple_partition_map")
        let isBootable = hasElTorito || hasAPMBoot
        let bootStd = hasElTorito ? "El Torito x86/EFI" : (hasAPMBoot ? "Apple OpenFirmware / APM" : "Non-Bootable Data/Media")

        let media: String
        if byteSize <= 737_280_000 {
            media = "CD-R (700 MB)"
        } else if byteSize <= 4_700_372_992 {
            media = "DVD-5 (4.7 GB SL)"
        } else if byteSize <= 8_547_991_552 {
            media = "DVD-9 (8.5 GB DL)"
        } else if byteSize <= 25_025_314_816 {
            media = "BD-25 (25 GB SL)"
        } else {
            media = "BD-50 / BDXL"
        }

        let sectors = max(1, (byteSize + 2047) / 2048)
        return KroutonGaletteDepotClassification(
            detectedFilesystems: fs,
            isBootable: isBootable,
            bootStandard: bootStd,
            recommendedMediaBadge: media,
            totalSectors2048: sectors
        )
    }
}

public struct GaletteBootClassification: Sendable, Equatable {
    public let formatName: String
    public let isBootable: Bool
    public let architectureDescription: String
}

public struct GaletteParsedTrack: Sendable, Equatable {
    public let trackNumber: Int
    public let mode: String
    public let sectorSize: Int
}

public struct GaletteParsedCueSheet: Sendable, Equatable {
    public let tracks: [GaletteParsedTrack]
}

extension KroutonGaletteModule {
    /// Classifies an ISO-9660 / El Torito / UDF header buffer for boot signatures.
    public static func classifyBootableImage(headerBytes: Data) -> GaletteBootClassification {
        let pvdOffset = 16 * 2048
        let brvdOffset = 17 * 2048
        let hasCD001 = headerBytes.count >= pvdOffset + 6 &&
            String(data: headerBytes.subdata(in: (pvdOffset + 1)..<(pvdOffset + 6)), encoding: .ascii) == "CD001"
        let hasElTorito = headerBytes.count >= brvdOffset + 30 &&
            String(data: headerBytes.subdata(in: (brvdOffset + 7)..<(brvdOffset + 30)), encoding: .ascii)?.hasPrefix("EL TORITO") == true
        return GaletteBootClassification(
            formatName: hasCD001 ? "ISO-9660 + El Torito" : "Raw Optical Image",
            isBootable: hasElTorito || hasCD001,
            architectureDescription: hasElTorito ? "El Torito x86_64 / EFI Boot Catalog (LBA 18)" : "Data Archive Volume"
        )
    }

    /// Parses a CUE sheet string into structured track descriptors (`MODE1/2352`, `MODE1/2048`, `AUDIO`).
    public static func parseCueSheet(cueText: String) -> GaletteParsedCueSheet {
        var tracks: [GaletteParsedTrack] = []
        for rawLine in cueText.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if trimmed.hasPrefix("TRACK ") {
                let parts = trimmed.split(separator: " ").map(String.init)
                let num = parts.count > 1 ? (Int(parts[1]) ?? (tracks.count + 1)) : (tracks.count + 1)
                let mode = parts.count > 2 ? parts[2] : "MODE1/2352"
                let secSize = mode.contains("2048") ? 2048 : 2352
                tracks.append(GaletteParsedTrack(trackNumber: num, mode: mode, sectorSize: secSize))
            }
        }
        return GaletteParsedCueSheet(tracks: tracks)
    }
}
