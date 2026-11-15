#if canImport(XCTest)
import XCTest
#endif
import Foundation
import ImageKit

final class HybridImageBuilderTests: XCTestCase {
    func testArgumentsRequestAllThreeTreesWithoutAShell() throws {
        let args = try KroutonHybridImageBuilder.arguments(
            sourceDirectory: URL(fileURLWithPath: "/tmp/My Stage; rm -rf ~"),
            outputURL: URL(fileURLWithPath: "/tmp/out.iso"),
            options: KroutonHybridImageOptions(volumeName: "Family Photos 2026")
        )
        XCTAssertEqual(args.first ?? "", "makehybrid")
        XCTAssertTrue(args.contains("-iso") && args.contains("-joliet") && args.contains("-udf"))
        XCTAssertFalse(args.contains("-hfs"))
        // The source path is one argument, passed through untouched as the last element.
        XCTAssertEqual(args.last ?? "", "/tmp/My Stage; rm -rf ~")
        let isoName = args[(args.firstIndex(of: "-iso-volume-name") ?? 0) + 1]
        XCTAssertEqual(isoName, "FAMILY_PHOTOS_2026")
        let udfVersion = args[(args.firstIndex(of: "-udf-version") ?? 0) + 1]
        XCTAssertEqual(udfVersion, "1.02")
    }

    func testNoFilesystemSelectedIsRejected() {
        let options = KroutonHybridImageOptions(volumeName: "X", includeISO9660: false, includeJoliet: false, includeUDF: false)
        var rejected = false
        do {
            _ = try KroutonHybridImageBuilder.arguments(
                sourceDirectory: URL(fileURLWithPath: "/tmp/a"), outputURL: URL(fileURLWithPath: "/tmp/a.iso"), options: options
            )
        } catch {
            rejected = (error as? KroutonHybridImageError) == .noFilesystemSelected
        }
        XCTAssertTrue(rejected)
    }

    func testClippedVolumeNameKeepsMultiDiscSuffix() {
        XCTAssertEqual(KroutonHybridImageBuilder.clippedVolumeName("SHORT", limit: 16), "SHORT")
        let clipped = KroutonHybridImageBuilder.clippedVolumeName("ARCHIVAL_VAULT_TITLE_2026_D02", limit: 16)
        XCTAssertEqual(clipped.count, 16)
        XCTAssertTrue(clipped.hasSuffix("_D02"))
        XCTAssertTrue(clipped.hasPrefix("ARCHIVAL_VAU"))
    }

    func testStreamingSHA256MatchesKnownVector() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HybridImageBuilderTests_\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("abc".utf8).write(to: url)
        let digest = try KroutonHybridImageBuilder.sha256(ofFileAt: url)
        XCTAssertEqual(digest.hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(digest.byteCount, 3)
    }

    /// Runs the real `hdiutil`: the image must carry an ISO-9660 descriptor, be sector-aligned,
    /// keep its subdirectory, and hash to the value the builder reported.
    func testBuildsAMountableImageWithSubdirectories() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("HybridImageBuilderTests_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        let tree = tmp.appendingPathComponent("tree")
        try fm.createDirectory(at: tree.appendingPathComponent("Docs/Nested"), withIntermediateDirectories: true)
        try Data("hello krouton".utf8).write(to: tree.appendingPathComponent("Docs/Nested/A Long File Name With Spaces.txt"))
        try Data(repeating: 0x5A, count: 10_000).write(to: tree.appendingPathComponent("payload.bin"))

        let image = try KroutonHybridImageBuilder.buildBlocking(
            sourceDirectory: tree,
            outputURL: tmp.appendingPathComponent("out.iso"),
            options: KroutonHybridImageOptions(volumeName: "KROUTON_TEST")
        )
        XCTAssertGreaterThan(image.byteCount, Int64(17 * 2048))
        XCTAssertEqual(image.byteCount % 2048, 0)

        let handle = try FileHandle(forReadingFrom: image.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(16 * 2048 + 1))
        let signature = try handle.read(upToCount: 5) ?? Data()
        XCTAssertEqual(String(decoding: signature, as: UTF8.self), "CD001")

        let rehash = try KroutonHybridImageBuilder.sha256(ofFileAt: image.url)
        XCTAssertEqual(rehash.hex, image.sha256Hex)
        XCTAssertEqual(rehash.byteCount, image.byteCount)

        // Building again over the same path replaces the image instead of failing.
        let second = try KroutonHybridImageBuilder.buildBlocking(
            sourceDirectory: tree,
            outputURL: tmp.appendingPathComponent("out.iso"),
            options: KroutonHybridImageOptions(volumeName: "KROUTON_TEST")
        )
        XCTAssertEqual(second.byteCount, image.byteCount)
    }

    func testMissingSourceDirectoryIsReported() {
        var reported = false
        do {
            _ = try KroutonHybridImageBuilder.buildBlocking(
                sourceDirectory: URL(fileURLWithPath: "/nonexistent/krouton-\(UUID().uuidString)"),
                outputURL: FileManager.default.temporaryDirectory.appendingPathComponent("never.iso"),
                options: KroutonHybridImageOptions(volumeName: "X")
            )
        } catch {
            if case .sourceDirectoryMissing = error as? KroutonHybridImageError { reported = true }
        }
        XCTAssertTrue(reported)
    }
}
