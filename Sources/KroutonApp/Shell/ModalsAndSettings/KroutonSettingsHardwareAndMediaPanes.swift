import NetworkSpool
import DriveKit
import SwiftUI
import Foundation
import UniformTypeIdentifiers
import OpticalCore

// MARK: - Settings Window: Depot, Audio/Video, Ripping & Burners/Network Panes

extension KroutonSettingsWindowView {

    var discImageDepotPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Disc Image Depot — Subscribed Channels & Repositories") {
                ForEach(Array(store.depotChannels.enumerated()), id: \.element.id) { idx, channel in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: channel.sfSymbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(channel.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("• \(channel.itemCount) Images")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text(channel.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $store.depotChannels[idx].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        if idx < store.depotChannels.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Verification, Virtualization Test-Boot & Custom Feeds") {
                Toggle(KroutonL10n.tr("Automatically verify SHA-256 / PGP signatures on downloaded Depot images before burning"), isOn: $store.autoVerifyDepotSHA256)
                Divider()
                Toggle(KroutonL10n.tr("Enable Apple Virtualization.framework 'Test-Boot in VM' button for El Torito / UEFI images"), isOn: $store.enableVMTestBootInDepot)
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Custom Community Depot Manifest URL"))
                    Spacer()
                    TextField("https://...", text: $store.customDepotFeedURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                }
            }
        }
    }

