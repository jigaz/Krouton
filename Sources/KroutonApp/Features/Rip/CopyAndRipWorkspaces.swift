import AudioKit
import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import VideoKit
import os

// MARK: - CopyAndRipWorkspaces

final class KroutonRipCancelToken: Sendable {
    private struct State: Sendable {
        var isCancelled: Bool = false
        var cancelledTracks: Set<Int> = []
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    var isCancelled: Bool {
        get { state.withLock { $0.isCancelled } }
        set { state.withLock { $0.isCancelled = newValue } }
    }

    var cancelledTracks: Set<Int> {
        get { state.withLock { $0.cancelledTracks } }
        set { state.withLock { $0.cancelledTracks = newValue } }
    }

    init() {}
}

struct KroutonCopyAndRipWorkspaceView: View {
    var store: KroutonStateStore
    let primarySelectedDrive: KroutonOpticalDriveInfo?
    let isCenterWorkspaceNarrow: Bool

    @State var audioRipCodec: KroutonRipCodec = .flac
    @State var audioRipGenerateCueLog: Bool = true
    // No error-correction switch: rips read the AIFF files macOS mounts for an audio CD, and
    // the drive's own error correction is all there is on that path.
    @State var audioRipSelectedTracks: Set<Int> = Set(1...99)
    @State var videoExtractMode: String = "Lossless MKV Remux"
    @State var videoExtractMinSeconds: Int = 120
    @State var videoExtractSelectedTitles: Set<String> = ["TITLE_01", "TITLE_02"]
    @State var copySourceOverrideLabel: String = ""
    @State var copyOutputFolderPath: String = "~/Music/Krouton Rips"
    @State var copyStatusBanner: String = ""
    @State var audioRipTracks: [KroutonRipTrackItem] = []
    @State var mountedCDSnapshot: KroutonMountedAudioCDSnapshot? = nil
    @State var scannedVideoDisc: ScannedOpticalVideoDisc? = nil
    @State var isRippingCD: Bool = false
    @State var isScanningTOC: Bool = false
    @State var ripProgressFraction: Double = 0.0
    @State var activeRippingTrackNum: Int? = nil
    @State var perTrackProgress: [Int: Double] = [:]
    @State var ripCancelToken = KroutonRipCancelToken()
    @State var showCDInfoPopover: Bool = false
    // These album fields, with the album title and artist and each track's name, are written
    // into every ripped file after it is saved (`KroutonAudioTagWriter`: Vorbis comments in FLAC,
    // iTunes metadata in M4A, LIST/INFO in WAV, NAME/AUTH/ANNO in AIFF).
    @State var cdInfoComposer: String = ""
    @State var cdInfoGenre: String = ""
    @State var cdInfoYear: String = ""
    @State var cdInfoDiscNumber: String = "1"
    @State var cdInfoDiscTotal: String = "1"
    @State var cdInfoIsCompilation: Bool = false
    @State var videoExtractTitles: [KroutonVideoExtractTitleItem] = []

    var body: some View {
        let isShrinkTask = (store.selectedCopyTaskID == .duplicateDisc)
        let isAudioRipTask = (store.selectedCopyTaskID == .ripAudioCD)
        let isRescueTask = (store.selectedCopyTaskID == .rescueDisc)
        let sourceDescription = mountedCDSnapshot != nil
            ? "Mounted CD: \(mountedCDSnapshot!.mountPath) • \(mountedCDSnapshot!.tracks.count) Audio Tracks (\(ByteCountFormatter.string(fromByteCount: mountedCDSnapshot!.totalPCMBytes, countStyle: .file))) • DiscID: \(mountedCDSnapshot!.musicBrainzDiscID)"
            : "Source Drive: \(primarySelectedDrive?.displayName ?? "Optical Drive") — Status: \(primarySelectedDrive?.statusBadgeText ?? "Ready")"

        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    headerTitleBlock(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask, subtitle: sourceDescription)
                    Spacer(minLength: 8)
                    headerActionButtons(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask, compact: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    headerTitleBlock(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask, subtitle: sourceDescription)
                    headerActionButtons(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask, compact: true)
                }
            }

