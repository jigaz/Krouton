import Foundation

// MARK: - DVD-Video Without Menus: Play Every Title in Order

/// What `DVDVideoPlayAllNavigation.convert` did to a `VIDEO_TS` folder.
public struct DVDVideoPlayAllResult: Sendable, Equatable {
    /// Title numbers (as on the disc) in the order the new disc plays them.
    public let playOrder: [Int]
    /// Titles left out of the order because they are shorter than the threshold (blank or
    /// placeholder titles many discs carry).
    public let skippedShortTitles: [Int]
    /// Titles whose program chain had no command slot to continue from; the player stops after them.
    public let titlesThatStop: [Int]
    /// Bytes of menu video removed.
    public let removedMenuBytes: Int64
}

enum DVDVideoPlayAllError: Error, LocalizedError, Sendable, Equatable {
    case notAVideoTSFolder
    case noPlayableTitles

    public var errorDescription: String? {
        switch self {
        case .notAVideoTSFolder: return "The folder has no VIDEO_TS.IFO, so it isn't a DVD-Video folder."
        case .noPlayableTitles: return "The disc has no title long enough to play without its menus."
        }
    }
}

/// Removes a DVD-Video's menus and rewires its navigation so the disc starts playing title 1 at
/// once and goes on to each following title, then stops.
///
/// How: the first-play program chain jumps to the first title; the VMG gets a small menu domain
/// of command-only chains (no video), one per step, each jumping to the next title; and in every
/// title, a command that would have gone to a menu or ended playback now calls the next step.
/// Conditions on rewritten commands are kept. Menu VOBs are deleted and every sector address that
/// depends on them is recomputed. Video, audio and subtitles are untouched.
public enum DVDVideoPlayAllNavigation {
    static let sector = DVDVideoIFORelinker.sectorBytes
    static let pgcHeaderBytes = 0xEC

    /// Rewrites `videoTSDirectory` in place.
    @discardableResult
    public static func convert(videoTSDirectory: URL, minimumTitleSeconds: Double = 5) throws -> DVDVideoPlayAllResult {
        let fm = FileManager.default
        let vmgURL = videoTSDirectory.appendingPathComponent("VIDEO_TS.IFO")
        guard var vmg = try? [UInt8](Data(contentsOf: vmgURL)), vmg.count >= sector else {
            throw DVDVideoPlayAllError.notAVideoTSFolder
        }
        let titles = titleTable(vmg)

        // Read each title set and learn how long each title runs.
        var vtsData: [Int: [UInt8]] = [:]
        for vts in Set(titles.map(\.vts)) {
            let url = videoTSDirectory.appendingPathComponent(String(format: "VTS_%02d_0.IFO", vts))
            if let data = try? Data(contentsOf: url), data.count >= sector { vtsData[vts] = [UInt8](data) }
        }
        var playOrder: [Int] = []
        var skipped: [Int] = []
        for title in titles {
            guard let bytes = vtsData[title.vts], titleSectors(in: videoTSDirectory, vts: title.vts) > 0 else { continue }
            if titleSeconds(bytes, ttn: title.ttn) < minimumTitleSeconds {
                skipped.append(title.number)
            } else {
                playOrder.append(title.number)
            }
        }
        guard !playOrder.isEmpty else { throw DVDVideoPlayAllError.noPlayableTitles }

        // Step pgcn: VMGM PGC 1 starts the disc again (it is also the title menu); PGC i + 2 runs
        // after the i-th title in the order. A title outside the order goes back to the start.
        let indexOf = Dictionary(uniqueKeysWithValues: playOrder.enumerated().map { ($1, $0) })
        var titlesThatStop: [Int] = []
        for (vts, original) in vtsData {
            var bytes = original
            let stepByTTN = Dictionary(titles.filter { $0.vts == vts }.map { title in
                (title.ttn, UInt16(indexOf[title.number].map { $0 + 2 } ?? 1))
            }, uniquingKeysWith: { first, _ in first })
            let stopping = rewriteTitleChains(&bytes, stepByTTN: stepByTTN)
            titlesThatStop += titles.filter { $0.vts == vts && stopping.contains($0.ttn) && indexOf[$0.number] != nil }.map(\.number)
            removeMenuDomain(fromVTS: &bytes, titleSectors: titleSectors(in: videoTSDirectory, vts: vts))
            vtsData[vts] = bytes
        }

        writeFirstPlay(&vmg, jumpTo: playOrder[0])
        appendStepMenus(&vmg, playOrder: playOrder)

        // Menus go; then every address that counted them is recomputed.
        var removed: Int64 = 0
        for name in try fm.contentsOfDirectory(atPath: videoTSDirectory.path) {
            let upper = name.uppercased()
            guard upper == "VIDEO_TS.VOB" || (upper.hasPrefix("VTS_") && upper.hasSuffix("_0.VOB")) else { continue }
            let url = videoTSDirectory.appendingPathComponent(name)
            removed += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try fm.removeItem(at: url)
        }
        var layouts: [DVDVideoVTSLayout] = []
        for (vts, bytes) in vtsData.sorted(by: { $0.key < $1.key }) {
            let prefix = String(format: "VTS_%02d_0", vts)
            try Data(bytes).write(to: videoTSDirectory.appendingPathComponent("\(prefix).IFO"))
            try Data(bytes).write(to: videoTSDirectory.appendingPathComponent("\(prefix).BUP"))
            layouts.append(DVDVideoVTSLayout(vtsNumber: vts, ifoSectors: UInt32(bytes.count / sector), menuVobSectors: 0,
                                             titleVobSectors: titleSectors(in: videoTSDirectory, vts: vts)))
        }
        let relinked = DVDVideoIFORelinker.relinkVideoManagerIFO(vmgIfoData: Data(vmg), vmgMenuVobSectors: 0, vtsLayouts: layouts)
        try relinked.write(to: vmgURL)
        try relinked.write(to: videoTSDirectory.appendingPathComponent("VIDEO_TS.BUP"))

        return DVDVideoPlayAllResult(playOrder: playOrder, skippedShortTitles: skipped,
                                     titlesThatStop: titlesThatStop.sorted(), removedMenuBytes: removed)
    }

