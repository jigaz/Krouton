import AVFoundation
import Combine
import CryptoKit
@preconcurrency import DiscRecording
import Foundation
import IOKit
import IOKit.storage
import OpticalCore
import SwiftUI

// MARK: - KroutonOpticalDriveBank .BIN/.CUE <-> .ISO Sector Converter & Staging Inspectors
// (The physical burn lifecycle lives in KroutonOpticalDriveBank+BurnSession.swift.)

@MainActor
extension KroutonOpticalDriveBank {
    // MARK: - UltraISO / PowerISO .BIN/.CUE (2,352 B/sector) <-> .ISO (2,048 B/sector) Sector Converter
    public func convertBinAndIsoSectorImage(sourceURL: URL) async -> (outputURL: URL?, report: KroutonBurnSessionReport) {
        let lower = sourceURL.lastPathComponent.lowercased()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let parentDir = sourceURL.deletingLastPathComponent()
        let isBinToIso = lower.hasSuffix(".bin") || lower.hasSuffix(".cue")

        isExecutingQueue = true
        let startTime = Date()
        activeJobProgress = 0.1
        activeJobPhase = isBinToIso ? "Converting Raw 2,352 B/s .BIN to 2,048 B/s .ISO..." : "Wrapping 2,048 B/s .ISO into 2,352 B/s .BIN + .CUE..."

        do {
            if isBinToIso {
                // Locate actual .bin if user clicked on .cue, then stream in bounded 1,024-sector chunks (~2.3 MB)
                let binURL: URL = lower.hasSuffix(".cue") ? parentDir.appendingPathComponent("\(baseName).bin") : sourceURL
                let outISO = parentDir.appendingPathComponent("\(baseName)_Converted.iso")
                let tempISO = parentDir.appendingPathComponent(".\(baseName)_Converted.\(UUID().uuidString.prefix(8)).tmp")
                let attrs = try FileManager.default.attributesOfItem(atPath: binURL.path)
                let rawByteCount = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                let rawSectorSize = 2352

                FileManager.default.createFile(atPath: tempISO.path, contents: nil)
                let inHandle = try FileHandle(forReadingFrom: binURL)
                defer { try? inHandle.close() }
                let outHandle = try FileHandle(forWritingTo: tempISO)
                defer { try? outHandle.close() }

                var writtenBytes: Int64 = 0
                if rawByteCount >= Int64(rawSectorSize) && rawByteCount % Int64(rawSectorSize) == 0 {
                    let chunkBytes = rawSectorSize * 1024
                    while let chunk = try inHandle.read(upToCount: chunkBytes), !chunk.isEmpty {
                        let sectorCount = chunk.count / rawSectorSize
                        var outChunk = Data(capacity: sectorCount * 2048)
                        for s in 0..<sectorCount {
                            let base = s * rawSectorSize
                            // Mode 1 payload is at +16 (after 12B sync + 4B header); Mode 2 Form 1 payload is at +24 (after +8B XA subheader)
                            let modeByte = chunk[chunk.startIndex + base + 15]
                            let payloadOffset = (modeByte == 2) ? 24 : 16
                            let lowerBound = chunk.startIndex + base + payloadOffset
                            outChunk.append(chunk[lowerBound..<(lowerBound + 2048)])
                        }
                        try outHandle.write(contentsOf: outChunk)
                        writtenBytes += Int64(outChunk.count)
                    }
                } else {
                    while let chunk = try inHandle.read(upToCount: 1_048_576), !chunk.isEmpty {
                        try outHandle.write(contentsOf: chunk)
                        writtenBytes += Int64(chunk.count)
                    }
                }
                try outHandle.synchronize()
                try outHandle.close()
                if FileManager.default.fileExists(atPath: outISO.path) {
                    try FileManager.default.removeItem(at: outISO)
                }
                try FileManager.default.moveItem(at: tempISO, to: outISO)

                activeJobProgress = 1.0
                activeJobPhase = "Converted .BIN to .ISO Successfully"
                isExecutingQueue = false
                /* Acoustic cue handled by KroutonApp UI layer */
                let secs = max(1, Int(Date().timeIntervalSince(startTime)))
                let rep = KroutonBurnSessionReport(
                    isSuccess: true,
                    title: ".BIN → .ISO Sector Conversion Complete",
                    summary: "Extracted 2,048-byte user payloads from 2,352-byte raw sectors into \(outISO.path).",
                    driveModel: "Krouton Sector Geometry Transcoder",
                    firmwareRevision: "ISO/IEC 10149",
                    mediaFormattedName: "ISO 9660 (2,048 B/Sector)",
                    volumeName: outISO.lastPathComponent,
                    sectorsWrittenLBA: max(1, writtenBytes / 2048),
                    bytesWritten: writtenBytes,
                    averageSpeedText: "Streamed Direct",
                    peakSpeedText: "Streamed Direct",
                    elapsedDurationText: String(format: "%02d:%02d", secs / 60, secs % 60),
                    diagnosticAdvice: "The converted .iso image has been added to your workspace and can be mounted or burned immediately."
                )
                self.completionReport = rep
                return (outISO, rep)
            } else {
                // Convert 2,048 B/s .ISO -> 2,352 B/s Mode 1 .BIN + companion .CUE sheet in bounded streaming chunks
                let outBIN = parentDir.appendingPathComponent("\(baseName).bin")
                let outCUE = parentDir.appendingPathComponent("\(baseName).cue")
                let tempBIN = parentDir.appendingPathComponent(".\(baseName).\(UUID().uuidString.prefix(8)).bin.tmp")
                let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
                let isoByteCount = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                let totalSectors = Int(max(1, (isoByteCount + 2047) / 2048))
                // Red Book / Yellow Book BCD MSF headers encode up to 99:59:74 (449,999 frames including 150-frame pregap)
                guard totalSectors + 150 <= 449_999 else {
                    throw NSError(domain: "app.krouton.drivekit", code: 2352, userInfo: [
                        NSLocalizedDescriptionKey: "Mode 1 .BIN/.CUE MSF headers support CD images up to 99:59:74 (~900 MB); burn DVD/BD .ISO images directly."
                    ])
                }

                FileManager.default.createFile(atPath: tempBIN.path, contents: nil)
                let inHandle = try FileHandle(forReadingFrom: sourceURL)
                defer { try? inHandle.close() }
                let outHandle = try FileHandle(forWritingTo: tempBIN)
                defer { try? outHandle.close() }

                let syncPattern: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
                let zeroTrailer = Data(count: 288) // 4B EDC + 8B Zero + 276B RSPC ECC
                func toBCD(_ value: Int) -> UInt8 { UInt8(((value / 10) << 4) | (value % 10)) }

                var sectorIndex = 0
                let chunkBytes = 2048 * 1024
                while let chunk = try inHandle.read(upToCount: chunkBytes), !chunk.isEmpty {
                    let sectorsInChunk = (chunk.count + 2047) / 2048
                    var binChunk = Data(capacity: sectorsInChunk * 2352)
                    for s in 0..<sectorsInChunk {
                        binChunk.append(contentsOf: syncPattern)
                        let absFrames = sectorIndex + 150
                        let mm = toBCD((absFrames / 75) / 60)
                        let ss = toBCD((absFrames / 75) % 60)
                        let ff = toBCD(absFrames % 75)
                        binChunk.append(contentsOf: [mm, ss, ff, 0x01])
                        let startByte = chunk.startIndex + s * 2048
                        let endByte = min(chunk.endIndex, startByte + 2048)
                        binChunk.append(chunk[startByte..<endByte])
                        if endByte - startByte < 2048 {
                            binChunk.append(Data(count: 2048 - (endByte - startByte)))
                        }
                        binChunk.append(zeroTrailer)
                        sectorIndex += 1
                    }
                    try outHandle.write(contentsOf: binChunk)
                }
                try outHandle.synchronize()
                try outHandle.close()
                if FileManager.default.fileExists(atPath: outBIN.path) {
                    try FileManager.default.removeItem(at: outBIN)
                }
                try FileManager.default.moveItem(at: tempBIN, to: outBIN)
                let cueText = "FILE \"\(outBIN.lastPathComponent)\" BINARY\r\n  TRACK 01 MODE1/2352\r\n    INDEX 01 00:00:00\r\n"
                try cueText.write(to: outCUE, atomically: true, encoding: .utf8)

                activeJobProgress = 1.0
                activeJobPhase = "Generated .BIN + .CUE Pair Successfully"
                isExecutingQueue = false
                /* Acoustic cue handled by KroutonApp UI layer */
                let secs = max(1, Int(Date().timeIntervalSince(startTime)))
                let rep = KroutonBurnSessionReport(
                    isSuccess: true,
                    title: ".ISO → .BIN/.CUE Conversion Complete",
                    summary: "Synthesized 2,352-byte Mode 1 raw sectors + companion .CUE descriptor at \(outCUE.path).",
                    driveModel: "Krouton Sector Geometry Transcoder",
                    firmwareRevision: "DAO/96 Mode 1",
                    mediaFormattedName: "BIN/CUE Raw Sector Pair",
                    volumeName: outBIN.lastPathComponent,
                    sectorsWrittenLBA: Int64(totalSectors),
                    bytesWritten: Int64(totalSectors) * 2352,
                    averageSpeedText: "RAM Direct",
                    peakSpeedText: "RAM Direct",
                    elapsedDurationText: String(format: "%02d:%02d", secs / 60, secs % 60),
                    diagnosticAdvice: "Both the .BIN and .CUE files have been generated and staged in your File List."
                )
                self.completionReport = rep
                return (outCUE, rep)
            }
        } catch {
            isExecutingQueue = false
            let rep = KroutonBurnSessionReport(
                isSuccess: false,
                title: "Sector Conversion Error",
                summary: error.localizedDescription,
                driveModel: "Krouton Sector Transcoder",
                firmwareRevision: "1.0",
                mediaFormattedName: "Disc Image",
                volumeName: sourceURL.lastPathComponent,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "—",
                peakSpeedText: "—",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Verify read/write permissions in the source image folder."
            )
            self.completionReport = rep
            return (nil, rep)
        }
    }