            if !copyStatusBanner.isEmpty {
                HStack(spacing: 10) {
                    if isScanningTOC {
                        ProgressView().controlSize(.small)
                    }
                    // A sector copy reports through the rescue engine that does it.
                    Text(isShrinkTask && store.rescue.isRunning ? store.rescue.status : copyStatusBanner)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(store.activeAccent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if isRippingCD {
                        ProgressView(value: ripProgressFraction)
                            .frame(width: 120)
                        Text("\(Int(ripProgressFraction * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                        Button {
                            ripCancelToken.isCancelled = true
                            copyStatusBanner = "Stopping optical extraction..."
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(store.activeAccent.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if isRescueTask {
                rescueWorkspaceDeck
            } else {
                unifiedOpticalRescueMapCard(showVideoHandoff: !isAudioRipTask)
            }
            if isRescueTask {
                EmptyView()
            } else if isAudioRipTask {
                audioCDRipWorkspaceDeck
            } else if isShrinkTask {
                shrinkDVDVideoWorkspaceDeck
            } else {
                videoDiscExtractWorkspaceDeck
            }
        }
        .onAppear {
            if isAudioRipTask && audioRipTracks.isEmpty {
                rescanOpticalDiscForCopyTask(isAudioRipTask: true, isShrinkTask: false, fetchMetadata: false)
            } else if !isAudioRipTask && !isRescueTask && scannedVideoDisc == nil {
                rescanOpticalDiscForCopyTask(isAudioRipTask: false, isShrinkTask: isShrinkTask, fetchMetadata: false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuScanTOC)) { _ in
            rescanOpticalDiscForCopyTask(isAudioRipTask: true, isShrinkTask: false, fetchMetadata: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuRipSelected)) { _ in
            startHardwareAudioCDExtraction(onlyTrackNumber: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuShowCDInfo)) { _ in
            showCDInfoPopover = true
        }
    }

    @ViewBuilder
    func headerTitleBlock(isAudioRipTask: Bool, isShrinkTask: Bool, subtitle: String) -> some View {
        let isRescueTask = store.selectedCopyTaskID == .rescueDisc
        HStack(spacing: 8) {
            KroutonStyledIconBadge(
                sfSymbol: isRescueTask ? "lifepreserver.fill" : (isAudioRipTask ? "waveform.circle.fill" : (isShrinkTask ? "doc.on.doc.fill" : "film.stack.fill")),
                tintColor: store.activeAccent, style: store.iconWidgetStyle, size: 28, symbolSize: 14
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(KroutonL10n.tr(isRescueTask ? "Rescue a Damaged Disc" : (isAudioRipTask ? "Audio CD Ripper & AccurateRip Archiver" : (isShrinkTask ? "Duplicate Disc & Fit-to-Disc Requantizer" : "Video Disc Extractor (MKV Remux)"))))
                    .font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.8)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    func headerActionButtons(isAudioRipTask: Bool, isShrinkTask: Bool, compact: Bool) -> some View {
        HStack(spacing: 6) {
            Button {
                rescanOpticalDiscForCopyTask(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask, fetchMetadata: true)
            } label: {
                Label(isScanningTOC ? "Scanning..." : (compact ? "Scan TOC" : (isAudioRipTask ? "Scan TOC" : "Scan Disc")), systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(store.uiSecondaryAccent.opacity(0.18)).foregroundStyle(store.uiSecondaryAccent).clipShape(Capsule())
            }.buttonStyle(.plain).fixedSize()

            if isAudioRipTask {
                Button {
                    showCDInfoPopover.toggle()
                } label: {
                    Label(KroutonL10n.tr("CD Info"), systemImage: "info.circle.fill")
                        .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.10)).clipShape(Capsule())
                }
                .buttonStyle(.plain).fixedSize()
                .popover(isPresented: $showCDInfoPopover) {
                    cdInfoEditorPopoverView
                }

                if isRippingCD {
                    Button {
                        ripCancelToken.isCancelled = true
                        copyStatusBanner = "Stopping optical extraction..."
                    } label: {
                        Label(KroutonL10n.tr("Stop Ripping"), systemImage: "xmark.octagon.fill")
                            .font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.red).foregroundStyle(.white).clipShape(Capsule())
                    }.buttonStyle(.plain).fixedSize()
                } else {
                    Button {
                        startHardwareAudioCDExtraction(onlyTrackNumber: nil)
                    } label: {
                        Label(KroutonL10n.tr(compact ? "Import CD" : "Rip Selected"), systemImage: "waveform.badge.plus")
                            .font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                            .background(store.activeAccent).foregroundStyle(store.activeOnAccentText).clipShape(Capsule())
                    }.buttonStyle(.plain).fixedSize()
                }
            } else {
                Button {
                    startVideoOrDiscExtraction(isShrinkTask: isShrinkTask)
                } label: {
                    Label(isShrinkTask ? (compact ? "Build .ISO" : "Duplicate to .ISO") : (compact ? "Extract" : "Extract Selected"), systemImage: isShrinkTask ? "opticaldisc.fill" : "film.stack.fill")
                        .font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(store.activeAccent).foregroundStyle(store.activeOnAccentText).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(isRippingCD)
            }

            Button {
                promptForCopySourceOrFolder(isAudioRipTask: isAudioRipTask, isShrinkTask: isShrinkTask)
            } label: {
                Label(KroutonL10n.tr("Folder..."), systemImage: "folder.fill.badge.gearshape")
                    .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.10)).clipShape(Capsule())
            }.buttonStyle(.plain).fixedSize()

            Button {
                store.ejectActiveOpticalDisc()
                copyStatusBanner = "Sent optical tray eject command to \(primarySelectedDrive?.displayName ?? "drive")."
            } label: {
                Image(systemName: "eject.fill")
                    .font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.10)).clipShape(Capsule())
            }.buttonStyle(.plain).help(KroutonL10n.tr("Eject Optical Disc")).accessibilityLabel(KroutonL10n.tr("Eject Optical Disc"))
        }
    }

    var videoDiscExtractWorkspaceDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                HStack(spacing: 14) {
                    Picker(KroutonL10n.tr("Mode:"), selection: $videoExtractMode) {
                        Text("MKV, all audio and subtitles (needs ffmpeg)").tag("Lossless MKV Remux")
                        Text("MPEG file, copied as it is").tag("MPEG Program Stream")
                    }.font(.caption.bold())
                    Text(KroutonL10n.tr("Unprotected discs only: Krouton doesn't remove copy protection."))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(videoExtractTitles.filter { $0.seconds >= videoExtractMinSeconds }) { (item: KroutonVideoExtractTitleItem) in
                        HStack(spacing: 10) {
                            Toggle("", isOn: Binding(
                                get: { videoExtractSelectedTitles.contains(item.id) },
                                set: { if $0 { videoExtractSelectedTitles.insert(item.id) } else { videoExtractSelectedTitles.remove(item.id) } }
                            )).labelsHidden().toggleStyle(.checkbox)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.system(size: 12, weight: .semibold))
                                Text("\(item.streamInfo) • \(item.sizeLabel)").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.duration).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(store.activeAccent)
                            Text("\(item.seconds / 60) min").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }.padding(.horizontal, 12).padding(.vertical, 8)
                        Divider()
                    }
                }
            }.background(Color.kroutonControlSurface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    var shrinkDVDVideoWorkspaceDeck: some View {
        let sourceBytes = max(store.totalStagedBytes, scannedVideoDisc?.totalBytes ?? 0)
        let plan = KroutonVideoAuthoringEngine.planDVD9ToDVD5Shrink(mainFeatureBytes: sourceBytes, menusAndExtrasBytes: 0, preserveMenusAndExtras: store.preserveMenusAndExtras)
        return VStack(alignment: .leading, spacing: 10) {
            KroutonMasteringDeckCard(store: store) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Toggle(KroutonL10n.tr("Fit Dual-Layer DVD-9 (8.5 GB) onto Single-Layer DVD-5 (4.7 GB)"), isOn: Bindable(store).fitToDiscDVD9Shrink).toggleStyle(.checkbox).font(.caption.bold())
                        Toggle(KroutonL10n.tr("Preserve Interactive Menus & Subpictures"), isOn: Bindable(store).preserveMenusAndExtras).toggleStyle(.checkbox).font(.caption)
                        Spacer()
                    }
                    Text(String(format: "VideoKit Requantizer Ratio: %.1f%% • Output: %.2f GB • Requantize: %@", plan.requantizationRatio * 100.0, Double(plan.estimatedOutputBytes) / 1_000_000_000.0, plan.requiresRequantization ? "ACTIVE" : "PASSTHROUGH"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(store.activeAccent)
                }
            }
        }
    }

