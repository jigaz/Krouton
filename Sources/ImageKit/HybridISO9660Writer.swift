import Foundation
import CryptoKit
import OpticalCore

/// Input file descriptor for writing a multi-extent ECMA-119 ISO-9660 + El Torito optical disc image.
public struct HybridISOFileInput: Sendable, Equatable {
    public let fileName: String
    public let data: Data

    public init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
    }
}

/// Summary of a synthesized ECMA-119 ISO-9660 + El Torito optical image on disk.
public struct HybridSynthesizedISOImage: Sendable, Equatable {
    public let url: URL
    public let sha256Hex: String
    public let totalSectorsLBA: Int
    public let totalBytes: Int64
    public let fileExtentLBAs: [String: Int]
}

public enum KroutonHybridISO9660Writer {
    /// Writes a spec-compliant ECMA-119 ISO-9660 + El Torito image containing a Primary Volume Descriptor (LBA 16),
    /// El Torito Boot Record (LBA 17), Boot Catalog (LBA 18), L/M Path Tables (LBA 19-20), Root Directory (LBA 21),
    /// Volume Descriptor Set Terminator (LBA 22), and real sector-aligned file extents starting at LBA 23.
    public static func writeMountableISO9660Image(
        volumeTitle: String,
        files: [HybridISOFileInput],
        outputURL: URL
    ) throws -> HybridSynthesizedISOImage {
        let effectiveFiles: [HybridISOFileInput] = files.isEmpty
            ? [HybridISOFileInput(fileName: "README_KROUTON.TXT", data: Data("Mastered by Krouton Hybrid ISO-9660 Engine.\n".utf8))]
            : files

        var nextLBA = 23
        var filePlacement: [(name: String, isoIdent: String, lba: Int, data: Data, paddedSectors: Int)] = []
        var extentMap: [String: Int] = [:]

        for item in effectiveFiles {
            let isoIdent = sanitizeISO9660Identifier(item.fileName)
            let sectors = max(1, (item.data.count + 2047) / 2048)
            filePlacement.append((item.fileName, isoIdent, nextLBA, item.data, sectors))
            extentMap[item.fileName] = nextLBA
            nextLBA += sectors
        }

        let totalSectors = max(24, nextLBA)
        var image = [UInt8](repeating: 0, count: totalSectors * 2048)

        writePrimaryVolumeDescriptor(&image, volumeTitle: volumeTitle, totalSectors: UInt32(totalSectors))
        writeElToritoBootSectors(&image)
        writePathTablesAndTerminator(&image)
        writeRootDirectoryRecords(&image, placements: filePlacement)

        for entry in filePlacement {
            let byteStart = entry.lba * 2048
            image.replaceSubrange(byteStart..<(byteStart + entry.data.count), with: entry.data)
        }

        let finalData = Data(image)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try finalData.write(to: outputURL, options: .atomic)
        let digest = KroutonHybridImagePlanner.computeBlockSHA256Hex(for: finalData)

        return HybridSynthesizedISOImage(
            url: outputURL,
            sha256Hex: digest,
            totalSectorsLBA: totalSectors,
            totalBytes: Int64(finalData.count),
            fileExtentLBAs: extentMap
        )
    }

    private static func writePrimaryVolumeDescriptor(_ image: inout [UInt8], volumeTitle: String, totalSectors: UInt32) {
        let pvd = 16 * 2048
        image[pvd] = 0x01
        for (i, b) in Array("CD001".utf8).enumerated() { image[pvd + 1 + i] = b }
        image[pvd + 6] = 0x01

        let sysID = "MACOS_KROUTON".padding(toLength: 32, withPad: " ", startingAt: 0)
        for (i, b) in Array(sysID.utf8).prefix(32).enumerated() { image[pvd + 8 + i] = b }

        let cleanedTitle = volumeTitle.uppercased()
            .replacingOccurrences(of: " ", with: "_")
            .padding(toLength: 32, withPad: " ", startingAt: 0)
        for (i, b) in Array(cleanedTitle.utf8).prefix(32).enumerated() { image[pvd + 40 + i] = b }

        writeBothEndianUInt32(&image, offset: pvd + 80, value: totalSectors)
        writeBothEndianUInt16(&image, offset: pvd + 120, value: 1)
        writeBothEndianUInt16(&image, offset: pvd + 124, value: 1)
        writeBothEndianUInt16(&image, offset: pvd + 128, value: 2048)
        writeBothEndianUInt32(&image, offset: pvd + 132, value: 10)
        writeUInt32LE(&image, offset: pvd + 140, value: 19)
        writeUInt32BE(&image, offset: pvd + 148, value: 20)

        writeDirectoryRecord(&image, baseOffset: pvd + 156, extentLBA: 21, dataLength: 2048, flags: 0x02, identifier: [0x00])
    }

    private static func writeElToritoBootSectors(_ image: inout [UInt8]) {
        let brvd = 17 * 2048
        image[brvd] = 0x00
        for (i, b) in Array("CD001".utf8).enumerated() { image[brvd + 1 + i] = b }
        image[brvd + 6] = 0x01
        for (i, b) in Array("EL TORITO SPECIFICATION".utf8).enumerated() { image[brvd + 7 + i] = b }
        writeUInt32LE(&image, offset: brvd + 0x47, value: 18)

        let cat = 18 * 2048
        image[cat] = 0x01
        image[cat + 0x1E] = 0x55
        image[cat + 0x1F] = 0xAA
        image[cat + 32] = 0x88
        image[cat + 32 + 6] = 0x04
        writeUInt32LE(&image, offset: cat + 32 + 8, value: 23)
    }

