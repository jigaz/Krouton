import Foundation

// MARK: - DVD-Video Navigation Pack and IFO Relinker

/// One cell's new sector range after relinking.
public struct DVDVideoRelinkedCellRange: Sendable, Equatable {
    let vobID: UInt16
    /// The cell's number within its VOB.
    public let cellID: UInt8
    let startSector: UInt32
    let endSector: UInt32
}

/// The sizes of one title set after a shrink, in sectors.
public struct DVDVideoVTSLayout: Sendable, Equatable {
    let vtsNumber: Int
    let ifoSectors: UInt32
    /// The menu VOB's size.
    public let menuVobSectors: UInt32
    /// The title VOBs' size.
    public let titleVobSectors: UInt32
    var totalVTSSectors: UInt32 {
        (ifoSectors * 2) + menuVobSectors + titleVobSectors
    }
}

/// Rewrites the sector addresses in DVD-Video navigation packs and IFO tables after title VOBs
/// change size, and re-encodes title VOBs with ffmpeg for the DVD-9 to DVD-5 shrink.
public enum DVDVideoIFORelinker {
    static let sectorBytes = 2048
    /// Spec limit per VOB file: 1 GiB minus 32 KiB (524,272 sectors)
    static let maxSingleVOBBytes = 524_272 * 2048

    // MARK: - Big-Endian Helpers

