#if canImport(XCTest)
import XCTest
#endif
import Foundation
import VideoKit

final class DVDShrinkGuardTests: XCTestCase {
    private func makeVideoTS(mainFeatureBytes: UInt64) throws -> (root: URL, source: URL, output: URL) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("DVDShrinkGuardTests_\(UUID().uuidString)")
        let source = root.appendingPathComponent("in/VIDEO_TS")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("IFO-BYTES-THAT-MUST-NOT-CHANGE".utf8 + [UInt8](repeating: 0x11, count: 4096)).write(to: source.appendingPathComponent("VIDEO_TS.IFO"))
        try Data("MENU".utf8).write(to: source.appendingPathComponent("VIDEO_TS.VOB"))
        try Data("VTS-IFO".utf8 + [UInt8](repeating: 0x22, count: 4096)).write(to: source.appendingPathComponent("VTS_01_0.IFO"))
        // A sparse file: the size is real, the disk usage is not.
        let feature = source.appendingPathComponent("VTS_01_1.VOB")
        fm.createFile(atPath: feature.path, contents: Data("FEATURE".utf8))
        let handle = try FileHandle(forWritingTo: feature)
        try handle.truncate(atOffset: mainFeatureBytes)
        try handle.close()
        return (root, source, root.appendingPathComponent("out/VIDEO_TS"))
    }

    func testOversizeTitleIsRefusedAndNothingIsWritten() throws {
        let paths = try makeVideoTS(mainFeatureBytes: 5_000_000_000)
        defer { try? FileManager.default.removeItem(at: paths.root) }
        var refused = false
        do {
            try KroutonVideoAuthoringEngine.executeDVD9ToDVD5ShrinkOnDisk(
                sourceVideoTSDirectory: paths.source, outputVideoTSDirectory: paths.output, preserveMenus: false
            )
        } catch {
            if case .requantizationUnavailable = error as? KroutonVideoShrinkError { refused = true }
        }
        XCTAssertTrue(refused)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.output.path))
    }

    func testTitleThatAlreadyFitsIsCopiedByteForByte() throws {
        let paths = try makeVideoTS(mainFeatureBytes: 64 * 1024)
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let plan = try KroutonVideoAuthoringEngine.executeDVD9ToDVD5ShrinkOnDisk(
            sourceVideoTSDirectory: paths.source, outputVideoTSDirectory: paths.output, preserveMenus: true
        )
        XCTAssertFalse(plan.requiresRequantization)
        for name in ["VIDEO_TS.IFO", "VIDEO_TS.VOB", "VTS_01_0.IFO", "VTS_01_1.VOB"] {
            let original = try Data(contentsOf: paths.source.appendingPathComponent(name))
            let copied = try Data(contentsOf: paths.output.appendingPathComponent(name))
            XCTAssertTrue(original == copied)
        }
    }
}
