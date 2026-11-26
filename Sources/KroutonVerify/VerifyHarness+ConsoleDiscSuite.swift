import Foundation
import OpticalCore

// MARK: - VerifyHarness — Suite 35: Console Disc Identification

extension KroutonTestHarness {
    mutating func runVerifyConsoleDiscSuite() {
        self.runSuite("35. Console Discs: Identified From Their Own Headers, With Honest Burn Advice") { h in
            func header(_ edits: [(Int, [UInt8])]) -> [UInt8] {
                var bytes = [UInt8](repeating: 0, count: KroutonConsoleDiscIdentifier.headerLength)
                for (offset, value) in edits { bytes.replaceSubrange(offset..<offset + value.count, with: value) }
                return bytes
            }
            let ascii = { (text: String) in Array(text.utf8) }

            let gc = KroutonConsoleDiscIdentifier.identify(
                header: header([(0, ascii("GALE01")), (0x1C, [0xC2, 0x33, 0x9F, 0x3D]), (0x20, ascii("Super Smash Bros Melee"))]),
                fileExtension: "iso", byteSize: 1_459_978_240)
            h.lint(gc.platform == .gamecube && gc.gameID == "GALE01" && gc.title == "Super Smash Bros Melee",
                   "A GameCube header must give its game ID and title (\(gc))")
            h.lint(gc.region == "North America" && gc.recommendedMedia.contains("mini DVD"), "GameCube: region from the ID, 8 cm media")

            let wii = KroutonConsoleDiscIdentifier.identify(
                header: header([(0, ascii("RMCP01")), (0x18, [0x5D, 0x1C, 0x9E, 0xA3]), (0x20, ascii("Mario Kart Wii"))]),
                fileExtension: "iso", byteSize: 4_699_979_776)
            h.lint(wii.platform == .wii && wii.region == "Europe" && wii.advice.contains("modchip"),
                   "A Wii header must be recognised, with the modchip caveat")

            let xbox = KroutonConsoleDiscIdentifier.identify(header: header([(0x10000, ascii("MICROSOFT*XBOX*MEDIA"))]),
                                                            fileExtension: "iso", byteSize: 7_000_000_000)
            h.lint(xbox.platform == .xbox && xbox.recommendedMedia == "DVD+R DL", "An XISO must be recognised and need a dual-layer blank")

            let ipBin = 16
            let dreamcastHeader = header([(ipBin, ascii("SEGA SEGAKATANA")), (ipBin + 0x40, ascii("T-8101N   ")),
                                          (ipBin + 0x80, ascii("HOMEBREW DEMO"))])
            let cdi = KroutonConsoleDiscIdentifier.identify(header: dreamcastHeader, fileExtension: "cdi", byteSize: 700_000_000)
            let bin = KroutonConsoleDiscIdentifier.identify(header: dreamcastHeader, fileExtension: "bin", byteSize: 700_000_000)
            h.lint(cdi.platform == .dreamcast && cdi.gameID == "T-8101N" && cdi.title == "HOMEBREW DEMO",
                   "A Dreamcast IP.BIN must give the product number and title")
            h.lint(cdi.canBurn && bin.canBurn, "A Dreamcast .cdi and .cue/.bin must both be burnable")

            // A DiscJuggler 3 descriptor: 302 frames of audio, then Mode 2 data at 11,702.
            func cdiTrack(pregap: UInt32, frames: UInt32, mode: UInt32, start: UInt32, sizeCode: UInt32) -> [UInt8] {
                let le = { (v: UInt32) in [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 24)] }
                let mark: [UInt8] = [0, 0, 1, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF]
                var t = le(0) + mark + mark + [UInt8](repeating: 0, count: 4) + [5] + ascii("a.cdi")
                t += [UInt8](repeating: 0, count: 19) + le(0) + [0, 0] + le(pregap) + le(frames)
                t += [UInt8](repeating: 0, count: 6) + le(mode) + [UInt8](repeating: 0, count: 12) + le(start) + le(pregap + frames)
                t += [UInt8](repeating: 0, count: 16) + le(sizeCode) + [UInt8](repeating: 0, count: 29 + 5) + le(0)
                return t
            }
            func cdiDescriptor(dataStart: UInt32) -> [UInt8] {
                let end = [UInt8](repeating: 0, count: 13)
                return [2, 0] + [1, 0] + cdiTrack(pregap: 150, frames: 302, mode: 0, start: 0, sizeCode: 2) + end
                    + [1, 0] + cdiTrack(pregap: 150, frames: 1_000, mode: 2, start: dataStart, sizeCode: 1) + end
            }
            let image = try? KroutonDiscJugglerImage.parse(descriptor: cdiDescriptor(dataStart: 11_702),
                                                           version: KroutonDiscJugglerImage.version3, fileLength: 10_000_000)
            let plan = try? image?.audioDataPlan()
            h.lint(plan?.audio.count == 1 && plan?.data.startLBA == 11_702 && plan?.data.fileOffset == Int64(452 * 2352 + 150 * 2336)
                   && plan?.data.userDataOffset == 8, "An audio/data .cdi must give its tracks, file offsets and a burn plan")
            let misplaced = try? KroutonDiscJugglerImage.parse(descriptor: cdiDescriptor(dataStart: 11_700),
                                                               version: KroutonDiscJugglerImage.version3, fileLength: 10_000_000)
            h.lint(misplaced != nil && (try? misplaced?.audioDataPlan()) == nil,
                   "A .cdi whose data wouldn't land where it was mastered must be refused")

            let playstationField = ascii("PLAYSTATION") + [UInt8](repeating: 0x20, count: 21)
            let ps1 = KroutonConsoleDiscIdentifier.identify(
                header: header([(16 * 2352 + 24, [0x01] + ascii("CD001")), (16 * 2352 + 24 + 8, playstationField),
                                (16 * 2352 + 24 + 40, ascii("SLUS_000.01"))]),
                fileExtension: "bin", byteSize: 650_000_000)
            h.lint(ps1.platform == .playstation && ps1.title == "SLUS_000.01", "A raw Mode 2 PlayStation CD must be found by its PVD")
            let ps2 = KroutonConsoleDiscIdentifier.identify(
                header: header([(0x8000, [0x01] + ascii("CD001")), (0x8008, playstationField)]),
                fileExtension: "iso", byteSize: 4_200_000_000)
            h.lint(ps2.platform == .playstation2 && ps2.advice.contains("Open PS2 Loader"), "A DVD-sized PlayStation image must be PS2")

            let gdi = KroutonConsoleDiscIdentifier.identify(header: [], fileExtension: "gdi", byteSize: 0)
            h.lint(!gdi.canBurn && gdi.platform == .dreamcast, "A .gdi (GD-ROM) must be refused for burning")
            let plain = KroutonConsoleDiscIdentifier.identify(header: header([]), fileExtension: "iso", byteSize: 100_000)
            h.lint(plain.platform == .unknown && plain.canBurn, "An ordinary image must pass through as unknown")

            h.lint(KroutonConsoleDiscIdentifier.firstBinary(inCue: "REM x\nFILE \"Game (Track 1).bin\" BINARY\n  TRACK 01 MODE2/2352\n")
                   == "Game (Track 1).bin", "The first FILE of a cue sheet must be found, spaces and all")
        }
    }
}
