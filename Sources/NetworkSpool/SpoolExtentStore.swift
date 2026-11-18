import Darwin
import Foundation

// MARK: - Durable Extent Store (node side)

public actor SpoolExtentStore {
    public enum StoreError: Error, Sendable, Equatable {
        case io(operation: String, errno: Int32)
        case insufficientSpace(neededBytes: Int64)
    }

    public let manifest: SpoolTransferManifest
    public private(set) var committed: ExtentBitmap
    private let imageFD: Int32
    private let journalFD: Int32

    public init(manifest: SpoolTransferManifest, imageURL: URL, journalURL: URL) throws(StoreError) {
        let imageFD = open(imageURL.path, O_RDWR | O_CREAT, 0o644)
        guard imageFD >= 0 else { throw .io(operation: "open image", errno: errno) }
        let journalFD = open(journalURL.path, O_RDWR | O_CREAT | O_APPEND, 0o644)
        guard journalFD >= 0 else {
            close(imageFD)
            throw .io(operation: "open journal", errno: errno)
        }
        var info = stat()
        if fstat(imageFD, &info) == 0, info.st_size == 0 {
            var request = fstore_t(fst_flags: UInt32(F_ALLOCATEALL), fst_posmode: F_PEOFPOSMODE,
                                   fst_offset: 0, fst_length: off_t(manifest.imageBytes), fst_bytesalloc: 0)
            guard fcntl(imageFD, F_PREALLOCATE, &request) != -1,
                  ftruncate(imageFD, off_t(manifest.imageBytes)) == 0 else {
                close(imageFD)
                close(journalFD)
                throw .insufficientSpace(neededBytes: Int64(manifest.imageBytes))
            }
        }
        self.manifest = manifest
        self.imageFD = imageFD
        self.journalFD = journalFD
        self.committed = ExtentCommitRecord.replay(Self.readAll(journalFD), against: manifest)
    }

    deinit {
        close(imageFD)
        close(journalFD)
    }

    public func commit(extent index: Int, bytes: [UInt8]) throws(StoreError) {
        guard !committed.contains(index) else { return }
        let offset = off_t(manifest.byteRange(ofExtent: index).lowerBound)
        let written = bytes.withUnsafeBytes { pwrite(imageFD, $0.baseAddress, $0.count, offset) }
        guard written == bytes.count else { throw .io(operation: "pwrite", errno: errno) }
        guard fcntl(imageFD, F_BARRIERFSYNC) == 0 else { throw .io(operation: "barrier image", errno: errno) }
        let record = ExtentCommitRecord(extentIndex: UInt32(index), leafDigest: manifest.leafDigests[index]).encoded()
        let appended = record.withUnsafeBytes { write(journalFD, $0.baseAddress, $0.count) }
        guard appended == record.count, fcntl(journalFD, F_BARRIERFSYNC) == 0 else {
            throw .io(operation: "append journal", errno: errno)
        }
        committed.insert(index)
    }

    public func seal() throws(StoreError) {
        guard committed.isComplete else { return }
        guard fcntl(imageFD, F_FULLFSYNC) == 0 else { throw .io(operation: "full fsync", errno: errno) }
    }

    private static func readAll(_ fd: Int32) -> [UInt8] {
        var out: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        var offset: off_t = 0
        while true {
            let count = chunk.withUnsafeMutableBytes { pread(fd, $0.baseAddress, $0.count, offset) }
            guard count > 0 else { break }
            out.append(contentsOf: chunk[0..<count])
            offset += off_t(count)
        }
        return out
    }
}
