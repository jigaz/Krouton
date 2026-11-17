import CryptoKit
import Foundation

actor KroutonHardwareAccelerator {
    static let shared = KroutonHardwareAccelerator()
    private init() {}

    func computeSHA256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func computeFileSHA256Hex(at url: URL, chunkSize: Int = 4 * 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                return false
            }
            hasher.update(data: chunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
