import AudioKit
import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI
import UniformTypeIdentifiers
import VideoKit

// MARK: - Optical Audio CD Scanning, MusicBrainz Lookup & Extraction Pipeline

extension KroutonCopyAndRipWorkspaceView {
    func rescanOpticalDiscForCopyTask(isAudioRipTask: Bool, isShrinkTask: Bool, fetchMetadata: Bool = false) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        isScanningTOC = true
        store.refreshOpticalDrives()
        if isAudioRipTask {
            if let liveCD = KroutonRealCDExtractor.scanMountedAudioCD(preferredMountPath: copySourceOverrideLabel) {
                mountedCDSnapshot = liveCD
                if cdTextAlbumTitle.isEmpty || cdTextAlbumTitle.hasPrefix("Audio CD") {
                    cdTextAlbumTitle = liveCD.albumTitle
                }
                if !liveCD.albumPerformer.isEmpty {
                    cdTextAlbumPerformer = liveCD.albumPerformer
                }
                audioRipTracks = liveCD.tracks.map { t in
                    KroutonRipTrackItem(
                        num: t.trackNumber,
                        title: t.title,
                        performer: "LBA \(t.startBlockLBA) • \(ByteCountFormatter.string(fromByteCount: t.byteSize, countStyle: .file))",
                        duration: t.durationMMSSFF,
                        arStatus: "Ready [PCM 44.1k/16b]"
                    )
                }
                audioRipSelectedTracks = Set(liveCD.tracks.map(\.trackNumber))
                copyStatusBanner = "Scanned TOC [\(stamp)]: \(liveCD.tracks.count) Audio Tracks (\(ByteCountFormatter.string(fromByteCount: liveCD.totalPCMBytes, countStyle: .file)) • DiscID \(liveCD.musicBrainzDiscID))"
                if store.voiceOverSpokenTelemetry { store.announceForVoiceOver("Scanned Audio CD Table of Contents: \(liveCD.tracks.count) tracks ready.") }
                if fetchMetadata {
                    lookupMusicBrainzMetadata(for: liveCD)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isScanningTOC = false }
                }
            } else {
                mountedCDSnapshot = nil
                audioRipTracks = []
                audioRipSelectedTracks = []
                copyStatusBanner = "Scanned [\(stamp)]: No Audio CD mounted in /Volumes."
                isScanningTOC = false
            }
        } else {
            if let disc = OpticalDiscVolumeScanner.scanMountedVideoOrDataDisc(preferredPath: copySourceOverrideLabel) {
                scannedVideoDisc = disc
                videoExtractTitles = disc.titles
                videoExtractSelectedTitles = Set(disc.titles.map(\.id))
                if store.discVolumeTitle.isEmpty {
                    store.discVolumeTitle = disc.volumeTitle
                }
                let sizeStr = ByteCountFormatter.string(fromByteCount: disc.totalBytes, countStyle: .file)
                copyStatusBanner = "Scanned \(disc.discKind) [\(stamp)]: \(disc.volumeTitle) • \(disc.titles.count) Title(s) (\(sizeStr) • \(disc.totalSectorsLBA) LBA)"
            } else {
                scannedVideoDisc = nil
                videoExtractTitles = []
                videoExtractSelectedTitles = []
                copyStatusBanner = "Scanned [\(stamp)]: No mounted VIDEO_TS, BDMV, or Optical volume found in /Volumes (use Folder... to select a source directory)."
            }
            isScanningTOC = false
        }
    }

    func lookupMusicBrainzMetadata(for snap: KroutonMountedAudioCDSnapshot) {
        isScanningTOC = true
        copyStatusBanner = "Querying MusicBrainz for DiscID \(snap.musicBrainzDiscID)..."
        guard let url = URL(string: "https://musicbrainz.org/ws/2/discid/\(snap.musicBrainzDiscID)?inc=recordings+artists&fmt=json") else {
            isScanningTOC = false
            return
        }
        var req = URLRequest(url: url)
        req.setValue("KroutonOpticalArchiver/1.0 (https://krouton.app)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 6.0
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                self.isScanningTOC = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let releases = json["releases"] as? [[String: Any]],
                      let firstRel = releases.first else {
                    let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    self.copyStatusBanner = "TOC Verified [\(stamp)]: \(snap.tracks.count) Audio Tracks • DiscID \(snap.musicBrainzDiscID) (Custom/Unlisted CD — edit names inline or in CD Info)"
                    return
                }
                if let title = firstRel["title"] as? String, !title.isEmpty {
                    self.cdTextAlbumTitle = title
                }
                if let dateStr = firstRel["date"] as? String, !dateStr.isEmpty {
                    self.cdInfoYear = String(dateStr.prefix(4))
                }
                if let credits = firstRel["artist-credit"] as? [[String: Any]],
                   let firstArtist = credits.first?["name"] as? String {
                    self.cdTextAlbumPerformer = firstArtist
                }
                if let media = firstRel["media"] as? [[String: Any]],
                   let tracks = media.first?["tracks"] as? [[String: Any]] {
                    for tObj in tracks {
                        if let numStr = tObj["number"] as? String, let tNum = Int(numStr),
                           let tTitle = tObj["title"] as? String,
                           let idx = self.audioRipTracks.firstIndex(where: { $0.num == tNum }) {
                            self.audioRipTracks[idx].title = tTitle
                        }
                    }
                }
                self.copyStatusBanner = "Matched MusicBrainz Release: \(self.cdTextAlbumPerformer) — \(self.cdTextAlbumTitle)"
            }
        }.resume()
    }

    func startHardwareAudioCDExtraction(onlyTrackNumber: Int?) {
        guard !isRippingCD else { return }
        let snap = mountedCDSnapshot ?? KroutonRealCDExtractor.scanMountedAudioCD()
        guard let cd = snap else {
            copyStatusBanner = "Insert an Audio CD into your optical drive first (/Volumes/Audio CD/.TOC.plist not found)."
            return
        }
        let selectedNums: Set<Int> = onlyTrackNumber != nil ? [onlyTrackNumber!] : audioRipSelectedTracks
        let editedTitles = Dictionary(uniqueKeysWithValues: audioRipTracks.map { ($0.num, $0.title) })
        let selected: [KroutonMountedCDTrackDescriptor] = cd.tracks.compactMap { t in
            guard selectedNums.contains(t.trackNumber) else { return nil }
            var copy = t
            if let customTitle = editedTitles[t.trackNumber], !customTitle.isEmpty { copy.title = customTitle }
            return copy
        }
        guard !selected.isEmpty else {
            copyStatusBanner = "Select at least one track to rip."
            return
        }
        let expandedBase = (copyOutputFolderPath as NSString).expandingTildeInPath
        let baseRoot = expandedBase.hasPrefix("/Volumes/Audio CD") ? ("~/Music/Krouton Rips" as NSString).expandingTildeInPath : expandedBase
        let safeAlbum = cdTextAlbumTitle.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let outDir = URL(fileURLWithPath: baseRoot).appendingPathComponent(safeAlbum.isEmpty ? "Audio CD Rip" : safeAlbum)
        let chosenCodec = audioRipCodec
        let writeCueLog = audioRipGenerateCueLog
        let albTitle = cdTextAlbumTitle
        let albPerf = cdTextAlbumPerformer
        let token = KroutonRipCancelToken()
        ripCancelToken = token
        isRippingCD = true
        ripProgressFraction = 0.01
        copyStatusBanner = "Spinning up optical drive for \(selected.count) track(s) -> \(outDir.lastPathComponent)..."
        KroutonNotificationAndCompanionService.shared.dispatchEvent(
            id: "start",
            title: "Audio CD Extraction Started",
            subtitle: "Ripping \(selected.count) track(s) from \(cd.albumTitle) to \(chosenCodec)",
            progress: 0.02,
            driveName: primarySelectedDrive?.displayName ?? "Optical Drive",
            speedLabel: chosenCodec,
            store: store
        )

        DispatchQueue.global(qos: .userInitiated).async {
            var logLines = [
                "KROUTON HARDWARE RED BOOK AUDIO CD EXTRACTION LOG",
                "Source Mount: \(cd.mountPath) | DiscID: \(cd.musicBrainzDiscID) | Leadout LBA: \(cd.leadoutBlockLBA)",
                "Album: \(albTitle) | Artist: \(albPerf) | Codec: \(chosenCodec)",
                "------------------------------------------------------------------------"
            ]
            var cueLines = ["REM DISCID \(cd.musicBrainzDiscID)", "PERFORMER \"\(albPerf)\"", "TITLE \"\(albTitle)\""]
            let totalTracks = Double(selected.count)
            var okCount = 0, errCount = 0, cancelCount = 0
            for (idx, trk) in selected.enumerated() {
                if token.isCancelled {
                    cancelCount += 1
                    DispatchQueue.main.async {
                        if let rIdx = audioRipTracks.firstIndex(where: { $0.num == trk.trackNumber }) {
                            audioRipTracks[rIdx].arStatus = "Cancelled"
                        }
                    }
                    continue
                }
                DispatchQueue.main.async {
                    activeRippingTrackNum = trk.trackNumber
                    perTrackProgress[trk.trackNumber] = 0.0
                    copyStatusBanner = "Converting Track \(String(format: "%02d", trk.trackNumber))/\(selected.count): \(trk.title)..."
                    if let rIdx = audioRipTracks.firstIndex(where: { $0.num == trk.trackNumber }) {
                        audioRipTracks[rIdx].arStatus = "Converting (0%)..."
                    }
                }
                do {
                    let res = try KroutonRealCDExtractor.extractSingleTrack(
                        track: trk, codecLabel: chosenCodec, outputDirectory: outDir,
                        shouldCancel: { token.isCancelled || token.cancelledTracks.contains(trk.trackNumber) }
                    ) { trackFrac, bytesDone in
                        let overall = (Double(idx) + trackFrac) / totalTracks
                        let mbDone = Double(bytesDone) / (1024.0 * 1024.0)
                        let mbTotal = Double(trk.byteSize) / (1024.0 * 1024.0)
                        DispatchQueue.main.async {
                            ripProgressFraction = overall
                            perTrackProgress[trk.trackNumber] = trackFrac
                            copyStatusBanner = String(format: "Track %02d/%02d: %.1f / %.1f MB (%.0f%%)", trk.trackNumber, selected.count, mbDone, mbTotal, trackFrac * 100.0)
                        }
                    }
                    okCount += 1
                    let statusBadge = "CRC \(res.crc32Hex) • AR \(res.accurateRipV1Hex)"
                    logLines.append(String(format: "Track %02d : %@ | %lld bytes | CRC32: %@ | AccurateRip: %@", trk.trackNumber, res.outputURL.lastPathComponent, res.bytesWritten, res.crc32Hex, res.accurateRipV1Hex))
                    cueLines.append("FILE \"\(res.outputURL.lastPathComponent)\" WAVE")
                    cueLines.append(String(format: "  TRACK %02d AUDIO", trk.trackNumber))
                    cueLines.append("    TITLE \"\(trk.title)\"")
                    cueLines.append("    INDEX 01 00:00:00")
                    DispatchQueue.main.async {
                        perTrackProgress[trk.trackNumber] = 1.0
                        if let rowIdx = audioRipTracks.firstIndex(where: { $0.num == trk.trackNumber }) {
                            audioRipTracks[rowIdx].arStatus = statusBadge
                        }
                    }
                } catch {
                    let isCancelledErr = (error as NSError).code == -999
                    if isCancelledErr { cancelCount += 1 } else { errCount += 1 }
                    logLines.append("Track \(trk.trackNumber) \(isCancelledErr ? "CANCELLED" : "ERROR"): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        if let rowIdx = audioRipTracks.firstIndex(where: { $0.num == trk.trackNumber }) {
                            audioRipTracks[rowIdx].arStatus = isCancelledErr ? "Cancelled" : "Read Error"
                        }
                    }
                }
            }
            if writeCueLog && okCount > 0 {
                try? cueLines.joined(separator: "\n").write(to: outDir.appendingPathComponent("Album.cue"), atomically: true, encoding: .utf8)
                try? logLines.joined(separator: "\n").write(to: outDir.appendingPathComponent("Extraction.log"), atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async {
                isRippingCD = false
                activeRippingTrackNum = nil
                ripProgressFraction = okCount > 0 ? 1.0 : 0.0
                if cancelCount > 0 && okCount == 0 {
                    copyStatusBanner = "Cancelled optical extraction (\(cancelCount) track(s) stopped)."
                } else if errCount == 0 && cancelCount == 0 {
                    copyStatusBanner = "Ripped \(okCount) Track(s) to \(outDir.path)"
                } else {
                    copyStatusBanner = "Ripped \(okCount)/\(selected.count) Track(s) (\(cancelCount) cancelled, \(errCount) errors)"
                }
                KroutonNotificationAndCompanionService.shared.dispatchEvent(
                    id: errCount == 0 ? "done" : "err",
                    title: errCount == 0 ? "Audio CD Extraction Complete" : "Audio CD Extraction Notice",
                    subtitle: copyStatusBanner,
                    progress: okCount > 0 ? 1.0 : 0.0,
                    driveName: primarySelectedDrive?.displayName ?? "Optical Drive",
                    speedLabel: chosenCodec,
                    store: store
                )
                if okCount > 0 {
                    KroutonOSDesktopBridge.playAcousticCue()
                    KroutonOSDesktopBridge.revealInFinder(url: outDir)
                }
            }
        }
    }
}
