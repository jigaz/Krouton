import DiscRecording
import DiskArbitration
import Foundation
import OpticalCore

// MARK: - KroutonOpticalDriveBank — VolumeScanner

extension KroutonOpticalDriveBank {
    // Resolves the underlying BSD device name (e.g. "disk4" or "disk4s1") for a mounted volume URL via DiskArbitration
    private static func bsdDeviceNameForVolumeURL(_ url: URL, session: DASession?) -> String? {
        guard let session = session,
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
              let cName = DADiskGetBSDName(disk) else {
            return nil
        }
        return String(cString: cName)
    }

    // Scans ONLY the mounted volumes residing on the selected optical drive's BSD device (e.g. /dev/disk4 -> disk4 / disk4s1)
    public static func scanMountedOpticalVolumes(bsdName: String?, isMediaPresent: Bool, isMediaBlank: Bool, usedBytes: Int64) -> [KroutonMountedDiscVolume] {
        guard isMediaPresent && !isMediaBlank,
              let rawTargetBSD = bsdName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTargetBSD.isEmpty,
              rawTargetBSD.lowercased() != "unmounted" else {
            return []
        }

        // Normalize "/dev/rdisk4" or "/dev/disk4s1" -> base whole-disc BSD identifier "disk4"
        let stripped = rawTargetBSD
            .replacingOccurrences(of: "/dev/rdisk", with: "disk")
            .replacingOccurrences(of: "/dev/disk", with: "disk")
        let baseWholeDisk: String = {
            if let sRange = stripped.range(of: #"^disk\d+"#, options: .regularExpression) {
                return String(stripped[sRange])
            }
            return stripped
        }()
        guard baseWholeDisk.hasPrefix("disk") else { return [] }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeCreationDateKey
        ]

        guard let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }

        let daSession = DASessionCreate(kCFAllocatorDefault)
        var results: [KroutonMountedDiscVolume] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        for url in urls {
            guard url.path != "/",
                  url.path.hasPrefix("/Volumes/"),
                  let volBSD = bsdDeviceNameForVolumeURL(url, session: daSession),
                  (volBSD == baseWholeDisk || volBSD.hasPrefix(baseWholeDisk + "s")),
                  let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }

            let formatDesc = vals.volumeLocalizedFormatDescription ?? "ISO 9660 / HFS+"
            let lowerFormat = formatDesc.lowercased()

            let volName = vals.volumeName ?? url.lastPathComponent
            let isAudio = lowerFormat.contains("audio") || lowerFormat.contains("cd-da") || lowerFormat.contains("cdda")

            // Fast top-level item count so main thread never blocks during app launch
            let topItems = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            let count = topItems.count

            let totalCap = Int64(vals.volumeTotalCapacity ?? Int(max(usedBytes, 0)))
            let availCap = Int64(vals.volumeAvailableCapacity ?? 0)
            let usedCap = max(0, totalCap - availCap)
            let createdStr = vals.volumeCreationDate.map { dateFormatter.string(from: $0) } ?? "Mastered Session"

            results.append(KroutonMountedDiscVolume(
                id: url.path,
                volumeName: volName,
                filesystemFormat: formatDesc,
                mountPath: url.path,
                itemCount: count,
                isAudioCD: isAudio,
                usedBytes: usedCap > 0 ? usedCap : usedBytes,
                totalBytes: totalCap > 0 ? totalCap : usedBytes,
                creationDateText: createdStr
            ))
        }

        return results
    }

    public static func formatHumanBurnState(_ rawState: String, isErase: Bool = false) -> String {
        switch rawState {
        case DRStatusStatePreparing:
            return isErase ? "Preparing Optical Drive & Laser..." : "Calibrating Laser Power (OPC) & Preparing Track..."
        case DRStatusStateSessionOpen:
            return "Opening Disc Session & Writing Lead-In TOC..."
        case DRStatusStateTrackOpen:
            return "Opening Data Track & Syncing Drive Buffer..."
        case DRStatusStateTrackWrite:
            return "Writing Sectors to Optical Media..."
        case DRStatusStateTrackClose:
            return "Closing Track & Flushing Hardware Cache..."
        case DRStatusStateSessionClose:
            return "Closing Session & Writing Lead-Out..."
        case DRStatusStateFinishing:
            return "Finalizing Disc & Updating PMA/TOC..."
        case DRStatusStateVerifying:
            return "Verifying Written Sectors Against Source..."
        case DRStatusStateErasing:
            return "Erasing Rewritable Phase-Change Layer (PMA/TOC)..."
        case DRStatusStateDone:
            return isErase ? "Rewritable Disc Erased & Ready" : "Burn & Verification Complete"
        case DRStatusStateFailed:
            return isErase ? "Disc Erase Failed" : "Optical Burn Failed"
        default:
            let cleaned = rawState.replacingOccurrences(of: "DRStatusState", with: "")
            return cleaned.isEmpty ? "Active..." : cleaned
        }
    }

}