    // MARK: - Title Table

    struct Title: Equatable {
        let number: Int
        let vts: Int
        let ttn: Int
    }

    /// TT_SRPT, in title-number order.
    static func titleTable(_ vmg: [UInt8]) -> [Title] {
        let base = Int(DVDVideoIFORelinker.readUInt32BE(vmg, at: 0xC4)) * sector
        guard base > 0, base + 8 <= vmg.count else { return [] }
        let count = Int(DVDVideoIFORelinker.readUInt16BE(vmg, at: base))
        return (0..<count).compactMap { index in
            let entry = base + 8 + index * 12
            guard entry + 12 <= vmg.count, vmg[entry + 6] > 0, vmg[entry + 7] > 0 else { return nil }
            return Title(number: index + 1, vts: Int(vmg[entry + 6]), ttn: Int(vmg[entry + 7]))
        }
    }

    static func titleSectors(in folder: URL, vts: Int) -> UInt32 {
        (1...9).reduce(UInt32(0)) { total, part in
            let url = folder.appendingPathComponent(String(format: "VTS_%02d_%d.VOB", vts, part))
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + UInt32((bytes + sector - 1) / sector)
        }
    }

    // MARK: - Program Chains

    /// Byte offsets of the PGCs in VTS_PGCI with the VTS title number each belongs to.
    static func titleChains(_ vts: [UInt8]) -> [(ttn: Int, offset: Int)] {
        let base = Int(DVDVideoIFORelinker.readUInt32BE(vts, at: 0xCC)) * sector
        guard base > 0, base + 8 <= vts.count else { return [] }
        let count = Int(DVDVideoIFORelinker.readUInt16BE(vts, at: base))
        return (0..<count).compactMap { index in
            let entry = base + 8 + index * 8
            guard entry + 8 <= vts.count else { return nil }
            let offset = base + Int(DVDVideoIFORelinker.readUInt32BE(vts, at: entry + 4))
            guard offset + pgcHeaderBytes <= vts.count else { return nil }
            return (Int(vts[entry] & 0x7F), offset)
        }
    }

    /// Seconds in the PGC playback time (BCD hours, minutes, seconds, frames).
    static func titleSeconds(_ vts: [UInt8], ttn: Int) -> Double {
        titleChains(vts).filter { $0.ttn == ttn }.reduce(0) { total, chain in
            func bcd(_ byte: UInt8) -> Double { Double((byte >> 4) * 10 + (byte & 0x0F)) }
            let time = chain.offset + 4
            let frames = vts[time + 3] & 0x3F
            let rate: Double = (vts[time + 3] >> 6) == 3 ? 30 : 25
            return total + bcd(vts[time]) * 3600 + bcd(vts[time + 1]) * 60 + bcd(vts[time + 2]) + bcd(frames) / rate
        }
    }

    /// The command table of the PGC at `pgc`: where its pre, post and cell commands start.
    static func commandTable(_ bytes: [UInt8], pgc: Int) -> (pre: Range<Int>, post: Range<Int>, cell: Range<Int>)? {
        let relative = Int(DVDVideoIFORelinker.readUInt16BE(bytes, at: pgc + 0xE4))
        guard relative > 0, pgc + relative + 8 <= bytes.count else { return nil }
        let table = pgc + relative
        let pre = Int(DVDVideoIFORelinker.readUInt16BE(bytes, at: table))
        let post = Int(DVDVideoIFORelinker.readUInt16BE(bytes, at: table + 2))
        let cell = Int(DVDVideoIFORelinker.readUInt16BE(bytes, at: table + 4))
        let first = table + 8
        guard first + (pre + post + cell) * 8 <= bytes.count else { return nil }
        return (first..<first + pre * 8, first + pre * 8..<first + (pre + post) * 8,
                first + (pre + post) * 8..<first + (pre + post + cell) * 8)
    }

