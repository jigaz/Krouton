import Foundation
import OpticalDough
import Marmalade
import Tartine
import VideoOven
import Galette
import Crustini

#if canImport(XCTest)
import XCTest

final class KroutonRepositoryTests: XCTestCase {
    func testOpticalMediaKindClassification() {
        XCTAssertEqual(OpticalMediaKind(mediaDescription: "DVD+R DL 8.5GB"), .dvdDualLayer)
        XCTAssertEqual(OpticalMediaKind(mediaDescription: "DVD-R 4.7GB"), .dvdSingleLayer)
        XCTAssertEqual(OpticalMediaKind(mediaDescription: "BD-R 25GB"), .bluRaySingleLayer)
        XCTAssertEqual(OpticalMediaKind(mediaDescription: "CD-R 700MB"), .cd)
        XCTAssertTrue(OpticalMediaKind.dvdSingleLayer.isDVDClass)
    }

    func testTartineSHA256AndElToritoLayout() {
        let sample = Data("KROUTON_EL_TORITO_SECTOR".utf8)
        let digest = KroutonTartineModule.computeBlockSHA256Hex(for: sample)
        XCTAssertTrue(digest.hasPrefix("sha256:"))
        XCTAssertEqual(digest.count, 7 + 64)
        XCTAssertEqual(KroutonTartineModule.elToritoBootRecordVolumeDescriptorLBA, 17)
        XCTAssertEqual(KroutonTartineModule.elToritoDefaultBootCatalogLBA, 18)
    }

    func testVideoOvenIFOBinarySectorPatching() {
        var rawIFO = Data(repeating: 0, count: 256)
        rawIFO[0x010] = 0x0F
        let patched = KroutonVideoOvenModule.patchVTSIFOBinarySectorPointers(
            ifoData: rawIFO,
            relocatedStartSectorLBA: 0x0001_0203,
            cellPlaybackFlagOffsets: [0x010]
        )
        XCTAssertEqual(patched[0x00C4], 0x00)
        XCTAssertEqual(patched[0x00C5], 0x01)
        XCTAssertEqual(patched[0x00C6], 0x02)
        XCTAssertEqual(patched[0x00C7], 0x03)
        XCTAssertEqual(patched[0x010] & 0x08, 0x00)
    }

    func testGaletteCueParserAndBootClassifier() {
        let cue = """
        FILE "ARCHIVE.BIN" BINARY
          TRACK 01 MODE1/2352
            INDEX 01 00:00:00
        """
        let parsed = KroutonGaletteModule.parseCueSheet(cueText: cue)
        XCTAssertEqual(parsed.tracks.count, 1)
        XCTAssertEqual(parsed.tracks.first?.sectorSize, 2352)
    }
}
#endif
