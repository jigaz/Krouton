import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Window: Burners & Network Hardware Pane

extension KroutonSettingsWindowView {
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

                                if drive.isMediaErasable {
                                    pillToggleButton(title: "Quick Erase RW", sfSymbol: "eraser.fill", isSelected: false) {
                                        driveManager.eraseRewritableDisc(driveID: drive.id, fullErase: false) { _ in }
                                    }
                                }
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
                        }
                    }
                    pillToggleButton(title: "Calibrate Spool Cache", sfSymbol: "gauge.with.dots.needle.67percent", isSelected: false) {
                        Task {
                            await spoolClient.runSpoolCalibration()
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
                Toggle(KroutonL10n.tr("Share this Mac's connected optical drives on the local network"), isOn: Bindable(store).enableNetworkServerSharing)
                Toggle(KroutonL10n.tr("Pre-stage full compiled disc image to remote Spool Cache before igniting laser"), isOn: Bindable(store).preStageImageToServerSSD)
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
    var burnersNetworkBottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            settingsCard(title: "Optical Drive Hardware & MMC Bitsetting (Retro Console & Set-Top DVD Compatibility)") {
                Toggle(KroutonL10n.tr("Stamp Book Type as DVD-ROM (0x00) on DVD+R & DVD+R DL Media (Required by vintage DVD players, early PS2 & Xbox)"), isOn: Bindable(store).forceDVDROMBookType)
                    .fontWeight(.semibold)
                Text(KroutonL10n.tr("When enabled, Krouton sends the vendor MMC Mode Select / Set Compatibility bitsetting command before lead-in write so DVD+R and DVD+R DL discs identify as pressed factory DVD-ROMs."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text(KroutonL10n.tr("MMC Bitsetting Command Profile"))
                    Spacer()
                    Picker("", selection: Bindable(store).bitsetVendorProfile) {
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
                Toggle(KroutonL10n.tr("Disable BD-R Defect Management Spare Area on Video Blu-rays (Enables full rated write speed)"), isOn: Bindable(store).disableBDDefectManagementForVideo)
            }

            settingsCard(title: "Hands-Free Multi-Copy Duplication & Spanned Disc Auto-Loader") {
                Toggle(KroutonL10n.tr("Auto-Load Next Disc: Eject finished disc & automatically start next burn after fresh blank disc insertion"), isOn: Bindable(store).autoLoadNextDiscBatchMode)
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
                    Stepper("\(store.autoLoadCountdownSeconds) seconds after insert", value: Bindable(store).autoLoadCountdownSeconds, in: 3...15)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
            }
        }
    }
}
