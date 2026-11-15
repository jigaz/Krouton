#if canImport(XCTest)
import XCTest
#endif
import Foundation
import BurnKit
import OpticalCore

final class BurnSetPlannerTests: XCTestCase {
    private let mib: Int64 = 1024 * 1024

    private func file(_ path: String, _ bytes: Int64) -> SpanInputFile {
        SpanInputFile(relativePath: path, sourceURL: URL(fileURLWithPath: "/tmp/" + path), byteCount: bytes)
    }

    func testPlannedBytesRoundsUpAndAddsDirectorySector() {
        XCTAssertEqual(BurnSetPlanner.plannedBytes(forFileOfSize: 0), 2048)
        XCTAssertEqual(BurnSetPlanner.plannedBytes(forFileOfSize: 1), 4096)
        XCTAssertEqual(BurnSetPlanner.plannedBytes(forFileOfSize: 2048), 4096)
        XCTAssertEqual(BurnSetPlanner.plannedBytes(forFileOfSize: 2049), 6144)
    }

    func testFilesFillDiscsInOrderAndKeepTheirPaths() throws {
        // 100 MiB discs keep 92 MiB for files after the 8 MiB reserve.
        let files = [file("a.bin", 40 * mib), file("b.bin", 40 * mib), file("c.bin", 40 * mib), file("d/e.bin", 10 * mib)]
        let plan = try BurnSetPlanner.plan(files, discCapacityBytes: 100 * mib)
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan[0].map(\.relativePathOnDisc), ["a.bin", "b.bin"])
        XCTAssertEqual(plan[1].map(\.relativePathOnDisc), ["c.bin", "d/e.bin"])
    }

    func testEveryPlannedDiscStaysWithinTheUsableSize() throws {
        var files: [SpanInputFile] = []
        for index in 0..<200 { files.append(file(String(format: "f%03d.bin", index), Int64(1 + (index * 7919) % 9) * mib)) }
        let capacity = 64 * mib
        let usable = BurnSetPlanner.usableBytes(discCapacityBytes: capacity, totalFileCount: files.count)
        let sizes = Dictionary(uniqueKeysWithValues: files.map { ($0.relativePath, $0.byteCount) })
        let plan = try BurnSetPlanner.plan(files, discCapacityBytes: capacity)
        XCTAssertEqual(plan.flatMap { $0 }.count, files.count)
        for disc in plan {
            let used = disc.reduce(Int64(0)) { $0 + BurnSetPlanner.plannedBytes(forFileOfSize: sizes[$1.relativePathOnDisc] ?? 0) }
            XCTAssertTrue(used <= usable)
        }
    }

    func testFileLargerThanADiscIsRefusedByName() {
        var refusedPath = ""
        do {
            _ = try BurnSetPlanner.plan([file("small.txt", 10), file("movie.mkv", 200 * mib)], discCapacityBytes: 100 * mib)
        } catch {
            if case .fileTooLarge(let path, _, _) = error as? BurnSetPlanError { refusedPath = path }
        }
        XCTAssertEqual(refusedPath, "movie.mkv")
    }

    func testEmptyInputAndTinyDiscAreRefused() {
        var nothing = false
        do { _ = try BurnSetPlanner.plan([], discCapacityBytes: 100 * mib) } catch { nothing = (error as? BurnSetPlanError) == .nothingToBurn }
        XCTAssertTrue(nothing)

        var tooSmall = false
        do { _ = try BurnSetPlanner.plan([file("a", 1)], discCapacityBytes: 4 * mib) } catch {
            if case .discTooSmall = error as? BurnSetPlanError { tooSmall = true }
        }
        XCTAssertTrue(tooSmall)
    }

    func testExpandWalksFoldersSkipsFinderFilesAndSortsByDiscPath() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("BurnSetPlannerTests_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        let folder = tmp.appendingPathComponent("Photos")
        try fm.createDirectory(at: folder.appendingPathComponent("2026/Trip"), withIntermediateDirectories: true)
        try Data(count: 300).write(to: folder.appendingPathComponent("2026/Trip/b.jpg"))
        try Data(count: 100).write(to: folder.appendingPathComponent("2026/a.jpg"))
        try Data(count: 50).write(to: folder.appendingPathComponent(".DS_Store"))
        let loose = tmp.appendingPathComponent("notes.txt")
        try Data(count: 7).write(to: loose)

        let files = try BurnSetPlanner.expand([(url: loose, name: "Notes.txt"), (url: folder, name: "Photos")])
        XCTAssertEqual(files.map(\.relativePath), ["Notes.txt", "Photos/2026/Trip/b.jpg", "Photos/2026/a.jpg"])
        XCTAssertEqual(files.map(\.byteCount), [7, 300, 100])
    }

    func testExpandRefusesTwoItemsAtTheSameDiscPath() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("BurnSetPlannerTests_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        let one = tmp.appendingPathComponent("one.txt")
        let two = tmp.appendingPathComponent("two.txt")
        try Data(count: 1).write(to: one)
        try Data(count: 1).write(to: two)
        var duplicate = false
        do {
            _ = try BurnSetPlanner.expand([(url: one, name: "Report.txt"), (url: two, name: "REPORT.TXT")])
        } catch {
            if case .duplicatePath = error as? BurnSetPlanError { duplicate = true }
        }
        XCTAssertTrue(duplicate)
    }
}