    /// What actually happened to each track in the last rip. Audio rips read through the mounted
    /// volume; sector-level rescue of data discs is its own task (CopyAndRipWorkspaces+RescueUX).
    @ViewBuilder
    func unifiedOpticalRescueMapCard(showVideoHandoff: Bool) -> some View {
        let outcomes = audioRipTracks.map { KroutonRipTrackOutcome(status: $0.arStatus) }
        let ripped = outcomes.filter { $0 == .ripped }.count
        let failed = outcomes.filter { $0 == .readError }.count
        let cancelled = outcomes.filter { $0 == .cancelled }.count
        let waiting = outcomes.filter { $0 == .notRipped }.count
        KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "lifepreserver.fill").foregroundStyle(store.activeAccent)
                    Text("TRACK RIP RESULTS")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 4)
                    Button(KroutonL10n.tr("Copy Results")) {
                        let lines = audioRipTracks.map { String(format: "Track %02d: %@", $0.num, $0.arStatus) }
                        KroutonOSDesktopBridge.copyTextToClipboard(lines.joined(separator: "\n"))
                        copyStatusBanner = "Copied Track Rip Results to Clipboard"
                    }.buttonStyle(.bordered).controlSize(.mini).fixedSize().disabled(audioRipTracks.isEmpty)
                    if showVideoHandoff {
                        Button(KroutonL10n.tr("Send to Video Author ->")) {
                            store.selectedTaskID = KroutonFormatID.dvdVideo.rawValue
                            copyStatusBanner = "Routed Extracted Stream to DVD/BDMV Authoring Deck"
                        }.buttonStyle(.borderedProminent).tint(store.uiSecondaryAccent).controlSize(.mini).fixedSize()
                    }
                }
                if outcomes.isEmpty {
                    Text("Per-track results appear here after an Audio CD rip. A track with a read error is reported as failed; for a damaged data disc, use Rescue a Damaged Disc.")
                        .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 2) {
                        ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                            RoundedRectangle(cornerRadius: 1.5).fill(outcome.color.opacity(0.85)).frame(height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Track rip results")
                    .accessibilityValue("\(ripped) ripped, \(failed) read errors, \(cancelled) cancelled, \(waiting) not ripped")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], spacing: 4) {
                        Label("Ripped: \(ripped)/\(outcomes.count)", systemImage: "checkmark.circle.fill").foregroundStyle(.green).lineLimit(1)
                        Label("Read Errors: \(failed)", systemImage: "exclamationmark.octagon.fill").foregroundStyle(.red).lineLimit(1)
                        Label("Cancelled: \(cancelled)", systemImage: "xmark.circle").foregroundStyle(.orange).lineLimit(1)
                        Label("Not Ripped: \(waiting)", systemImage: "circle").foregroundStyle(.secondary).lineLimit(1)
                    }.font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                }
            }
        }
    }
}

/// A track's rip outcome, read from the status text the ripper writes for it.
enum KroutonRipTrackOutcome: Equatable {
    case ripped
    case readError
    case cancelled
    case notRipped

    init(status: String) {
        if status.contains("Read Error") {
            self = .readError
        } else if status.contains("Cancelled") {
            self = .cancelled
        } else if status.hasPrefix("CRC ") {
            self = .ripped
        } else {
            self = .notRipped
        }
    }

    var color: Color {
        switch self {
        case .ripped: return .green
        case .readError: return .red
        case .cancelled: return .orange
        case .notRipped: return .gray
        }
    }
}
