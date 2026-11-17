import VideoKit
import LabelKit
import RescueKit
import AudioKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore

extension KroutonCopyAndRipWorkspaceView {
    var cdInfoEditorPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(KroutonL10n.tr("CD Info & Metadata Tags")).font(.headline)
                    Text(mountedCDSnapshot?.musicBrainzDiscID ?? "No Disc Mounted")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(KroutonL10n.tr("Get Track Names")) {
                    if let snap = mountedCDSnapshot {
                        lookupMusicBrainzMetadata(for: snap)
                    }
                }.buttonStyle(.borderedProminent).tint(store.uiSecondaryAccent).controlSize(.small)
            }
            Divider()
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Artist:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Artist", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Album:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Album", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Composer:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Composer", text: $cdInfoComposer).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Genre:").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Genre", text: $cdInfoGenre).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Year:").font(.caption.bold()).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("YYYY", text: $cdInfoYear).textFieldStyle(.roundedBorder).frame(width: 70)
                        Text("Disc:").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("1", text: $cdInfoDiscNumber).textFieldStyle(.roundedBorder).frame(width: 36)
                        Text("of").font(.caption).foregroundStyle(.secondary)
                        TextField("1", text: $cdInfoDiscTotal).textFieldStyle(.roundedBorder).frame(width: 36)
                    }
                }
            }
            Toggle(KroutonL10n.tr("Album is a compilation of songs by various artists"), isOn: $cdInfoIsCompilation)
                .toggleStyle(.checkbox).font(.caption)
            Toggle(KroutonL10n.tr("Use error correction when reading Audio CDs"), isOn: $audioRipErrorCorrection)
                .toggleStyle(.checkbox).font(.caption)
            HStack {
                Spacer()
                Button(KroutonL10n.tr("OK")) { showCDInfoPopover = false }
                    .buttonStyle(.borderedProminent).tint(store.activeAccent)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    var audioCDRipWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 195), alignment: .leading)], spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Album:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            TextField("Album Title", text: $cdTextAlbumTitle).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Artist:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            TextField("Artist", text: $cdTextAlbumPerformer).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 6) {
                            Text("Codec:").font(.caption.bold()).frame(width: 44, alignment: .leading)
                            Picker("", selection: $audioRipCodec) {
                                Text("FLAC (Lossless)").tag("FLAC (Lossless)")
                                Text("Apple Lossless (ALAC)").tag("Apple Lossless (ALAC)")
                                Text("WAV (Uncompressed PCM)").tag("WAV (Uncompressed PCM)")
                                Text("AIFF (1:1 Red Book PCM)").tag("AIFF (1:1 Red Book PCM)")
                            }.labelsHidden().font(.caption)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Button(audioRipSelectedTracks.count == audioRipTracks.count ? "Deselect All" : "Select All (\(audioRipTracks.count))") {
                                if audioRipSelectedTracks.count == audioRipTracks.count {
                                    audioRipSelectedTracks.removeAll()
                                } else {
                                    audioRipSelectedTracks = Set(audioRipTracks.map(\.num))
                                }
                            }.buttonStyle(.bordered).controlSize(.mini).fixedSize()
                            Button {
                                if let snap = mountedCDSnapshot { lookupMusicBrainzMetadata(for: snap) }
                                else { rescanOpticalDiscForCopyTask(isAudioRipTask: true, isShrinkTask: false, fetchMetadata: true) }
                            } label: {
                                Label(KroutonL10n.tr("Get Track Names"), systemImage: "sparkles.tv")
                            }.buttonStyle(.bordered).controlSize(.mini).fixedSize()
                            Spacer(minLength: 4)
                            Text("Out: \(copyOutputFolderPath)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        HStack(spacing: 12) {
                            Toggle(KroutonL10n.tr("Error Correction"), isOn: $audioRipErrorCorrection).toggleStyle(.checkbox).font(.caption.bold()).fixedSize()
                            Toggle(KroutonL10n.tr("AccurateRip + CRC32"), isOn: $audioRipAccurateRip).toggleStyle(.checkbox).font(.caption).fixedSize()
                            Toggle(KroutonL10n.tr("Write .CUE + .LOG"), isOn: $audioRipGenerateCueLog).toggleStyle(.checkbox).font(.caption).fixedSize()
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($audioRipTracks) { $trk in
                        audioTrackRowView(trk: $trk)
                        Divider()
                    }
                }
            }.background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func audioTrackRowView(trk: Binding<KroutonRipTrackItem>) -> some View {
        let item = trk.wrappedValue
        let isActiveTrack = (activeRippingTrackNum == item.num && isRippingCD)
        let frac = perTrackProgress[item.num] ?? 0.0
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { audioRipSelectedTracks.contains(item.num) },
                set: { if $0 { audioRipSelectedTracks.insert(item.num) } else { audioRipSelectedTracks.remove(item.num) } }
            )).labelsHidden().toggleStyle(.checkbox)

            Text(String(format: "%02d", item.num))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(store.activeAccent).frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                TextField("Track Title", text: trk.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                if isActiveTrack {
                    HStack(spacing: 8) {
                        ProgressView(value: frac)
                            .frame(maxWidth: 220)
                        Text(String(format: "Converting (%.0f %%)...", frac * 100.0))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    }
                } else {
                    Text("\(cdTextAlbumPerformer.isEmpty ? "Audio CD" : cdTextAlbumPerformer) • \(item.performer)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)

            if audioRipAccurateRip {
                let badgeColor: Color = item.arStatus.contains("Cancelled") || item.arStatus.contains("Error")
                    ? .red
                    : (item.arStatus.contains("CRC") ? .cyan : .green)
                Text(item.arStatus)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(badgeColor)
                    .lineLimit(1).fixedSize()
            }

            Text(item.duration)
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).fixedSize()

            if isActiveTrack {
                Button {
                    ripCancelToken.cancelledTracks.insert(item.num)
                } label: {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop converting this track")
            } else {
                Button {
                    startHardwareAudioCDExtraction(onlyTrackNumber: item.num)
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isRippingCD)
                .help("Rip / Retry this track")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isActiveTrack ? store.activeAccent.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(String(format: "%02d", item.num)), \(item.title)")
        .accessibilityValue("\(audioRipSelectedTracks.contains(item.num) ? "Selected" : "Unchecked"), \(item.duration), \(item.arStatus)")
        .contextMenu {
            Button("Start / Convert Track \(String(format: "%02d", item.num))") {
                startHardwareAudioCDExtraction(onlyTrackNumber: item.num)
            }.keyboardShortcut("r", modifiers: [.command, .shift])
            Button(KroutonL10n.tr("Play Track in Default Player")) {
                if let src = mountedCDSnapshot?.tracks.first(where: { $0.trackNumber == item.num })?.sourceAIFFURL {
                    KroutonOSDesktopBridge.revealInFinder(url: src)
                }
            }
            Divider()
            Button(KroutonL10n.tr("Get Info (CD Info...)")) {
                showCDInfoPopover = true
            }.keyboardShortcut("i", modifiers: .command)
            Button(KroutonL10n.tr("Locate Source File in Finder")) {
                if let src = mountedCDSnapshot?.tracks.first(where: { $0.trackNumber == item.num })?.sourceAIFFURL {
                    KroutonOSDesktopBridge.revealInFinder(url: src)
                }
            }.keyboardShortcut("f", modifiers: [.command, .shift])
            Divider()
            Button(audioRipSelectedTracks.contains(item.num) ? "Uncheck Selection" : "Check Selection") {
                if audioRipSelectedTracks.contains(item.num) { audioRipSelectedTracks.remove(item.num) }
                else { audioRipSelectedTracks.insert(item.num) }
            }
        }
    }

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
