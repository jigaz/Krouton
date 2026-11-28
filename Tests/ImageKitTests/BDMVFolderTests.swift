#if canImport(XCTest)
import XCTest
#endif
import Foundation
@testable import ImageKit

final class BDMVFolderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("BDMVFolder_\(UUID().uuidString)/MOVIE")
        let bdmv = root.appendingPathComponent("BDMV")
        for folder in ["PLAYLIST", "CLIPINF", "STREAM", "BACKUP", "AUXDATA"] {
            try FileManager.default.createDirectory(at: bdmv.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("CERTIFICATE"), withIntermediateDirectories: true)
        for file in ["index.bdmv", "MovieObject.bdmv", "PLAYLIST/00000.mpls", "CLIPINF/00000.clpi"] {
            try Data([0x4D, 0x50]).write(to: bdmv.appendingPathComponent(file))
        }
        try stream(copyPermission: 0).write(to: bdmv.appendingPathComponent("STREAM/00000.m2ts"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    /// Four aligned units of source packets, each unit led by the given copy-permission bits.
    private func stream(copyPermission: UInt8) -> Data {
        var bytes = [UInt8](repeating: 0, count: 6144 * 4)
        for packet in stride(from: 0, to: bytes.count, by: 192) {
            bytes[packet + 4] = 0x47
            if packet % 6144 == 0 { bytes[packet] = copyPermission << 6 }
        }
        return Data(bytes)
    }

    func testAnAuthoredFolderPasses() {
        XCTAssertNil(KroutonBDMVFolder.problem(root: root))
    }

    func testAFolderMissingWhatPlayersReadIsRefused() throws {
        try FileManager.default.removeItem(at: root.appendingPathComponent("BDMV/index.bdmv"))
        XCTAssertTrue(KroutonBDMVFolder.problem(root: root)?.contains("index.bdmv") == true)
        XCTAssertTrue(KroutonBDMVFolder.problem(root: root.deletingLastPathComponent())?.contains("no BDMV") == true)
    }

    func testEncryptedVideoIsRefused() throws {
        try stream(copyPermission: 3).write(to: root.appendingPathComponent("BDMV/STREAM/00000.m2ts"))
        XCTAssertTrue(KroutonBDMVFolder.problem(root: root)?.contains("encrypted") == true)
    }

    func testHiddenFilesAndKeyFoldersStayOffTheDisc() throws {
        XCTAssertTrue(KroutonBDMVFolder.leftOut(relativePath: "BDMV/STREAM/.DS_Store", isDirectory: false))
        XCTAssertTrue(KroutonBDMVFolder.leftOut(relativePath: "BDMV/STREAM/._00000.m2ts", isDirectory: false))
        XCTAssertTrue(KroutonBDMVFolder.leftOut(relativePath: "AACS", isDirectory: true))
        XCTAssertFalse(KroutonBDMVFolder.leftOut(relativePath: "BDMV/AACS", isDirectory: true))
        XCTAssertFalse(KroutonBDMVFolder.leftOut(relativePath: "BDMV/STREAM/00000.m2ts", isDirectory: false))

        try Data([1]).write(to: root.appendingPathComponent("BDMV/STREAM/.DS_Store"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("AACS"), withIntermediateDirectories: true)
        try Data([1]).write(to: root.appendingPathComponent("AACS/Unit_Key_RO.inf"))
        let image = root.deletingLastPathComponent().appendingPathComponent("disc.iso")
        let all = try KroutonUDFImageWriter.build(folder: root, output: image, label: "MOVIE", now: 1_795_000_000)
        let kept = try KroutonUDFImageWriter.build(folder: root, output: image, label: "MOVIE", now: 1_795_000_000,
                                                   leaveOut: KroutonBDMVFolder.leftOut)
        XCTAssertEqual(all.files - kept.files, 2)
        XCTAssertEqual(all.folders - kept.folders, 1)
    }
}