    private static func writePathTablesAndTerminator(_ image: inout [UInt8]) {
        let lPath = 19 * 2048
        image[lPath] = 1
        writeUInt32LE(&image, offset: lPath + 2, value: 21)
        writeUInt16LE(&image, offset: lPath + 6, value: 1)

        let mPath = 20 * 2048
        image[mPath] = 1
        writeUInt32BE(&image, offset: mPath + 2, value: 21)
        writeUInt16BE(&image, offset: mPath + 6, value: 1)

        let term = 22 * 2048
        image[term] = 0xFF
        for (i, b) in Array("CD001".utf8).enumerated() { image[term + 1 + i] = b }
        image[term + 6] = 0x01
    }

    private static func writeRootDirectoryRecords(
        _ image: inout [UInt8],
        placements: [(name: String, isoIdent: String, lba: Int, data: Data, paddedSectors: Int)]
    ) {
        let rootBase = 21 * 2048
        var cursor = rootBase
        cursor += writeDirectoryRecord(&image, baseOffset: cursor, extentLBA: 21, dataLength: 2048, flags: 0x02, identifier: [0x00])
        cursor += writeDirectoryRecord(&image, baseOffset: cursor, extentLBA: 21, dataLength: 2048, flags: 0x02, identifier: [0x01])

        for item in placements {
            let idBytes = Array(item.isoIdent.utf8)
            let recLen = 33 + idBytes.count + ((idBytes.count % 2 == 0) ? 1 : 0)
            guard (cursor - rootBase) + recLen <= 2048 else { break }
            cursor += writeDirectoryRecord(
                &image,
                baseOffset: cursor,
                extentLBA: UInt32(item.lba),
                dataLength: UInt32(item.data.count),
                flags: 0x00,
                identifier: idBytes
            )
        }
    }

    @discardableResult
    private static func writeDirectoryRecord(
        _ image: inout [UInt8],
        baseOffset: Int,
        extentLBA: UInt32,
        dataLength: UInt32,
        flags: UInt8,
        identifier: [UInt8]
    ) -> Int {
        let len = 33 + identifier.count + ((identifier.count % 2 == 0) ? 1 : 0)
        image[baseOffset] = UInt8(len)
        writeBothEndianUInt32(&image, offset: baseOffset + 2, value: extentLBA)
        writeBothEndianUInt32(&image, offset: baseOffset + 10, value: dataLength)
        image[baseOffset + 18] = 126
        image[baseOffset + 19] = 11
        image[baseOffset + 20] = 13
        image[baseOffset + 25] = flags
        writeBothEndianUInt16(&image, offset: baseOffset + 28, value: 1)
        image[baseOffset + 32] = UInt8(identifier.count)
        for (i, b) in identifier.enumerated() {
            image[baseOffset + 33 + i] = b
        }
        return len
    }

    private static func sanitizeISO9660Identifier(_ rawName: String) -> String {
        let upper = rawName.uppercased()
        let parts = upper.split(separator: ".", maxSplits: 1).map(String.init)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let stem = String(parts.first?.unicodeScalars.filter { allowed.contains($0) } ?? "FILE".unicodeScalars).prefix(8)
        let ext = parts.count > 1 ? String(parts[1].unicodeScalars.filter { allowed.contains($0) }).prefix(3) : "DAT"
        return "\(stem.isEmpty ? "FILE" : stem).\(ext.isEmpty ? "DAT" : ext);1"
    }

    private static func writeUInt16LE(_ buf: inout [UInt8], offset: Int, value: UInt16) {
        buf[offset] = UInt8(value & 0xFF)
        buf[offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    private static func writeUInt16BE(_ buf: inout [UInt8], offset: Int, value: UInt16) {
        buf[offset] = UInt8((value >> 8) & 0xFF)
        buf[offset + 1] = UInt8(value & 0xFF)
    }

    private static func writeBothEndianUInt16(_ buf: inout [UInt8], offset: Int, value: UInt16) {
        writeUInt16LE(&buf, offset: offset, value: value)
        writeUInt16BE(&buf, offset: offset + 2, value: value)
    }

    private static func writeUInt32LE(_ buf: inout [UInt8], offset: Int, value: UInt32) {
        buf[offset] = UInt8(value & 0xFF)
        buf[offset + 1] = UInt8((value >> 8) & 0xFF)
        buf[offset + 2] = UInt8((value >> 16) & 0xFF)
        buf[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    private static func writeUInt32BE(_ buf: inout [UInt8], offset: Int, value: UInt32) {
        buf[offset] = UInt8((value >> 24) & 0xFF)
        buf[offset + 1] = UInt8((value >> 16) & 0xFF)
        buf[offset + 2] = UInt8((value >> 8) & 0xFF)
        buf[offset + 3] = UInt8(value & 0xFF)
    }

    private static func writeBothEndianUInt32(_ buf: inout [UInt8], offset: Int, value: UInt32) {
        writeUInt32LE(&buf, offset: offset, value: value)
        writeUInt32BE(&buf, offset: offset + 4, value: value)
    }
}