    /// In every title PGC: a menu call or jump before or during playback is dropped; at the end, a
    /// menu call, a jump to another title or an exit becomes a call to the title's next step. A
    /// chain end with nothing to rewrite gets the call in a free slot. Returns the titles that
    /// had no slot for it.
    static func rewriteTitleChains(_ bytes: inout [UInt8], stepByTTN: [Int: UInt16]) -> Set<Int> {
        var stopping = Set<Int>()
        for chain in titleChains(bytes) {
            let step = stepByTTN[chain.ttn] ?? 1
            guard let table = commandTable(bytes, pgc: chain.offset) else {
                if DVDVideoIFORelinker.readUInt16BE(bytes, at: chain.offset + 0x9C) == 0 { stopping.insert(chain.ttn) }
                continue
            }
            let beforeTheEnd = Array(stride(from: table.pre.lowerBound, to: table.pre.upperBound, by: 8))
                + Array(stride(from: table.cell.lowerBound, to: table.cell.upperBound, by: 8))
            for start in beforeTheEnd where VMCommand(bytes, at: start).leavesTheTitle {
                bytes.replaceSubrange(start..<start + 8, with: VMCommand.nop)
            }
            var continues = false
            for start in stride(from: table.post.lowerBound, to: table.post.upperBound, by: 8) {
                let command = VMCommand(bytes, at: start)
                if command.leavesTheTitle || command.isExit {
                    bytes.replaceSubrange(start..<start + 8, with: command.callingStep(step))
                    continues = true
                } else if command.isLink {
                    continues = true
                }
            }
            let isChainEnd = DVDVideoIFORelinker.readUInt16BE(bytes, at: chain.offset + 0x9C) == 0
            guard isChainEnd, !continues else { continue }
            let slots = Array(stride(from: table.post.lowerBound, to: table.post.upperBound, by: 8))
            if let free = slots.first(where: { VMCommand(bytes, at: $0).isNOP }) ?? slots.last {
                bytes.replaceSubrange(free..<free + 8, with: VMCommand(VMCommand.nop).callingStep(step))
            } else {
                stopping.insert(chain.ttn)
            }
        }
        return stopping
    }

    // MARK: - Title Set Without Menus

    static func removeMenuDomain(fromVTS bytes: inout [UInt8], titleSectors: UInt32) {
        let ifoSectors = UInt32(bytes.count / sector)
        for pointer in [0xC0, 0xD0, 0xD8, 0xDC] {          // VTSM_VOBS, VTSM_PGCI_UT, VTSM_C_ADT, VTSM_VOBU_ADMAP
            DVDVideoIFORelinker.writeUInt32BE(0, into: &bytes, at: pointer)
        }
        DVDVideoIFORelinker.writeUInt32BE(titleSectors > 0 ? ifoSectors : 0, into: &bytes, at: 0xC4) // VTSTT_VOBS
        DVDVideoIFORelinker.writeUInt32BE(ifoSectors * 2 + titleSectors - 1, into: &bytes, at: 0x0C)  // VTS_EA
        DVDVideoIFORelinker.writeUInt32BE(ifoSectors - 1, into: &bytes, at: 0x1C)                     // VTSI_EA
    }

    // MARK: - Video Manager

    /// A fresh first-play PGC at 0x400, the space after VMGI_MAT that sector 0 keeps for it.
    static func writeFirstPlay(_ vmg: inout [UInt8], jumpTo title: Int) {
        let chain = commandOnlyPGC([VMCommand.jumpTT(title)])
        vmg.replaceSubrange(0x400..<0x800, with: chain + [UInt8](repeating: 0, count: 0x400 - chain.count))
        DVDVideoIFORelinker.writeUInt32BE(0x400, into: &vmg, at: 0x84) // FP_PGC
    }

