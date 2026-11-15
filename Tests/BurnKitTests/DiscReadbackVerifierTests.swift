#if canImport(XCTest)
import XCTest
#endif
import CryptoKit
import Foundation
import DriveKit
import OpticalCore

/// The "device" here is an ordinary file, which is all the verifier needs.
final class DiscReadbackVerifierTests: XCTestCase {
    private func makePair(sectors: Int) throws -> (dir: URL, image: URL, device: URL, payload: Data, sha: String) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DiscReadbackVerifierTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var payload = Data(count: sectors * 2048)
        for index in 0..<payload.count { payload[index] = UInt8(truncatingIfNeeded: index &* 31 &+ index / 2048) }
        let image = dir.appendingPathComponent("image.iso")
        let device = dir.appendingPathComponent("device.raw")
        try payload.write(to: image)
        try payload.write(to: device)
        let sha = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        return (dir, image, device, payload, sha)
    }

    private func failure(_ body: () throws -> Void) -> BurnFailure? {
        do { try body(); return nil } catch { return error as? BurnFailure }
    }

    func testIdenticalDiscPasses() throws {
        // 600 sectors spans more than one 512-sector read.
        let pair = try makePair(sectors: 600)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image, expectedSHA256: "sha256:" + pair.sha.uppercased(),
                byteCount: Int64(pair.payload.count)
            )
        }
        XCTAssertTrue(result == nil)
    }

    func testDiscWithTrailingDataBeyondTheImageStillPasses() throws {
        let pair = try makePair(sectors: 40)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        try (pair.payload + Data(count: 150 * 2048)).write(to: pair.device) // lead-out padding after the image
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image, expectedSHA256: pair.sha, byteCount: Int64(pair.payload.count)
            )
        }
        XCTAssertTrue(result == nil)
    }

    func testFlippedByteReportsItsSector() throws {
        let pair = try makePair(sectors: 600)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        var damaged = pair.payload
        let badOffset = 555 * 2048 + 17
        damaged[badOffset] ^= 0xFF
        try damaged.write(to: pair.device)
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image, expectedSHA256: pair.sha, byteCount: Int64(pair.payload.count)
            )
        }
        XCTAssertTrue(result == .verifyMismatch(firstBadSector: 555))
    }

    func testShortDiscReportsWhereItEnds() throws {
        let pair = try makePair(sectors: 100)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        try pair.payload.prefix(60 * 2048).write(to: pair.device)
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image, expectedSHA256: pair.sha, byteCount: Int64(pair.payload.count)
            )
        }
        XCTAssertTrue(result == .verifyMismatch(firstBadSector: 60))
    }

    func testImageChangedAfterFreezeIsNotReportedAsAGoodDisc() throws {
        let pair = try makePair(sectors: 20)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image,
                expectedSHA256: String(repeating: "0", count: 64), byteCount: Int64(pair.payload.count)
            )
        }
        var isWriteError = false
        if case .writeError = result { isWriteError = true }
        XCTAssertTrue(isWriteError)
    }

    func testCancellationStopsBeforeReading() throws {
        let pair = try makePair(sectors: 20)
        defer { try? FileManager.default.removeItem(at: pair.dir) }
        let result = failure {
            try KroutonDiscReadbackVerifier.verify(
                deviceURL: pair.device, imageURL: pair.image, expectedSHA256: pair.sha,
                byteCount: Int64(pair.payload.count), isCancelled: { true }
            )
        }
        XCTAssertTrue(result == .cancelledByUser)
    }
}
