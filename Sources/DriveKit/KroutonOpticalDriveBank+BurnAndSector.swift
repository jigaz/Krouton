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
                // Locate actual .bin if user clicked on .cue
                let binURL: URL = lower.hasSuffix(".cue") ? parentDir.appendingPathComponent("\(baseName).bin") : sourceURL
                let outISO = parentDir.appendingPathComponent("\(baseName)_Converted.iso")
                let rawData = try Data(contentsOf: binURL)
                var isoData = Data()

                let rawSectorSize = 2352
                if rawData.count >= rawSectorSize && rawData.count % rawSectorSize == 0 {
                    let totalSectors = rawData.count / rawSectorSize
                    isoData.reserveCapacity(totalSectors * 2048)
                    for s in 0..<totalSectors {
                        let base = s * rawSectorSize
                        // Mode 1 payload is at +16 (after 12B sync + 4B header); Mode 2 Form 1 payload is at +24 (after +8B XA subheader)
                        let modeByte = rawData[base + 15]
                        let payloadOffset = (modeByte == 2) ? 24 : 16
                        let slice = rawData.subdata(in: (base + payloadOffset)..<(base + payloadOffset + 2048))
                        isoData.append(slice)
                    }
                } else {
                    // Already 2,048-byte aligned or non-standard stream
                    isoData = rawData
                }

                try isoData.write(to: outISO, options: .atomic)
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
                    sectorsWrittenLBA: Int64(max(1, isoData.count / 2048)),
                    bytesWritten: Int64(isoData.count),
                    averageSpeedText: "RAM Direct",
                    peakSpeedText: "RAM Direct",
                    elapsedDurationText: String(format: "%02d:%02d", secs / 60, secs % 60),
                    diagnosticAdvice: "The converted .iso image has been added to your workspace and can be mounted or burned immediately."
                )
                self.completionReport = rep
                return (outISO, rep)
            } else {
                // Convert 2,048 B/s .ISO -> 2,352 B/s Mode 1 .BIN + companion .CUE sheet!
                let outBIN = parentDir.appendingPathComponent("\(baseName).bin")
                let outCUE = parentDir.appendingPathComponent("\(baseName).cue")
                let isoData = try Data(contentsOf: sourceURL)
                let totalSectors = max(1, (isoData.count + 2047) / 2048)
                var binData = Data(capacity: totalSectors * 2352)
                let syncPattern: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
                let zeroTrailer = Data(count: 288) // 4B EDC + 8B Zero + 276B RSPC ECC

                for s in 0..<totalSectors {
                    binData.append(contentsOf: syncPattern)
                    let absFrames = s + 150 // 2-second lead-in offset
                    let mm = UInt8((absFrames / 75) / 60)
                    let ss = UInt8((absFrames / 75) % 60)
                    let ff = UInt8(absFrames % 75)
                    binData.append(contentsOf: [mm, ss, ff, 0x01]) // Mode 1 header
                    let startByte = s * 2048
                    let endByte = min(isoData.count, startByte + 2048)
                    if endByte > startByte {
                        binData.append(isoData.subdata(in: startByte..<endByte))
                    }
                    if endByte - startByte < 2048 {
                        binData.append(Data(count: 2048 - (endByte - startByte)))
                    }
                    binData.append(zeroTrailer)
                }

                try binData.write(to: outBIN, options: .atomic)
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
                    bytesWritten: Int64(binData.count),
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
