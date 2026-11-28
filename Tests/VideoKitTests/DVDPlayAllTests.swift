#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import VideoKit

// MARK: - A Small DVD-Video Built Byte by Byte

private let sector = 2048

private func put32(_ value: Int, _ bytes: inout [UInt8], _ at: Int) {
    for shift in 0..<4 { bytes[at + shift] = UInt8((value >> (8 * (3 - shift))) & 0xFF) }
}

private func put16(_ value: Int, _ bytes: inout [UInt8], _ at: Int) {
    bytes[at] = UInt8(value >> 8); bytes[at + 1] = UInt8(value & 0xFF)
}

private func get32(_ bytes: [UInt8], _ at: Int) -> Int {
    (0..<4).reduce(0) { ($0 << 8) | Int(bytes[at + $1]) }
}

/// A title PGC lasting `time` (BCD h, m, s) with the given commands.
private func pgc(time: [UInt8], pre: [[UInt8]] = [], post: [[UInt8]] = [], cell: [[UInt8]] = []) -> [UInt8] {
    var chain = [UInt8](repeating: 0, count: 0xEC + 8)
    chain[4] = time[0]; chain[5] = time[1]; chain[6] = time[2]; chain[7] = 0xC0
    put16(0xEC, &chain, 0xE4)
    put16(pre.count, &chain, 0xEC); put16(post.count, &chain, 0xEE); put16(cell.count, &chain, 0xF0)
    put16(8 + (pre.count + post.count + cell.count) * 8 - 1, &chain, 0xF2)
    return chain + (pre + post + cell).flatMap { $0 }
}

/// A two-sector VTS IFO whose VTS_PGCI (sector 1) holds `chains`, one per title number in order.
private func vtsIFO(_ chains: [[UInt8]]) -> [UInt8] {
    var ifo = [UInt8](repeating: 0, count: 2 * sector)
    put32(1, &ifo, 0xC0)                                  // a menu VOB, to be removed
    put32(1, &ifo, 0xD0)
    put32(1, &ifo, 0xCC)
    var table = [UInt8](repeating: 0, count: 8 + chains.count * 8)
    put16(chains.count, &table, 0)
    for (index, chain) in chains.enumerated() {
        table[8 + index * 8] = 0x80 | UInt8(index + 1)
        put32(table.count, &table, 8 + index * 8 + 4)
        table += chain
    }
    ifo.replaceSubrange(sector..<sector + table.count, with: table)
    return ifo
}

private let callMenu: [UInt8] = [0x30, 0x08, 0, 0, 0, 0x40, 0, 0]           // CallSS VMGM menu
private let conditionalCall: [UInt8] = [0x30, 0xA8, 0, 9, 0, 0xC0, 0x00, 0x05] // if … CallSS VMGM pgcn 9
private let exitCommand: [UInt8] = [0x30, 0x01, 0, 0, 0, 0, 0, 0]
private let setGPRM: [UInt8] = [0x71, 0x00, 0x00, 0x01, 0x00, 0x02, 0, 0]       // gprm1 = 2

// MARK: - Tests

