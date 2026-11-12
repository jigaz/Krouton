import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalDough

struct KroutonBurnStationWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    let primarySelectedDrive: KroutonToasterInfo?
    let isCenterWorkspaceNarrow: Bool
    @Binding var enableCustomFinderLayoutTab: Bool
    @Binding var finderIconSize: Double
    @Binding var fitToDiscDVD9Shrink: Bool
    let preserveMenusAndExtras: Bool
    @Binding var cdTextAlbumTitle: String
    @Binding var cdTextAlbumPerformer: String
    @Binding var auditioningTrackID: UUID?
    @Binding var isDropTargeted: Bool
    let onPromptToAddFiles: () -> Void
    let onHandleFinderDrop: ([NSItemProvider]) -> Bool

    func addButtonTitle(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat {
            return "Add Audio Tracks (WAV / AIFF / FLAC / MP3)..."
        } else if spec.isCarSafeAudioFormat {
            return "Add Audio Files or Album Folders..."
        } else if spec.isVideoAuthoringFormat {
            return "Add Video Titles (MKV / MP4 / MOV / VIDEO_TS)..."
        } else if spec.isDiscImageBurnFormat {
            return "Select Disc Image (.ISO / .DMG / .BIN / .CUE / .CDR / .TOAST)..."
        } else if spec.id == "console-wii" {
            return "Select Wii Image (.RVZ / .WBFS / .ISO)..."
        } else if spec.id == "console-gc" {
            return "Select GameCube Image (.RVZ / .GCM / .ISO)..."
        } else if spec.id == "console-ps2" {
            return "Select PS2 Image (.ISO / .CHD / .BIN+.CUE)..."
        } else if spec.id == "console-ps1" {
            return "Select PS1 Image (.CUE+.BIN / .CHD / .CCD)..."
        } else if spec.id == "console-xbox" {
            return "Select Xbox Image (.ISO / .XISO / .DVD)..."
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "Select Console Image..."
        } else {
            return "Add Files or Folders..."
        }
    }

    func addButtonSymbol(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat || spec.isCarSafeAudioFormat {
            return "waveform.badge.plus"
        } else if spec.isVideoAuthoringFormat {
            return "film.stack.fill"
        } else if spec.isDiscImageBurnFormat {
            return "opticaldisc.fill"
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "gamecontroller.fill"
        } else {
            return "plus.rectangle.on.folder.fill"
        }
    }

    // ==========================================================================
    // 1. RED BOOK AUDIO CD (CD-DA) & CD-EXTRA WAVEBURNER MASTERING STUDIO
    // ==========================================================================


    // ==========================================================================
    // 2. CAR-SAFE MP3 / FLAC AUDIO CD WORKSPACE (Head-Unit Sorting & Sanitizer)
    // ==========================================================================


    // ==========================================================================
    // 3. VIDEO DISC AUTHORING STUDIO (DVD-Video, AVCHD, BD-R SL/DL, UHD-BD)
    // ==========================================================================


    // ==========================================================================
    // 4. RETRO CONSOLE ROM & SECTOR VERIFICATION WORKSPACE (PS1/PS2/GC/Wii/Xbox)
    // ==========================================================================


    // ==========================================================================
    // 5A. DEDICATED DISC IMAGE (.ISO / .BIN / .DMG / .CDR) FULL-WORKSPACE DECK
    //     (Single-Image Radial Platter, Live LBA Hex Scope & Actionable Pills)
    // ==========================================================================


    // ==========================================================================
    // 5B. NEW DATA & ARCHIVAL DISC AUTHORING WORKSPACE
    //     (Author File/Folder Trees with Universal Bridge & Per-File OS Visibility)
    // ==========================================================================


    // MARK: - Retro Console ROM Mastering Deck & Pre-Flight Sanity Engine


    func currentPreFlightSanityWarning(for spec: KroutonRecipeSpec) -> String? {
        if (spec.filterGroup == .console || spec.id.hasPrefix("console-")), let drive = primarySelectedDrive, drive.isMediaPresent && drive.isMediaErasable {
            return "Retro Console Pickup Warning: \(drive.displayName) has rewritable \(drive.mediaType) loaded (~20% reflectivity). Vintage PS1/PS2/GameCube/Dreamcast optical pickups require high-reflectivity write-once CD-R or DVD-R media at 4x–8x."
        }
        if spec.id == "console-ps1" && !store.stagedFiles.isEmpty {
            let hasBin = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".bin") }
            let hasCue = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".cue") || $0.name.lowercased().hasSuffix(".ccd") }
            if hasBin && !hasCue {
                return "Missing .CUE Descriptor: A raw .BIN track is staged without its companion .CUE sheet. Add the .CUE file to preserve Red Book audio tracks and 2-second pre-gap offsets."
            }
        }
        if let hugeFile = store.stagedFiles.first(where: { $0.exceedsISO9660FourGiBLimit }) {
            return "4 GiB File Limit Notice: '\(hugeFile.name)' exceeds the 4 GiB ISO9660 Level 2 ceiling. Krouton will bridge this file via UDF 2.60 + HFS+."
        }
        if let longFile = store.stagedFiles.first(where: { $0.exceedsJoliet64CharLimit }) {
            return "Joliet 64-Char Notice: '\(longFile.name)' is \(longFile.name.count) characters long. Full name is preserved on Mac (HFS+) and UDF, and safely truncated in legacy Windows Joliet tables."
        }
        return nil
    }


    var body: some View {
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID }) ?? store.discFormats[0]
        return VStack(alignment: .leading, spacing: 12) {
            // Format Header Bar with Context-Sensitive Add Action (Responsive & Zero Vertical Word-Towers)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        KroutonStyledIconBadge(
                            sfSymbol: activeSpec.sfSymbol,
                            tintColor: store.activeAccent,
                            style: store.iconWidgetStyle,
                            size: 28,
                            symbolSize: 15
                        )
                        let isCDDA = (activeSpec.id == "cd-da")
                        Text(isCDDA ? KroutonL10n.tr("Audio CD") : (isCenterWorkspaceNarrow ? activeSpec.exactShortDisplayName : activeSpec.technicalName))
                            .font(.title3.bold())
                            .lineLimit(1)
                        if !isCenterWorkspaceNarrow && !isCDDA {
                            Text(activeSpec.colloquialName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    if !isCenterWorkspaceNarrow {
                        Text("Spec: \(activeSpec.bookOrFileSystem) • Laser: \(activeSpec.laserType) • Source: \(activeSpec.sourceSupport)")
                            .font(.caption)
                            .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.82) : Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)

                if !store.stagedFiles.isEmpty {
                    Button {
                        auditioningTrackID = nil
                        store.clearStagedFiles()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            if !isCenterWorkspaceNarrow {
                                Text(KroutonL10n.tr("Clear All"))
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.kroutonControlSurface)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onPromptToAddFiles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addButtonSymbol(for: activeSpec))
                        Text(isCenterWorkspaceNarrow ? KroutonL10n.tr("Add Files...") : KroutonL10n.tr(addButtonTitle(for: activeSpec)))
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Pre-Flight Sanity Banner (Always active across all formats)
            if let sanityWarning = currentPreFlightSanityWarning(for: activeSpec) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    Text(sanityWarning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.orange.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            }

            // FORMAT-ADAPTIVE WORKSPACE ROUTER (Standalone Scoped View Structs)
            if activeSpec.isRedBookAudioFormat {
                KroutonRedBookAudioWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    cdTextAlbumTitle: $cdTextAlbumTitle,
                    cdTextAlbumPerformer: $cdTextAlbumPerformer,
                    auditioningTrackID: $auditioningTrackID,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isCarSafeAudioFormat {
                KroutonCarSafeAudioWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isVideoAuthoringFormat {
                KroutonVideoAuthoringWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                    preserveMenusAndExtras: preserveMenusAndExtras,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.isDiscImageBurnFormat {
                KroutonDiscImageInspectorWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isDropTargeted: $isDropTargeted,
                    onPromptToAddFiles: onPromptToAddFiles,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else if activeSpec.filterGroup == .console || activeSpec.id.hasPrefix("console-") {
                KroutonRetroConsoleWorkspaceView(
                    store: store,
                    spec: activeSpec,
                    isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            } else {
                KroutonDataAndArchivalWorkspaceView(
                    store: store,
                    activeSpec: activeSpec,
                    enableCustomFinderLayoutTab: $enableCustomFinderLayoutTab,
                    finderIconSize: $finderIconSize,
                    isDropTargeted: $isDropTargeted,
                    onHandleFinderDrop: onHandleFinderDrop
                )
            }
        }
    }

}