    /// A VMGM_PGCI_UT of command-only PGCs, appended in new sectors; the old menus' tables stay
    /// in the file but nothing points to them.
    static func appendStepMenus(_ vmg: inout [UInt8], playOrder: [Int]) {
        var steps = [[VMCommand.jumpTT(playOrder[0])]]
        steps += playOrder.indices.map { index in
            index + 1 < playOrder.count ? [VMCommand.jumpTT(playOrder[index + 1])] : [VMCommand.exit]
        }
        let chains = steps.map(commandOnlyPGC)

        var unit = [UInt8](repeating: 0, count: 8 + chains.count * 8)  // VMGM_LU
        DVDVideoIFORelinker.writeUInt16BE(UInt16(chains.count), into: &unit, at: 0)
        for (index, chain) in chains.enumerated() {
            let pointer = 8 + index * 8
            unit[pointer] = index == 0 ? 0x82 : 0x00                   // entry PGC, title menu
            DVDVideoIFORelinker.writeUInt32BE(UInt32(unit.count), into: &unit, at: pointer + 4)
            unit += chain
        }
        DVDVideoIFORelinker.writeUInt32BE(UInt32(unit.count - 1), into: &unit, at: 4)

        var table = [UInt8](repeating: 0, count: 16)                    // VMGM_PGCI_UT, one language unit
        DVDVideoIFORelinker.writeUInt16BE(1, into: &table, at: 0)
        table[8] = 0x65; table[9] = 0x6E                               // "en"
        table[11] = 0x80                                               // has a title menu
        DVDVideoIFORelinker.writeUInt32BE(16, into: &table, at: 12)
        table += unit
        DVDVideoIFORelinker.writeUInt32BE(UInt32(table.count - 1), into: &table, at: 4)

        let start = (vmg.count + sector - 1) / sector
        vmg += [UInt8](repeating: 0, count: start * sector - vmg.count)
        vmg += table + [UInt8](repeating: 0, count: (sector - table.count % sector) % sector)
        for pointer in [0xC0, 0xD8, 0xDC] {                             // VMGM_VOBS, VMGM_C_ADT, VMGM_VOBU_ADMAP
            DVDVideoIFORelinker.writeUInt32BE(0, into: &vmg, at: pointer)
        }
        DVDVideoIFORelinker.writeUInt32BE(UInt32(start), into: &vmg, at: 0xC8)            // VMGM_PGCI_UT
        DVDVideoIFORelinker.writeUInt32BE(UInt32(vmg.count / sector - 1), into: &vmg, at: 0x1C) // VMGI_EA
    }

    /// A PGC with no programs or cells whose pre-commands are `commands`.
    static func commandOnlyPGC(_ commands: [[UInt8]]) -> [UInt8] {
        var chain = [UInt8](repeating: 0, count: pgcHeaderBytes + 8)
        DVDVideoIFORelinker.writeUInt16BE(UInt16(pgcHeaderBytes), into: &chain, at: 0xE4)
        DVDVideoIFORelinker.writeUInt16BE(UInt16(commands.count), into: &chain, at: pgcHeaderBytes)
        DVDVideoIFORelinker.writeUInt16BE(UInt16(8 + commands.count * 8 - 1), into: &chain, at: pgcHeaderBytes + 6)
        return chain + commands.flatMap { $0 }
    }
}

// MARK: - VM Commands

/// One 8-byte navigation command, read only as far as this rewrite needs.
struct VMCommand {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) { self.bytes = bytes }
    init(_ table: [UInt8], at offset: Int) { bytes = Array(table[offset..<offset + 8]) }

    static let nop = [UInt8](repeating: 0, count: 8)
    static let exit: [UInt8] = [0x30, 0x01, 0, 0, 0, 0, 0, 0]
    static func jumpTT(_ title: Int) -> [UInt8] { [0x30, 0x02, 0, 0, 0, UInt8(title & 0x7F), 0, 0] }

    /// Type 1 with the jump bit set: Exit, JumpTT, JumpVTS_TT/PTT, JumpSS, CallSS.
    private var jumpCode: UInt8? { (bytes[0] & 0xF0) == 0x30 ? bytes[1] & 0x0F : nil }

    var isNOP: Bool { bytes == Self.nop }
    var isExit: Bool { jumpCode == 1 }
    /// To a menu or first play (JumpSS, CallSS), or to another title (JumpTT, JumpVTS_TT/PTT).
    var leavesTheTitle: Bool { [2, 3, 5, 6, 8].contains(jumpCode ?? 0) }
    /// LinkPGCN, LinkPTTN, LinkPGN, LinkCN or a link subset: the title carries on within itself.
    var isLink: Bool { (bytes[0] & 0xF0) == 0x20 && [1, 4, 5, 6, 7].contains(bytes[1] & 0x0F) }

    /// `CallSS VMGM pgcn` under the same condition this command had (the compare op in byte 1's
    /// high bits and the operands in bytes 0 and 6–7 are kept).
    func callingStep(_ pgcn: UInt16) -> [UInt8] {
        let conditional = isNOP ? [UInt8](repeating: 0, count: 8) : bytes
        return [0x30 | (conditional[0] & 0x0F), (conditional[1] & 0xF0) | 0x08,
                UInt8(pgcn >> 8), UInt8(pgcn & 0xFF), 0, 0xC0, conditional[6], conditional[7]]
    }
}
