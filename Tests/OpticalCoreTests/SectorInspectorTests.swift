#if canImport(XCTest)
import XCTest
#endif
import CryptoKit
import Foundation
import OpticalCore

/// The disc image inspector shows only what is in the file: real bytes, a real digest, and the
/// container named from the extension.
final class SectorInspectorTests: XCTestCase {
    private func temporaryImage(bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("krouton_inspector_\(UUID().uuidString).iso")
        try Data((0..<bytes).map { UInt8(truncatingIfNeeded: $0) }).write(to: url)
        return url
    }

    func testSHA256StreamsTheFileAndMatchesCryptoKit() throws {
        // A little over two 1 MiB pieces, so the streaming crosses piece boundaries.
        let url = try temporaryImage(bytes: (2 << 20) + 123)
        defer { try? FileManager.default.removeItem(at: url) }
        let expected = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(KroutonElToritoBootInspector.computeSHA256Hex(url: url), expected)
    }

    func testSHA256OfAnUnreadableFileIsNil() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("krouton_missing_\(UUID().uuidString).iso")
        XCTAssertTrue(KroutonElToritoBootInspector.computeSHA256Hex(url: missing) == nil)
    }

    func testHexDumpShowsRealBytesAndNothingPastTheEnd() throws {
        // Two sectors and 20 bytes: LBA 2 holds only 20 real bytes, LBA 3 is past the end.
        let url = try temporaryImage(bytes: 2 * 2048 + 20)
        defer { try? FileManager.default.removeItem(at: url) }

        let first = KroutonElToritoBootInspector.readSectorHexDump(url: url, lba: 1)
        XCTAssertEqual(first.count, 16)
        XCTAssertEqual(first.first?.offsetHex, "00000800")
        XCTAssertTrue(first.first?.hexBytes.hasPrefix("00 01 02") == true)
        XCTAssertTrue(KroutonElToritoBootInspector.sectorDumpUnavailableReason(url: url, lba: 1) == nil)

        let tail = KroutonElToritoBootInspector.readSectorHexDump(url: url, lba: 2)
        XCTAssertEqual(tail.count, 2)
        XCTAssertEqual(tail.last?.asciiText.count, 4)

        XCTAssertTrue(KroutonElToritoBootInspector.readSectorHexDump(url: url, lba: 3).isEmpty)
        XCTAssertTrue(KroutonElToritoBootInspector.sectorDumpUnavailableReason(url: url, lba: 3)?.contains("past the end") == true)
    }

    func testProbeNamesOnlyTheContainer() {
        let probe = KroutonMediaPrepEngine.probeFile(URL(fileURLWithPath: "/tmp/concert.mkv"))
        XCTAssertEqual(probe.fileExtension, "MKV")
        XCTAssertTrue(probe.shortHardwareBadge.hasPrefix("Matroska"))
        XCTAssertFalse(probe.isHardwareAccelerated)
        XCTAssertFalse(probe.shortHardwareBadge.contains("TrueHD"))
    }
}
