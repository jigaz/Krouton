import CryptoKit
import Foundation
import OpticalCore
import os

/// Compares what a drive reads back with the image that was burned.
/// Uses only file handles, so it is unit-tested with ordinary files.
public enum KroutonDiscReadbackVerifier {
    public static let sectorSize = 2048
    static let sectorsPerRead = 512 // 1 MiB

    /// Reads `byteCount` bytes from both `deviceURL` and `imageURL` once, in step.
    /// - Throws: `.verifyMismatch` with the first sector that differs or cannot be read;
    ///   `.writeError` if the image no longer matches `expectedSHA256`; `.cancelledByUser`.
    public static func verify(
        deviceURL: URL,
        imageURL: URL,
        expectedSHA256: String,
        byteCount: Int64,
        isCancelled: () -> Bool = { false }
    ) throws {
        let image: FileHandle
        let device: FileHandle
        do {
            image = try FileHandle(forReadingFrom: imageURL)
        } catch {
            throw BurnFailure.writeError(sense: "Could not reopen the image for verification: \(error.localizedDescription)")
        }
        defer { try? image.close() }
        do {
            device = try FileHandle(forReadingFrom: deviceURL)
        } catch {
            throw BurnFailure.writeError(sense: "Could not open \(deviceURL.path) to read the disc back: \(error.localizedDescription)")
        }
        defer { try? device.close() }

        var hasher = SHA256()
        var offset: Int64 = 0
        let chunkBytes = sectorSize * sectorsPerRead
        while offset < byteCount {
            if isCancelled() { throw BurnFailure.cancelledByUser }
            let want = Int(min(Int64(chunkBytes), byteCount - offset))
            let sector = offset / Int64(sectorSize)

            let imageData: Data
            do {
                imageData = try readFully(image, count: want)
            } catch {
                throw BurnFailure.writeError(sense: "Could not read the image during verification: \(error.localizedDescription)")
            }
            guard imageData.count == want else {
                throw BurnFailure.writeError(sense: "The image file is shorter than it was when the set was frozen.")
            }

            // Raw disc devices only accept whole-sector reads.
            let deviceWant = ((want + sectorSize - 1) / sectorSize) * sectorSize
            let deviceData: Data
            do {
                deviceData = try readFully(device, count: deviceWant)
            } catch {
                throw BurnFailure.verifyMismatch(firstBadSector: sector) // unreadable sector
            }
            guard deviceData.count >= want else {
                throw BurnFailure.verifyMismatch(firstBadSector: (offset + Int64(deviceData.count)) / Int64(sectorSize))
            }
            if deviceData.prefix(want) != imageData {
                let firstDifference = zip(deviceData, imageData).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? 0
                throw BurnFailure.verifyMismatch(firstBadSector: (offset + Int64(firstDifference)) / Int64(sectorSize))
            }
            hasher.update(data: imageData)
            offset += Int64(want)
        }

        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let expected = expectedSHA256.lowercased().replacingOccurrences(of: "sha256:", with: "")
        guard actual == expected else {
            throw BurnFailure.writeError(sense: "The image file changed after the set was frozen, so the disc cannot be trusted.")
        }
    }

    private static func readFully(_ handle: FileHandle, count: Int) throws -> Data {
        var collected = Data()
        collected.reserveCapacity(count)
        while collected.count < count {
            guard let part = try handle.read(upToCount: count - collected.count), !part.isEmpty else { break }
            collected.append(part)
        }
        return collected
    }
}
