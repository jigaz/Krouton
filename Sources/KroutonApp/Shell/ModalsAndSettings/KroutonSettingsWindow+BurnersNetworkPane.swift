import DriveKit
import Foundation
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

            burnServersCard
            burnersNetworkBottomSection
        }
    }

    @ViewBuilder
    var burnersNetworkBottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {

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
