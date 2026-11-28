import Foundation

// MARK: - Disc Image Operations (inspect, convert, mount, verify)

/// What the image inspector shows about one file.
public struct DiscImageInspectionReport: Sendable, Equatable {
    /// The file that was inspected.
    public let fileURL: URL
    /// Its name.
    public let fileName: String
    /// The size of the data file (the .bin for a .cue).
    public let byteSize: Int64
    /// File systems, boot format and suggested blank.
    public let classification: KroutonDiscImageClassification
    let bootClassification: DiscImageBootClassification
    /// The cue sheet's tracks, when there is one.
    public let cueTracks: [KroutonDiscImageCueTrack]
    /// The .bin a .cue names, when it was found.
    public let resolvedBinURL: URL?
}

/// File operations on disc images: inspect, convert between .bin and .iso and between .dmg and
/// .iso, mount, and verify. The `hdiutil` calls run as a `Process` with an argument array and block
/// until it exits.
public enum DiscImageDepotOperations {
    /// Inspects any `.iso`, `.dmg`, `.cdr`, `.img`, `.bin`, or `.cue` file on disk using `KroutonDiscImageDepot`.
    public static func inspectImageFile(at url: URL) -> DiscImageInspectionReport {
        let fm = FileManager.default
        let lowerExt = url.pathExtension.lowercased()
        var targetDataURL = url
        var cueTracks: [KroutonDiscImageCueTrack] = []
        var resolvedBinURL: URL? = nil

        if lowerExt == "cue", let cueText = try? String(contentsOf: url, encoding: .utf8) {
            cueTracks = KroutonDiscImageDepot.parseCueSheet(cueText)
            if let binCandidate = resolveCompanionBinURL(forCueURL: url, cueText: cueText),
               fm.fileExists(atPath: binCandidate.path) {
                resolvedBinURL = binCandidate
                targetDataURL = binCandidate
            }
        } else if lowerExt == "bin" {
            let cueSibling = url.deletingPathExtension().appendingPathExtension("cue")
            if fm.fileExists(atPath: cueSibling.path),
               let cueText = try? String(contentsOf: cueSibling, encoding: .utf8) {
                cueTracks = KroutonDiscImageDepot.parseCueSheet(cueText)
            }
        }

        let fileSize = Int64((try? targetDataURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        // The first 600 KB: sectors 0 to 299, which hold the ISO 9660 descriptors (16 on), an El
        // Torito record (17) and the UDF anchor (256).
        var headerData = Data()
        if let fh = try? FileHandle(forReadingFrom: targetDataURL) {
            defer { try? fh.close() }
            headerData = (try? fh.read(upToCount: 614_400)) ?? Data()
        }

        let asciiSample = String(decoding: headerData, as: UTF8.self)
        let classification = KroutonDiscImageDepot.classifyDepotImage(
            byteSize: fileSize,
            signatureSampleASCII: asciiSample
        )
        let bootClass = KroutonDiscImageDepot.classifyBootableImage(headerBytes: headerData)

        return DiscImageInspectionReport(
            fileURL: url,
            fileName: url.lastPathComponent,
            byteSize: fileSize,
            classification: classification,
            bootClassification: bootClass,
            cueTracks: cueTracks,
            resolvedBinURL: resolvedBinURL
        )
    }

    /// Resolves the `FILE "..." BINARY` path referenced inside a `.cue` sheet (or sibling `.bin`).
    static func resolveCompanionBinURL(forCueURL cueURL: URL, cueText: String) -> URL? {
        let dir = cueURL.deletingLastPathComponent()
        for rawLine in cueText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.uppercased().hasPrefix("FILE "),
               let q1 = line.firstIndex(of: "\""),
               let q2 = line.lastIndex(of: "\""),
               q1 < q2 {
                let relName = String(line[line.index(after: q1)..<q2])
                let candidate = dir.appendingPathComponent(relName)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        let sibling = cueURL.deletingPathExtension().appendingPathExtension("bin")
        return FileManager.default.fileExists(atPath: sibling.path) ? sibling : nil
    }

    /// Converts a raw 2,352-byte-sector `.bin` (or the `.bin` a `.cue` names) into a 2,048-byte-
    /// sector `.iso`, keeping each sector's user data. Returns the bytes written.
    public static func extractRawBinToISO(sourceURL: URL, outputISOURL: URL) throws -> Int64 {
        let fm = FileManager.default
        var binURL = sourceURL
        if sourceURL.pathExtension.lowercased() == "cue" {
            let cueText = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
            if let resolved = resolveCompanionBinURL(forCueURL: sourceURL, cueText: cueText) {
                binURL = resolved
            }
        }

        if fm.fileExists(atPath: outputISOURL.path) {
            try fm.removeItem(at: outputISOURL)
        }
        fm.createFile(atPath: outputISOURL.path, contents: nil)

        let inHandle = try FileHandle(forReadingFrom: binURL)
        defer { try? inHandle.close() }
        let outHandle = try FileHandle(forWritingTo: outputISOURL)
        defer { try? outHandle.close() }

        let fileBytes = Int64((try? binURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        // A size that divides by 2352 isn't enough (one ISO in 147 has one): raw sectors start
        // with the CD-ROM sync pattern.
        let head = try inHandle.read(upToCount: 12) ?? Data()
        try inHandle.seek(toOffset: 0)
        let isRaw2352 = fileBytes > 0 && fileBytes % 2352 == 0 && [UInt8](head) == KroutonDiscImageDepot.cdRomSyncPattern
        let sectorStride = isRaw2352 ? 2352 : 2048
        let batchSectors = 512
        var writtenBytes: Int64 = 0

        while true {
            guard let chunk = try inHandle.read(upToCount: sectorStride * batchSectors), !chunk.isEmpty else { break }
            if !isRaw2352 {
                try outHandle.write(contentsOf: chunk)
                writtenBytes += Int64(chunk.count)
            } else {
                var outBatch = Data()
                outBatch.reserveCapacity((chunk.count / 2352) * 2048)
                var offset = 0
                while offset + 2352 <= chunk.count {
                    let rawSec = chunk.subdata(in: offset..<(offset + 2352))
                    if let iso2048 = KroutonDiscImageDepot.extractISO2048SectorFromRaw2352(rawSec) {
                        outBatch.append(iso2048)
                    }
                    offset += 2352
                }
                if !outBatch.isEmpty {
                    try outHandle.write(contentsOf: outBatch)
                    writtenBytes += Int64(outBatch.count)
                }
            }
        }
        return writtenBytes
    }

    /// Converts `.dmg` -> `.iso` (via `hdiutil convert -format UDTO -ov` + `.cdr` rename) or `.iso`/`.cdr` -> `.dmg` (`UDZO`).
    public static func convertDiskImageWithHdiutil(sourceURL: URL, outputURL: URL) throws -> Int64 {
        let fm = FileManager.default
        if fm.fileExists(atPath: outputURL.path) {
            try? fm.removeItem(at: outputURL)
        }
        let targetExt = outputURL.pathExtension.lowercased()
        let formatArg = (targetExt == "iso" || targetExt == "cdr") ? "UDTO" : "UDZO"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["convert", sourceURL.path, "-format", formatArg, "-ov", "-o", outputURL.path]
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()

        // hdiutil convert -format UDTO appends .cdr when target ends in .iso
        let cdrCandidate = URL(fileURLWithPath: outputURL.path + ".cdr")
        if !fm.fileExists(atPath: outputURL.path), fm.fileExists(atPath: cdrCandidate.path) {
            try fm.moveItem(at: cdrCandidate, to: outputURL)
        }

        guard proc.terminationStatus == 0, fm.fileExists(atPath: outputURL.path) else {
            let msg = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "DiscImageDepotOperations", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: msg.isEmpty ? "hdiutil convert failed (\(proc.terminationStatus))" : msg
            ])
        }
        return Int64((try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }

    /// Mounts an `.iso`, `.dmg`, `.cdr`, or `.img` in macOS Finder via `/usr/bin/hdiutil attach`.
    public static func mountDiskImageInFinder(url: URL) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["attach", url.path]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            let msg = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "DiscImageDepotOperations", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: msg.isEmpty ? "Unable to mount \(url.lastPathComponent)" : msg
            ])
        }
        let outText = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if let volLine = outText.components(separatedBy: .newlines).first(where: { $0.contains("/Volumes/") }),
           let range = volLine.range(of: "/Volumes/") {
            return String(volLine[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Mounted in Finder"
    }

    /// Writes a 36-sector test image with the signatures of an ISO 9660 primary volume
    /// descriptor, an El Torito boot record and boot catalog, and `manifestText` from sector 20.
    /// It is not a complete ISO 9660 volume (no volume size, root directory or path tables, no
    /// validation-entry checksum) and doesn't boot. Only krouton-verify uses it.
    public static func writeBootableDepotISO(volumeID: String, manifestText: String, destinationURL: URL) throws {
        let sectorSize = 2048
        let totalSectors = 36
        var image = Data(count: totalSectors * sectorSize)

        // LBA 16: Primary Volume Descriptor (PVD)
        let pvdOffset = 16 * sectorSize
        image[pvdOffset] = 0x01
        for (i, b) in Array("CD001".utf8).enumerated() { image[pvdOffset + 1 + i] = b }
        image[pvdOffset + 6] = 0x01
        let sysID = Array("KROUTON OPTICAL MASTERING ENGINE".padding(toLength: 32, withPad: " ", startingAt: 0).utf8)
        for (i, b) in sysID.prefix(32).enumerated() { image[pvdOffset + 8 + i] = b }
        let volIDClean = Array(volumeID.uppercased().replacingOccurrences(of: "-", with: "_").padding(toLength: 32, withPad: " ", startingAt: 0).utf8)
        for (i, b) in volIDClean.prefix(32).enumerated() { image[pvdOffset + 40 + i] = b }

        // LBA 17: El Torito Boot Record Volume Descriptor
        let brvdOffset = 17 * sectorSize
        image[brvdOffset] = 0x00
        for (i, b) in Array("CD001".utf8).enumerated() { image[brvdOffset + 1 + i] = b }
        image[brvdOffset + 6] = 0x01
        for (i, b) in Array("EL TORITO SPECIFICATION".utf8).enumerated() { image[brvdOffset + 7 + i] = b }
        // Boot Catalog pointer at LBA 18 (little-endian UInt32 at offset +71)
        image[brvdOffset + 71] = 18

        // LBA 18: El Torito Validation Entry + Default Boot Entry (LBA 20)
        let catOffset = 18 * sectorSize
        image[catOffset] = 0x01
        image[catOffset + 30] = 0x55
        image[catOffset + 31] = 0xAA
        image[catOffset + 32] = 0x88
        image[catOffset + 40] = 20

        // LBA 19: Volume Descriptor Set Terminator
        let termOffset = 19 * sectorSize
        image[termOffset] = 0xFF
        for (i, b) in Array("CD001".utf8).enumerated() { image[termOffset + 1 + i] = b }
        image[termOffset + 6] = 0x01

        // LBA 20+: Manifest & Disc Content Schematic payload
        let payloadOffset = 20 * sectorSize
        for (i, b) in Array(manifestText.utf8).prefix((totalSectors - 20) * sectorSize).enumerated() {
            image[payloadOffset + i] = b
        }

        try image.write(to: destinationURL, options: .atomic)
    }

    /// Verifies image container integrity and checksums via `/usr/bin/hdiutil verify`.
    public static func verifyDiskImageIntegrity(url: URL) -> (isValid: Bool, summary: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["verify", url.path]
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                return (true, "Verified OK (hdiutil checksum valid)")
            }
            let msg = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (false, msg.isEmpty ? "Verification failed (\(proc.terminationStatus))" : msg)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
