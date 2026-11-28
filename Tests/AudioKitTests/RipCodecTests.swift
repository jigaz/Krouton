#if canImport(XCTest)
import XCTest
#endif
import Foundation
import AudioKit

/// Rip cards keep their format as text; these are the strings earlier versions saved.
final class RipCodecTests: XCTestCase {
    func testRawValuesRoundTrip() {
        for codec in KroutonRipCodec.allCases {
            XCTAssertEqual(KroutonRipCodec(savedLabel: codec.rawValue), codec)
            XCTAssertEqual(KroutonRipCodec(savedLabel: codec.title), codec)
        }
    }

    func testLabelsSavedBefore20261127() {
        XCTAssertEqual(KroutonRipCodec(savedLabel: "FLAC (Lossless) + AccurateRip"), .flac)
        XCTAssertEqual(KroutonRipCodec(savedLabel: "Apple Lossless (ALAC)"), .alac)
        XCTAssertEqual(KroutonRipCodec(savedLabel: "WAV (Uncompressed PCM)"), .wav)
        XCTAssertEqual(KroutonRipCodec(savedLabel: "AIFF (1:1 Red Book PCM)"), .aiff)
    }

    func testTextNamingNoFormatKroutonWrites() {
        // An "MP3" card used to write AIFF files without saying so.
        XCTAssertTrue(KroutonRipCodec(savedLabel: "MP3 (320 kbps CBR)") == nil)
        XCTAssertTrue(KroutonRipCodec(savedLabel: "Max Safe (Auto)") == nil)
        XCTAssertTrue(KroutonRipCodec(savedLabel: "") == nil)
    }

    func testFileExtensionsAreDistinct() {
        XCTAssertEqual(Set(KroutonRipCodec.allCases.map(\.fileExtension)).count, KroutonRipCodec.allCases.count)
        XCTAssertEqual(Set(KroutonRipCodec.allCases.map(\.defaultFolderName)).count, KroutonRipCodec.allCases.count)
    }
}