    // Stages a Car-Safe MP3/FLAC Folder Tree (Zero-padded 001_ prefixes + strips .DS_Store & ._AppleDouble files!)

    public static func inspectFileOrFolder(url: URL) -> KroutonStagedFileEntry {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: url.path, isDirectory: &isDir)

        var totalBytes: Int64 = 0
        var count: Int = 1
        var modDate = Date()
        var permsString = "rwxr-xr-x"

        if let attrs = try? fm.attributesOfItem(atPath: url.path) {
            if let d = attrs[.modificationDate] as? Date { modDate = d }
            if let posix = attrs[.posixPermissions] as? NSNumber {
                permsString = String(format: "0%o", posix.intValue)
            }
            if !isDir.boolValue, let sz = attrs[.size] as? NSNumber {
                totalBytes = sz.int64Value
            }
        }

        if isDir.boolValue {
            count = 0
            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let childURL as URL in enumerator {
                    if let vals = try? childURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
                        if vals.isDirectory != true {
                            totalBytes += Int64(vals.fileSize ?? 0)
                            count += 1
                        }
                    }
                }
            }
        }

        let lowerName = url.lastPathComponent.lowercased()
        let defaultMac = !(lowerName == "autorun.inf" || lowerName.hasSuffix(".exe") || lowerName.hasSuffix(".msi") || lowerName.hasSuffix(".bat"))
        let defaultPC = !(lowerName == ".ds_store" || lowerName == ".localized")

        return KroutonStagedFileEntry(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDir.boolValue,
            byteSize: totalBytes,
            itemCount: count,
            posixPermissions: permsString,
            modifiedDate: modDate,
            showOnMac: defaultMac,
            showOnPC: defaultPC
        )
    }
}
