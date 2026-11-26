import Foundation

// MARK: - Console Disc Identity

/// What a console disc image is, read from its own header, and what burning it will (and won't) do.
public struct KroutonConsoleDisc: Sendable, Equatable {
    public enum Platform: String, Sendable, CaseIterable {
        case gamecube = "GameCube"
        case wii = "Wii"
        case playstation = "PlayStation"
        case playstation2 = "PlayStation 2"
        case dreamcast = "Dreamcast"
        case saturn = "Saturn"
        case xbox = "Xbox"
        case unknown = "Unknown"
    }

    public let platform: Platform
    /// The disc's own product code: GALE01, T-8101N, MK-51000 and the like.
    public let gameID: String?
    public let title: String?
    public let region: String?
    /// False for formats Krouton can't write as a disc (GD-ROM images, DiscJuggler .cdi).
    public let canBurn: Bool
    public let recommendedMedia: String
    public let advice: String
}

// MARK: - Identifying an Image

public enum KroutonConsoleDiscIdentifier {
    /// How much of an image to read: enough for the PVD of a raw 2,352-byte CD image and an XISO header.
    public static let headerLength = 0x12000

    /// Reads the start of the image (or, for a .cue sheet, of its first .bin) and identifies it.
    public static func identify(url: URL) -> KroutonConsoleDisc {
        let ext = url.pathExtension.lowercased()
        var dataURL = url
        if ext == "cue", let sheet = try? String(contentsOf: url, encoding: .utf8), let first = firstBinary(inCue: sheet) {
            dataURL = url.deletingLastPathComponent().appendingPathComponent(first)
        }
        let size = (try? dataURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        guard let handle = try? FileHandle(forReadingFrom: dataURL) else {
            return identify(header: [], fileExtension: ext, byteSize: size)
        }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: headerLength)).map { [UInt8]($0) } ?? []
        return identify(header: header, fileExtension: ext, byteSize: size)
    }

    /// The first `FILE "name" BINARY` in a cue sheet.
    public static func firstBinary(inCue sheet: String) -> String? {
        for line in sheet.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("FILE ") else { continue }
            if let open = trimmed.firstIndex(of: "\""), let close = trimmed[trimmed.index(after: open)...].firstIndex(of: "\"") {
                return String(trimmed[trimmed.index(after: open)..<close])
            }
            return trimmed.split(separator: " ").dropFirst().first.map(String.init)
        }
        return nil
    }

    public static func identify(header: [UInt8], fileExtension: String, byteSize: Int64) -> KroutonConsoleDisc {
        let ext = fileExtension.lowercased()
        if ext == "gdi" {
            return disc(.dreamcast, nil, nil, nil, canBurn: false, byteSize: byteSize, advice: Advice.gdi)
        }
        if match(header, at: 0x1C, [0xC2, 0x33, 0x9F, 0x3D]) {
            return nintendo(.gamecube, header, byteSize: byteSize)
        }
        if match(header, at: 0x18, [0x5D, 0x1C, 0x9E, 0xA3]) {
            return nintendo(.wii, header, byteSize: byteSize)
        }
        if match(header, at: 0x10000, Array("MICROSOFT*XBOX*MEDIA".utf8)) {
            return disc(.xbox, nil, nil, nil, canBurn: true, byteSize: byteSize, advice: Advice.xbox)
        }
        if let offset = find(header, Array("SEGA SEGAKATANA".utf8)) {
            let id = text(header, offset + 0x40, 10)
            let title = text(header, offset + 0x80, 128)
            let isCDI = ext == "cdi"
            return disc(.dreamcast, id, title, nil, canBurn: !isCDI, byteSize: byteSize, advice: isCDI ? Advice.cdi : Advice.dreamcast)
        }
        if let offset = find(header, Array("SEGA SEGASATURN".utf8)) {
            return disc(.saturn, text(header, offset + 0x20, 10), text(header, offset + 0x60, 112), nil,
                        canBurn: true, byteSize: byteSize, advice: Advice.saturn)
        }
        if let pvd = primaryVolumeDescriptor(header), text(header, pvd + 8, 32) == "PLAYSTATION" {
            let volume = text(header, pvd + 40, 32)
            // Raw 2,352-byte images are CDs; a PS2 DVD is a plain 2,048-byte image larger than a CD.
            let isDVD = pvd == 0x8000 && byteSize > 900_000_000
            return disc(isDVD ? .playstation2 : .playstation, nil, volume, nil, canBurn: true, byteSize: byteSize,
                        advice: isDVD ? Advice.playstation2 : Advice.playstation)
        }
        return disc(.unknown, nil, nil, nil, canBurn: true, byteSize: byteSize, advice: Advice.unknown)
    }

    // MARK: - Header Helpers

    static func nintendo(_ platform: KroutonConsoleDisc.Platform, _ header: [UInt8], byteSize: Int64) -> KroutonConsoleDisc {
        let id = text(header, 0, 6)
        let regionLetter = id.flatMap { $0.count == 6 ? Array($0)[3] : nil }
        let region: String? = switch regionLetter {
        case "E"?: "North America"
        case "P"?: "Europe"
        case "J"?: "Japan"
        case "K"?: "Korea"
        default: nil
        }
        return disc(platform, id, text(header, 0x20, 0x60), region, canBurn: true, byteSize: byteSize,
                    advice: platform == .wii ? Advice.wii : Advice.gamecube)
    }

    /// Offset of the ISO 9660 primary volume descriptor in a 2,048-byte, raw Mode 1 or raw Mode 2 image.
    static func primaryVolumeDescriptor(_ header: [UInt8]) -> Int? {
        for offset in [0x8000, 16 * 2352 + 16, 16 * 2352 + 24] where match(header, at: offset, [0x01] + Array("CD001".utf8)) {
            return offset
        }
        return nil
    }

    static func match(_ bytes: [UInt8], at offset: Int, _ expected: [UInt8]) -> Bool {
        guard offset >= 0, bytes.count >= offset + expected.count else { return false }
        return Array(bytes[offset..<offset + expected.count]) == expected
    }

    static func find(_ bytes: [UInt8], _ needle: [UInt8]) -> Int? {
        guard let first = needle.first, bytes.count >= needle.count else { return nil }
        var index = 0
        while index <= bytes.count - needle.count {
            if bytes[index] == first, Array(bytes[index..<index + needle.count]) == needle { return index }
            index += 1
        }
        return nil
    }

    /// Printable ASCII from a fixed-width field, trimmed; nil when empty.
    static func text(_ bytes: [UInt8], _ offset: Int, _ length: Int) -> String? {
        guard offset >= 0, offset < bytes.count else { return nil }
        let field = bytes[offset..<min(bytes.count, offset + length)].prefix { $0 != 0 }
        let value = String(decoding: field.filter { $0 >= 0x20 && $0 < 0x7F }, as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    static func disc(_ platform: KroutonConsoleDisc.Platform, _ id: String?, _ title: String?, _ region: String?,
                     canBurn: Bool, byteSize: Int64, advice: String) -> KroutonConsoleDisc {
        KroutonConsoleDisc(platform: platform, gameID: id, title: title, region: region, canBurn: canBurn,
                           recommendedMedia: media(for: platform, byteSize: byteSize), advice: advice)
    }

    static func media(for platform: KroutonConsoleDisc.Platform, byteSize: Int64) -> String {
        switch platform {
        case .gamecube: return "8 cm mini DVD-R"
        case .playstation, .dreamcast, .saturn: return "CD-R (80-minute), burned slowly"
        default:
            if byteSize <= 737_280_000 { return "CD-R" }
            if byteSize <= 4_700_372_992 { return "DVD-R or DVD+R" }
            return "DVD+R DL"
        }
    }

    // MARK: - What Burning Does

    enum Advice {
        static let gamecube = "A GameCube only reads burned discs with a modchip. Burn to an 8 cm mini DVD-R; a full-size disc won't fit the tray. Without a chip, Swiss from an SD adapter plays backups instead."
        static let wii = "A Wii only reads burned discs with a modchip, and only on early drive models; later drives can't read DVD-R at all. For any Wii, USB Loader GX from a USB drive is the dependable way to play your own backups. On DVD+R, Krouton stamps the book type as DVD-ROM."
        static let playstation2 = "A PlayStation 2 reads burned DVDs with a modchip, or without one through Free McBoot and an ESR-patched disc (Krouton doesn't apply the ESR patch). Most people use Open PS2 Loader from USB instead."
        static let playstation = "A PlayStation reads burned CDs with a modchip, or through Unirom or FreePSXBoot (not on Japanese consoles). Burn the .cue/.bin as it is, at a low speed."
        static let dreamcast = "Dreamcasts made before late 2000 boot burned CD-Rs without a modchip, if the image is a self-booting MIL-CD."
        static let cdi = "This is a DiscJuggler .cdi image: two sessions, audio then data. Krouton can't burn .cdi yet."
        static let gdi = "A .gdi image is a GD-ROM, a 1 GB format no burner can write. Use it with an optical drive emulator such as GDEMU, or convert it to a self-booting .cdi with other tools."
        static let saturn = "A Saturn reads burned CDs only with a modchip or a Pseudo Saturn Kai cartridge. Burn the .cue/.bin as it is, at a low speed."
        static let xbox = "An original Xbox reads burned discs only with a modchip, and many drives are fussy about media. Most people copy games to the hard disk instead."
        static let unknown = "Krouton doesn't recognise this as a console disc image. It will be burned exactly as it is."
    }
}