    var audioVideoPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Red Book Audio CD & Crossfade Defaults") {
                Toggle(KroutonL10n.tr("Analyze BPM & Beat Grid automatically via Apple SoundAnalysis on import"), isOn: $store.autoBeatmatchSoundAnalysis)
                Divider()
                HStack {
                    Text(String(format: "Default Equal-Power Crossfade Overlap: %.1f seconds", store.defaultCrossfadeSec))
                    Spacer()
                    Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                        .frame(width: 220)
                }
                Divider()
                Toggle(KroutonL10n.tr("Car-Stereo Safe MP3 Mode (Enforce ID3v2.3 & strip hidden macOS ._* files)"), isOn: $store.carSafeMP3Mode)
            }

            settingsCard(title: "Video Authoring & Menu Defaults") {
                Toggle(KroutonL10n.tr("Single Video Track: Play immediately on disc insert (skip menu)"), isOn: $store.singleVideoFirstPlay)
                Divider()
                Toggle(KroutonL10n.tr("Use Apple Silicon VideoToolbox 2-Pass Hardware VBR for Blu-ray & DVD encoding"), isOn: $store.videoToolboxTwoPassVBR)
            }

            settingsCard(title: "Fit-to-Disc Compression Defaults (DVD-9 to 4.7 GB DVD-5 & BD-50 to BD-25)") {
                Toggle(KroutonL10n.tr("Always preserve interactive Menus, Chapter Tables & Bonus Featurettes when shrinking"), isOn: $store.fitToDiscPreserveMenus)
                Divider()
                Toggle(KroutonL10n.tr("Automatically strip foreign audio dubs (retain Original Language + English) to maximize video bitrate"), isOn: $store.fitToDiscStripForeignDubs)
            }

            settingsCard(title: "Universal Hardware & Software Decoder Matrix") {
                HStack {
                    Label(KroutonL10n.tr("Apple Silicon VideoToolbox ASIC + Accelerate vDSP + libavformat/libavcodec Active"), systemImage: "cpu.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(KroutonL10n.tr("Zero-Copy GPU & SIMD Pipeline"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider()
                ForEach(KroutonMediaPrepEngine.liveHardwareCodecMatrix) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: row.isHardwareAccelerated ? "bolt.shield.fill" : "cpu")
                                .foregroundStyle(row.isHardwareAccelerated ? .green : store.activeAccent)
                                .font(.system(size: 12))
                            Text(row.category)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(row.hardwareStatus)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.16))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        HStack {
                            Text("Formats: \(row.formatsAndExtensions)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Engine: \(row.primaryEngine)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(store.activeAccent)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
    }

    var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Optical Drive Read Offset & Error Recovery (CD / DVD / BD Ripping)") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(KroutonL10n.tr("Drive Sample Read Offset Correction"))
                        Text(KroutonL10n.tr("Compensates for physical laser lead-in/lead-out offset on Matshita/Pioneer/LG drives"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Offset", value: $store.driveReadOffsetSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(KroutonL10n.tr("samples"))
                        .font(.caption)
                }
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Paranoia Scratched Sector Re-Read Retries"))
                    Spacer()
                    Stepper("\(store.paranoiaErrorRetries) passes", value: $store.paranoiaErrorRetries, in: 1...64)
                }
                Divider()
                Toggle(KroutonL10n.tr("Verify ripped audio tracks against AccurateRip & MusicBrainz database"), isOn: $store.verifyAccurateRip)
                Divider()
                Toggle(KroutonL10n.tr("Generate archival .cue sheet and extraction .log alongside ALAC / FLAC rips"), isOn: $store.writeCueSheetLog)
            }

            settingsCard(title: "Video Disc Extraction & Hardware VideoToolbox") {
                Toggle(KroutonL10n.tr("Hardware Motion-Compensated Deinterlacing (480i / 1080i -> Progressive H.265)"), isOn: $store.hardwareDeinterlaceVideo)
                Divider()
                Toggle(KroutonL10n.tr("Passthrough lossless Dolby Atmos / TrueHD / DTS-HD Master Audio bitstreams"), isOn: $store.passthroughAtmosTrueHD)
            }

            settingsCard(title: "Smart File & Track Naming Pattern (Zero-Script Token Builder)") {
                Text(KroutonL10n.tr("Click tokens below to append to your active naming pattern, or click any active token pill to remove it:"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]", " - ", "/"], id: \.self) { token in
                        pillToggleButton(title: token, sfSymbol: "plus.circle", isSelected: false) {
                            store.namingTokens.append(token)
                        }
                    }
                    Spacer()
                    Button("Reset Default") {
                        store.namingTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                    }
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Active Pattern:"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(store.namingTokens.enumerated()), id: \.offset) { idx, tok in
                            Button {
                                store.namingTokens.remove(at: idx)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tok)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Live Output Preview: \(store.namingPreviewString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }

    // MARK: - 6. BURNERS & NETWORK PANE (Live Connected Hardware via KroutonOpticalDriveBank)
    var burnersNetworkPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Connected Optical Burners (Live IOKit / DiscRecording Bus)") {
                HStack {
                    Text(driveManager.hardwareStatusLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    pillToggleButton(title: "Rescan Bus", sfSymbol: "arrow.clockwise", isSelected: false) {
                        driveManager.refreshDrives()
                    }
                }
                Divider()

                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(KroutonL10n.tr("No physical optical drives detected. Plug in your USB burner and click Rescan Bus."))
                            .font(.caption)
                    }
                } else {
                    ForEach(Array(driveManager.availableDrives.enumerated()), id: \.element.id) { idx, drive in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: drive.isNetworkNode ? "server.rack" : "opticaldiscdrive.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(store.activeAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text(drive.displayName)
                                            .font(.system(size: 13, weight: .bold))
                                        Text("FW \(drive.firmware) • \(drive.interconnect)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Write Capabilities: \(drive.capabilitiesSummary)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(drive.isMediaPresent ? Color.green : Color.secondary)
                                        .frame(width: 7, height: 7)
                                    Text(drive.statusBadgeText)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(drive.isMediaPresent ? .green : .secondary)
                                }
                                .padding(.trailing, 6)

                                pillToggleButton(title: "Eject", sfSymbol: "eject.fill", isSelected: false) {
                                    driveManager.ejectDrive(id: drive.id)
                                }
                            }
                            if idx < driveManager.availableDrives.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }

            settingsCard(title: "Headless LAN Optical Spool Daemon (_krouton-spool._tcp.local. • Port 7420)") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spoolClient.statusBannerText)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text("Spool-and-Burn Architecture: Pre-stages disc image & metadata to remote Spool Cache (>= 1 GB free) before DAO/SAO laser ignition.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    pillToggleButton(title: "Scan mDNS (7420)", sfSymbol: "antenna.radiowaves.left.and.right", isSelected: false) {
                        spoolClient.startZeroConfDiscovery()
                        Task {
                            await spoolClient.refreshRemoteDrives()
                            store.objectWillChange.send()
                        }
                    }
                    pillToggleButton(title: "Calibrate Spool Cache", sfSymbol: "gauge.with.dots.needle.67percent", isSelected: false) {
                        Task {
                            await spoolClient.runSpoolCalibration()
                            store.objectWillChange.send()
                        }
                    }
                }
                Divider()

                ForEach(spoolClient.remoteDrives) { remoteDrive in
                    HStack(spacing: 10) {
                        Image(systemName: remoteDrive.isSimulatedDrive ? "sparkles.tv.fill" : "externaldrive.connected.to.line.below.fill")
                            .foregroundStyle(store.activeAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(remoteDrive.name)
                                .font(.system(size: 12, weight: .bold))
                            Text("DriveID: \(remoteDrive.id) • Rack: \(remoteDrive.rackState.rawValue) • SliceMedia: \(remoteDrive.sliceMedia.rawValue)")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        pillToggleButton(
                            title: remoteDrive.rackState == .open ? "Close Rack" : "Wink / Open Rack",
                            sfSymbol: "eject.fill",
                            isSelected: remoteDrive.rackState == .open
                        ) {
                            Task {
                                await spoolClient.toggleDriveTray(driveID: remoteDrive.id)
                                store.objectWillChange.send()
                            }
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Text("Diagnostic Bundle Retention Policy:")
                        .fontWeight(.medium)
                    Picker("", selection: Binding(
                        get: { spoolClient.retentionPolicy },
                        set: { newPol in
                            spoolClient.retentionPolicy = newPol
                            store.objectWillChange.send()
                        }
                    )) {
                        ForEach(SpoolArtifactRetentionPolicy.allCases) { pol in
                            Text(pol.rawValue).tag(pol)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)

                    Spacer()

                    pillToggleButton(title: "Export Telemetry (.log + .toc)", sfSymbol: "waveform.path.ecg", isSelected: false) {
                        Task {
                            let artifact = await spoolClient.preparePhaseScopeTelemetryArtifact()
                            spoolExportDocument = SpoolPlainTextFileDocument(text: artifact.contentText)
                            spoolExportDefaultFilename = artifact.defaultFilename
                            isShowingSpoolFileExporter = true
                        }
                    }
                    pillToggleButton(title: "Download Diagnostic Bundle", sfSymbol: "takeoutbag.and.cup.and.straw.fill", isSelected: false) {
                        Task {
                            let artifact = await spoolClient.prepareDiagnosticBundleArtifact()
                            spoolExportDocument = SpoolPlainTextFileDocument(text: artifact.contentText)
                            spoolExportDefaultFilename = artifact.defaultFilename
                            isShowingSpoolFileExporter = true
                        }
                    }
                }

                Divider()
                Toggle(KroutonL10n.tr("Share this Mac's connected optical drives on the local network"), isOn: $store.enableNetworkServerSharing)
                Toggle(KroutonL10n.tr("Pre-stage full compiled disc image to remote Spool Cache before igniting laser"), isOn: $store.preStageImageToServerSSD)
            }
            .fileExporter(
                isPresented: $isShowingSpoolFileExporter,
                document: spoolExportDocument,
                contentType: .plainText,
                defaultFilename: spoolExportDefaultFilename
            ) { result in
                if case .success(let savedURL) = result {
                    spoolClient.appendEventLog("Saved \(savedURL.lastPathComponent) via SwiftUI FileExporter")
                }
            }
                burnersNetworkBottomSection
        }
    }

    @ViewBuilder
    private var burnersNetworkBottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            settingsCard(title: "Optical Drive Hardware & MMC Bitsetting (Retro Console & Set-Top DVD Compatibility)") {
                Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (0x00) on DVD+R & DVD+R DL Media (Required by vintage DVD players, early PS2 & Xbox)"), isOn: $store.forceDVDROMBookType)
                    .fontWeight(.semibold)
                Text(KroutonL10n.tr("When enabled, Krouton sends the vendor MMC Mode Select / Set Compatibility bitsetting command before lead-in write so DVD+R and DVD+R DL discs identify as pressed factory DVD-ROMs."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text(KroutonL10n.tr("MMC Bitsetting Command Profile"))
                    Spacer()
                    Picker("", selection: $store.bitsetVendorProfile) {
                        Text(KroutonL10n.tr("Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)")).tag("Auto-Detect (MMC 0xFA / Pioneer / Lite-On / LG)")
                        Text(KroutonL10n.tr("Pioneer DVR / BDR Extended (0x3B Mode Select)")).tag("Pioneer DVR / BDR Extended (0x3B Mode Select)")
                        Text(KroutonL10n.tr("Lite-On / MediaTek SmartBurn (0xF9 / 0xFF)")).tag("Lite-On / MediaTek SmartBurn (0xF9 / 0xFF)")
                        Text(KroutonL10n.tr("LG / HL-DT-ST / Renesas Super-Multi (0xFA)")).tag("LG / HL-DT-ST / Renesas Super-Multi (0xFA)")
                        Text(KroutonL10n.tr("NEC / Optiarc / Sony (0xFF BookType)")).tag("NEC / Optiarc / Sony (0xFF BookType)")
                    }
                    .labelsHidden()
                    .frame(width: 340)
                }
                if !driveManager.availableDrives.isEmpty {
                    Divider()
                    ForEach(driveManager.availableDrives) { drive in
                        HStack {
                            Image(systemName: "opticaldisc.fill")
                                .foregroundStyle(store.activeAccent)
                            Text(drive.displayName)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(driveManager.bookTypeStatus(for: drive, forceDVDROM: store.forceDVDROMBookType))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(store.forceDVDROMBookType ? .green : .secondary)
                            pillToggleButton(title: "Stamp DVD-ROM Now", sfSymbol: "seal.fill", isSelected: false) {
                                driveManager.stampDVDROMBookType(for: drive.id, vendorProfile: store.bitsetVendorProfile)
                            }
                        }
                    }
                }
                Divider()
                Toggle(KroutonL10n.tr("Disable BD-R Defect Management Spare Area on Video Blu-rays (Enables full rated write speed)"), isOn: $store.disableBDDefectManagementForVideo)
            }

            settingsCard(title: "Hands-Free Multi-Copy Duplication & Spanned Disc Auto-Loader") {
                Toggle(KroutonL10n.tr("Auto-Load Next Disc: Eject finished disc & automatically start next burn after fresh blank disc insertion"), isOn: $store.autoLoadNextDiscBatchMode)
                    .fontWeight(.semibold)
                Text(KroutonL10n.tr("Turns your Mac into a hands-free duplication station when burning multiple copies or multi-disc spanned archives."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Post-Insertion Spin-Up & Auto-Fire Delay"))
                        Text(KroutonL10n.tr("Waits for macOS DiskArbitration and optical spindle lock before firing the laser"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper("\(store.autoLoadCountdownSeconds) seconds after insert", value: $store.autoLoadCountdownSeconds, in: 3...15)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
        }
    }
}