    static func readUInt16BE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= bytes.count else { return 0 }
        return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }

    /// The big-endian `UInt32` at `offset`, or 0 when it runs past the end.
    public static func readUInt32BE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else { return 0 }
        return (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    /// Writes `value` big-endian at `offset`; does nothing when it would run past the end.
    public static func writeUInt16BE(_ value: UInt16, into bytes: inout [UInt8], at offset: Int) {
        guard offset >= 0, offset + 2 <= bytes.count else { return }
        bytes[offset] = UInt8((value >> 8) & 0xFF)
        bytes[offset + 1] = UInt8(value & 0xFF)
    }

    /// Writes `value` big-endian at `offset`; does nothing when it would run past the end.
    public static func writeUInt32BE(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        guard offset >= 0, offset + 4 <= bytes.count else { return }
        bytes[offset] = UInt8((value >> 24) & 0xFF)
        bytes[offset + 1] = UInt8((value >> 16) & 0xFF)
        bytes[offset + 2] = UInt8((value >> 8) & 0xFF)
        bytes[offset + 3] = UInt8(value & 0xFF)
    }

    // MARK: - Navigation Packs (NV_PCK)

    /// Returns true if the 2048-byte pack at `packOffset` is a DVD-Video NV_PCK (PCI + DSI).
    static func isNavigationPack(_ bytes: [UInt8], at packOffset: Int) -> Bool {
        guard packOffset + sectorBytes <= bytes.count else { return false }
        // MPEG-2 Pack start code 0x000001BA + System header 0x000001BB at +14 + Private Stream 2 (PCI) 0x000001BF at +38
        return bytes[packOffset] == 0x00 && bytes[packOffset + 1] == 0x00
            && bytes[packOffset + 2] == 0x01 && bytes[packOffset + 3] == 0xBA
            && bytes[packOffset + 38] == 0x00 && bytes[packOffset + 39] == 0x00
            && bytes[packOffset + 40] == 0x01 && bytes[packOffset + 41] == 0xBF
            && bytes[packOffset + 0x0400] == 0x00 && bytes[packOffset + 0x0401] == 0x00
            && bytes[packOffset + 0x0402] == 0x01 && bytes[packOffset + 0x0403] == 0xBF
    }

    /// Scans concatenated title VOB bytes (`VTS_xx_1..9.VOB`) and patches every `NV_PCK` DSI header
    /// (`nv_pck_lbn`, `vobu_ea`, reference frame bounds, and `VOBU_SRI` search pointers), returning
    /// the patched VOB data, VOBU start sector list, and contiguous `(vobID, cellID)` sector ranges.
    public static func scanAndPatchTitleVOBs(_ vobData: Data) -> (
        patchedData: Data,
        vobuStartSectors: [UInt32],
        cells: [DVDVideoRelinkedCellRange]
    ) {
        var bytes = [UInt8](vobData)
        let totalSectors = bytes.count / sectorBytes
        guard totalSectors > 0 else { return (vobData, [], []) }

        var navSectors: [UInt32] = []
        var navCellKeys: [(vobID: UInt16, cellID: UInt8)] = []

        for sector in 0..<totalSectors {
            let base = sector * sectorBytes
            if isNavigationPack(bytes, at: base) {
                navSectors.append(UInt32(sector))
                // DSI general info begins at 0x0407 (substream ID 0x01 at 0x0406):
                // +0x04 (0x040B): nv_pck_lbn, +0x18 (0x041F): vob_idn (2B), +0x1B (0x0422): vob_c_idn (1B)
                let vobID = max(1, readUInt16BE(bytes, at: base + 0x041F))
                let cellID = max(1, bytes[base + 0x0422])
                navCellKeys.append((vobID, cellID))
            }
        }

        // If ffmpeg produced raw VOB packs without NV_PCKs, synthesize a single cell covering 0..<totalSectors
        if navSectors.isEmpty {
            let endSec = UInt32(max(0, totalSectors - 1))
            return (vobData, [0], [DVDVideoRelinkedCellRange(vobID: 1, cellID: 1, startSector: 0, endSector: endSec)])
        }

        // Patch each NV_PCK's DSI block in place
        for idx in navSectors.indices {
            let startSec = navSectors[idx]
            let nextStartSec = (idx + 1 < navSectors.count) ? navSectors[idx + 1] : UInt32(totalSectors)
            let vobuLength = max(1, nextStartSec - startSec)
            let vobuEndOffset = vobuLength - 1
            let base = Int(startSec) * sectorBytes

            // dsi_nv_pck_lbn at 0x040B & pci_nv_pck_lbn at 0x002D
            writeUInt32BE(startSec, into: &bytes, at: base + 0x002D)
            writeUInt32BE(startSec, into: &bytes, at: base + 0x040B)
            // vobu_ea at 0x040F
            writeUInt32BE(vobuEndOffset, into: &bytes, at: base + 0x040F)
            // Clamp 1st/2nd/3rd reference frame end addresses (0x0413, 0x0417, 0x041B) inside vobuEndOffset
            for refOff in [0x0413, 0x0417, 0x041B] {
                let curRef = readUInt32BE(bytes, at: base + refOff)
                if curRef > vobuEndOffset {
                    writeUInt32BE(vobuEndOffset, into: &bytes, at: base + refOff)
                }
            }

            // Recompute VOBU_SRI (42 x 4B entries starting at 0x04F1: 21 forward + 21 backward)
            let stepOffsets = [240, 120, 60, 20, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
            // Forward Next VOBU with video (0x04F1) & Next VOBU (0x04F5)
            let fwd1 = (idx + 1 < navSectors.count) ? (0x8000_0000 | (navSectors[idx + 1] - startSec)) : 0x3FFF_FFFF
            writeUInt32BE(fwd1, into: &bytes, at: base + 0x04F1)
            writeUInt32BE(fwd1, into: &bytes, at: base + 0x04F5)
            for (sIdx, step) in stepOffsets.enumerated() {
                let targetIdx = idx + step
                let ptr = (targetIdx < navSectors.count) ? (0x8000_0000 | (navSectors[targetIdx] - startSec)) : 0x3FFF_FFFF
                writeUInt32BE(ptr, into: &bytes, at: base + 0x04F9 + (sIdx * 4))
            }
            // Backward entries starting at 0x0545
            let bwdBase = base + 0x0545
            for (sIdx, step) in stepOffsets.enumerated() {
                let targetIdx = idx - step
                let ptr = (targetIdx >= 0) ? (0x8000_0000 | (startSec - navSectors[targetIdx])) : 0x3FFF_FFFF
                writeUInt32BE(ptr, into: &bytes, at: bwdBase + (sIdx * 4))
            }
            let prev1 = (idx > 0) ? (0x8000_0000 | (startSec - navSectors[idx - 1])) : 0x3FFF_FFFF
            writeUInt32BE(prev1, into: &bytes, at: bwdBase + 19 * 4)
            writeUInt32BE(prev1, into: &bytes, at: bwdBase + 20 * 4)
        }

        // Group contiguous VOBUs by (vobID, cellID) into relinked cell ranges
        var cells: [DVDVideoRelinkedCellRange] = []
        for idx in navSectors.indices {
            let key = navCellKeys[idx]
            let startSec = navSectors[idx]
            let endSec = (idx + 1 < navSectors.count) ? (navSectors[idx + 1] - 1) : UInt32(totalSectors - 1)
            if let last = cells.last, last.vobID == key.vobID && last.cellID == key.cellID {
                cells[cells.count - 1] = DVDVideoRelinkedCellRange(
                    vobID: last.vobID,
                    cellID: last.cellID,
                    startSector: last.startSector,
                    endSector: endSec
                )
            } else {
                cells.append(DVDVideoRelinkedCellRange(
                    vobID: key.vobID,
                    cellID: key.cellID,
                    startSector: startSec,
                    endSector: endSec
                ))
            }
        }

        return (Data(bytes), navSectors, cells)
    }

    // MARK: - IFO Sector Tables

    /// Rebuilds `VTS_C_ADT`, `VTS_VOBU_ADMAP`, `VTS_PGCI` cell sector offsets, and `VTSI_MAT` pointers
    /// in a `VTS_xx_0.IFO` buffer (which is then written identically to both `.IFO` and `.BUP`).
    public static func relinkVTSIFO(
        ifoData: Data,
        menuVobSectors: UInt32,
        titleVobSectors: UInt32,
        vobuStartSectors: [UInt32],
        cells: [DVDVideoRelinkedCellRange]
    ) -> Data {
        var bytes = [UInt8](ifoData)
        guard bytes.count >= sectorBytes else { return ifoData }

        let oldIfoSectors = max(1, UInt32((bytes.count + sectorBytes - 1) / sectorBytes))

        // Build fresh VTS_C_ADT (8-byte header + 12 bytes per cell)
        let cAdtEntries = max(1, cells.count)
        let cAdtByteLen = 8 + (cAdtEntries * 12)
        let cAdtSectors = UInt32((cAdtByteLen + sectorBytes - 1) / sectorBytes)
        var cAdtBuf = [UInt8](repeating: 0, count: Int(cAdtSectors) * sectorBytes)
        let maxVobID = cells.map(\.vobID).max() ?? 1
        writeUInt16BE(maxVobID, into: &cAdtBuf, at: 0)
        writeUInt32BE(UInt32(cAdtByteLen - 1), into: &cAdtBuf, at: 4)
        for (idx, cell) in cells.enumerated() {
            let off = 8 + (idx * 12)
            writeUInt16BE(cell.vobID, into: &cAdtBuf, at: off)
            cAdtBuf[off + 2] = cell.cellID
            writeUInt32BE(cell.startSector, into: &cAdtBuf, at: off + 4)
            writeUInt32BE(cell.endSector, into: &cAdtBuf, at: off + 8)
        }

        // Build fresh VTS_VOBU_ADMAP (4-byte end address + 4 bytes per VOBU start sector)
        let admapCount = max(1, vobuStartSectors.count)
        let admapByteLen = 4 + (admapCount * 4)
        let admapSectors = UInt32((admapByteLen + sectorBytes - 1) / sectorBytes)
        var admapBuf = [UInt8](repeating: 0, count: Int(admapSectors) * sectorBytes)
        writeUInt32BE(UInt32(admapByteLen - 1), into: &admapBuf, at: 0)
        for (idx, sec) in vobuStartSectors.enumerated() {
            writeUInt32BE(sec, into: &admapBuf, at: 4 + (idx * 4))
        }

        // Preserve existing IFO prefix up to VTS_C_ADT (or full IFO if tables are compact)
        let existingCAdtSector = readUInt32BE(bytes, at: 0x00E0)
        let prefixSectors: UInt32 = (existingCAdtSector > 0 && existingCAdtSector < oldIfoSectors)
            ? existingCAdtSector
            : oldIfoSectors
        let prefixByteCount = Int(prefixSectors) * sectorBytes
        if bytes.count < prefixByteCount {
            bytes.append(contentsOf: repeatElement(0, count: prefixByteCount - bytes.count))
        } else if bytes.count > prefixByteCount {
            bytes.removeLast(bytes.count - prefixByteCount)
        }

        let newCAdtStartSector = prefixSectors
        let newAdmapStartSector = newCAdtStartSector + cAdtSectors
        let newIfoSectors = newAdmapStartSector + admapSectors

        bytes.append(contentsOf: cAdtBuf)
        bytes.append(contentsOf: admapBuf)

        // Update VTSI_MAT sector pointers
        let totalVTSSectors = (newIfoSectors * 2) + menuVobSectors + titleVobSectors
        writeUInt32BE(totalVTSSectors - 1, into: &bytes, at: 0x000C) // VTS_EA
        writeUInt32BE(newIfoSectors - 1, into: &bytes, at: 0x001C)   // VTSI_EA
        writeUInt32BE(menuVobSectors > 0 ? newIfoSectors : 0, into: &bytes, at: 0x00C0) // VTSM_VOBS
        writeUInt32BE(titleVobSectors > 0 ? (newIfoSectors + menuVobSectors) : 0, into: &bytes, at: 0x00C4) // VTSTT_VOBS
        writeUInt32BE(newCAdtStartSector, into: &bytes, at: 0x00E0)  // VTS_C_ADT
        writeUInt32BE(newAdmapStartSector, into: &bytes, at: 0x00E4) // VTS_VOBU_ADMAP

        // Update VTS_PGCITI cell playback & position entries + clear layer-break pause flag
        let pgcitiSector = readUInt32BE(bytes, at: 0x00CC)
        if pgcitiSector > 0 && Int(pgcitiSector) * sectorBytes + 8 <= bytes.count {
            let tableBase = Int(pgcitiSector) * sectorBytes
            let numPGCs = Int(readUInt16BE(bytes, at: tableBase))
            for pIdx in 0..<numPGCs {
                let entryOff = tableBase + 8 + (pIdx * 8)
                guard entryOff + 8 <= bytes.count else { break }
                let pgcRelOffset = Int(readUInt32BE(bytes, at: entryOff + 4))
                let pgcBase = tableBase + pgcRelOffset
                guard pgcBase + 0xEC <= bytes.count else { continue }

                let numCells = Int(bytes[pgcBase + 0x03])
                let cellPlaybackOff = pgcBase + Int(readUInt16BE(bytes, at: pgcBase + 0xE8))
                let cellPosOff = pgcBase + Int(readUInt16BE(bytes, at: pgcBase + 0xEA))

                for cIdx in 0..<numCells {
                    let pb = cellPlaybackOff + (cIdx * 24)
                    let pos = cellPosOff + (cIdx * 4)
                    guard pb + 24 <= bytes.count else { break }

                    // Clear Dual-Layer STC_discontinuity / pause bit (0x08) and set seamless playback (0x02)
                    bytes[pb] = (bytes[pb] & ~0x08) | 0x02

                    let targetVobID: UInt16
                    let targetCellID: UInt8
                    if pos + 4 <= bytes.count {
                        targetVobID = max(1, readUInt16BE(bytes, at: pos))
                        targetCellID = max(1, bytes[pos + 3])
                    } else if cIdx < cells.count {
                        targetVobID = cells[cIdx].vobID
                        targetCellID = cells[cIdx].cellID
                    } else {
                        continue
                    }

                    if let matched = cells.first(where: { $0.vobID == targetVobID && $0.cellID == targetCellID })
                        ?? (cIdx < cells.count ? cells[cIdx] : nil) {
                        writeUInt32BE(matched.startSector, into: &bytes, at: pb + 0x08) // firstVOBUStart
                        writeUInt32BE(matched.endSector, into: &bytes, at: pb + 0x0C)   // firstILVUEnd
                        writeUInt32BE(matched.startSector, into: &bytes, at: pb + 0x10) // lastVOBUStart
                        writeUInt32BE(matched.endSector, into: &bytes, at: pb + 0x14)   // lastVOBUEnd
                    }
                }
            }
        }

        return Data(bytes)
    }

    /// Updates `VIDEO_TS.IFO` (`VMG_EA` and `TT_SRPT` `VTS_N_SA` start sectors) to match the relinked VTS sizes.
    static func relinkVideoManagerIFO(
        vmgIfoData: Data,
        vmgMenuVobSectors: UInt32,
        vtsLayouts: [DVDVideoVTSLayout]
    ) -> Data {
        var bytes = [UInt8](vmgIfoData)
        guard bytes.count >= sectorBytes else { return vmgIfoData }

        let vmgIfoSectors = UInt32((bytes.count + sectorBytes - 1) / sectorBytes)
        var vtsStartSectorByNumber: [Int: UInt32] = [:]
        var cursorSector = (vmgIfoSectors * 2) + vmgMenuVobSectors

        for layout in vtsLayouts.sorted(by: { $0.vtsNumber < $1.vtsNumber }) {
            vtsStartSectorByNumber[layout.vtsNumber] = cursorSector
            cursorSector += layout.totalVTSSectors
        }

        let totalVolumeSectors = max(cursorSector, vmgIfoSectors)
        writeUInt32BE(totalVolumeSectors - 1, into: &bytes, at: 0x000C) // VMG_EA
        writeUInt32BE(vmgMenuVobSectors > 0 ? vmgIfoSectors : 0, into: &bytes, at: 0x00C0) // VMGM_VOBS

        let ttSrptSector = readUInt32BE(bytes, at: 0x00C4)
        if ttSrptSector > 0 && Int(ttSrptSector) * sectorBytes + 8 <= bytes.count {
            let tableBase = Int(ttSrptSector) * sectorBytes
            let numTitles = Int(readUInt16BE(bytes, at: tableBase))
            for tIdx in 0..<numTitles {
                let entryOff = tableBase + 8 + (tIdx * 12)
                guard entryOff + 12 <= bytes.count else { break }
                let vtsNum = Int(bytes[entryOff + 6])
                if let startSec = vtsStartSectorByNumber[vtsNum] {
                    writeUInt32BE(startSec, into: &bytes, at: entryOff + 8) // VTS_N_SA
                }
            }
        }

        return Data(bytes)
    }

    // MARK: - ffmpeg Re-encode

    static func locateFFmpegExecutable() -> URL? {
        for candidate in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    /// Re-encodes concatenated title VOBs to `targetVideoKbps` MPEG-2 (`-f dvd`) while stream-copying
    /// all audio (`AC-3`, `DTS`, `LPCM`) and subpicture (`dvd_subtitle`) streams untouched.
    static func transcodeTitleVOBsToDVD5Bitrate(
        ffmpegURL: URL,
        inputVOBFiles: [URL],
        outputCombinedVOBURL: URL,
        targetVideoKbps: Int
    ) throws {
        let clampedKbps = max(1_400, min(8_500, targetVideoKbps))
        let concatArg = "concat:" + inputVOBFiles.map(\.path).joined(separator: "|")
        let proc = Process()
        proc.executableURL = ffmpegURL
        proc.arguments = [
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-i", concatArg,
            "-map", "0:v:0",
            "-map", "0:a?",
            "-map", "0:s?",
            "-c:v", "mpeg2video",
            "-b:v", "\(clampedKbps)k",
            "-maxrate", "9000k",
            "-bufsize", "1835k",
            "-g", "15",
            "-bf", "2",
            "-c:a", "copy",
            "-c:s", "copy",
            // The "dvd" muxer (not "vob") writes the NV_PCK navigation packs every VOBU needs,
            // which scanAndPatchTitleVOBs then fills in; 2048-byte packs at DVD's mux rate.
            "-f", "dvd",
            "-muxrate", "10080000",
            "-packetsize", "2048",
            outputCombinedVOBURL.path
        ]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw KroutonVideoShrinkError.transcodeFailed(exitCode: proc.terminationStatus)
        }
    }
}