final class DVDPlayAllTests: XCTestCase {
    private func makeDisc() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DVDPlayAll_\(UUID().uuidString)/VIDEO_TS")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var vmg = [UInt8](repeating: 0, count: 3 * sector)
        put32(1, &vmg, 0xC0)                               // VMGM_VOBS
        put32(1, &vmg, 0xC4)                               // TT_SRPT at sector 1
        put16(3, &vmg, sector)
        for (index, entry) in [(1, 1), (1, 2), (2, 1)].enumerated() {
            vmg[sector + 8 + index * 12 + 6] = UInt8(entry.0)
            vmg[sector + 8 + index * 12 + 7] = UInt8(entry.1)
        }
        func write(_ bytes: [UInt8], _ name: String) throws { try Data(bytes).write(to: folder.appendingPathComponent(name)) }
        try write(vmg, "VIDEO_TS.IFO"); try write(vmg, "VIDEO_TS.BUP")
        try write([UInt8](repeating: 0, count: 2 * sector), "VIDEO_TS.VOB")
        let feature = pgc(time: [0x00, 0x10, 0x00], pre: [callMenu], post: [conditionalCall])
        let placeholder = pgc(time: [0x00, 0x00, 0x02], post: [exitCommand])
        try write(vtsIFO([feature, placeholder]), "VTS_01_0.IFO"); try write(vtsIFO([feature, placeholder]), "VTS_01_0.BUP")
        try write([UInt8](repeating: 0, count: sector), "VTS_01_0.VOB")
        try write([UInt8](repeating: 0, count: 3 * sector), "VTS_01_1.VOB")
        let extra = pgc(time: [0x01, 0x00, 0x00], post: [setGPRM])
        try write(vtsIFO([extra]), "VTS_02_0.IFO"); try write(vtsIFO([extra]), "VTS_02_0.BUP")
        try write([UInt8](repeating: 0, count: 2 * sector), "VTS_02_1.VOB")
        return folder
    }

    func testTheDiscPlaysEveryRealTitleInOrderWithoutMenus() throws {
        let folder = try makeDisc()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let result = try DVDVideoPlayAllNavigation.convert(videoTSDirectory: folder)

        XCTAssertEqual(result.playOrder, [1, 3])
        XCTAssertEqual(result.skippedShortTitles, [2])
        XCTAssertEqual(result.titlesThatStop, [])
        XCTAssertEqual(result.removedMenuBytes, Int64(3 * sector))
        for gone in ["VIDEO_TS.VOB", "VTS_01_0.VOB"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(gone).path))
        }

        let vmg = try [UInt8](Data(contentsOf: folder.appendingPathComponent("VIDEO_TS.IFO")))
        XCTAssertEqual(vmg, try [UInt8](Data(contentsOf: folder.appendingPathComponent("VIDEO_TS.BUP"))))
        XCTAssertEqual(get32(vmg, 0x84), 0x400)
        XCTAssertEqual(Array(vmg[0x400 + 0xEC + 8..<0x400 + 0xEC + 16]), VMCommand.jumpTT(1))
        XCTAssertEqual(get32(vmg, 0xC0), 0)
        // The step menus: 1 restarts, 2 runs after title 1 (go to 3), 3 after title 3 (stop).
        let menus = get32(vmg, 0xC8) * sector
        XCTAssertEqual(menus, 3 * sector)
        let unit = menus + get32(vmg, menus + 12)
        XCTAssertEqual(Int(vmg[unit + 1]), 3)
        let preCommand = { (index: Int) -> [UInt8] in
            let chain = unit + get32(vmg, unit + 8 + index * 8 + 4)
            return Array(vmg[chain + 0xEC + 8..<chain + 0xEC + 16])
        }
        XCTAssertEqual(preCommand(0), VMCommand.jumpTT(1))
        XCTAssertEqual(preCommand(1), VMCommand.jumpTT(3))
        XCTAssertEqual(preCommand(2), VMCommand.exit)
        // Title sets start where they now are: VMG is 4 sectors, twice; VTS 1 is 2 + 3 + 2.
        XCTAssertEqual(get32(vmg, sector + 8 + 8), 8)
        XCTAssertEqual(get32(vmg, sector + 8 + 24 + 8), 15)

        let vts1 = try [UInt8](Data(contentsOf: folder.appendingPathComponent("VTS_01_0.IFO")))
        XCTAssertEqual(get32(vts1, 0xC0), 0)
        XCTAssertEqual(get32(vts1, 0xD0), 0)
        XCTAssertEqual(get32(vts1, 0xC4), 2)
        XCTAssertEqual(get32(vts1, 0x0C), 6)
        let chains = DVDVideoPlayAllNavigation.titleChains(vts1)
        let feature = try XCTUnwrap(DVDVideoPlayAllNavigation.commandTable(vts1, pgc: chains[0].offset))
        XCTAssertEqual(Array(vts1[feature.pre]), VMCommand.nop)
        XCTAssertEqual(Array(vts1[feature.post]), [0x30, 0xA8, 0, 2, 0, 0xC0, 0x00, 0x05])
        let placeholder = try XCTUnwrap(DVDVideoPlayAllNavigation.commandTable(vts1, pgc: chains[1].offset))
        XCTAssertEqual(Array(vts1[placeholder.post]), [0x30, 0x08, 0, 1, 0, 0xC0, 0, 0])

        let vts2 = try [UInt8](Data(contentsOf: folder.appendingPathComponent("VTS_02_0.IFO")))
        let extra = try XCTUnwrap(DVDVideoPlayAllNavigation.commandTable(vts2, pgc: DVDVideoPlayAllNavigation.titleChains(vts2)[0].offset))
        XCTAssertEqual(Array(vts2[extra.post]), [0x30, 0x08, 0, 3, 0, 0xC0, 0, 0])
    }

    func testAFolderWithoutAVideoManagerIsRefused() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DVDPlayAllEmpty_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try DVDVideoPlayAllNavigation.convert(videoTSDirectory: folder))
    }
}
