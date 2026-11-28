import DriveKit
import Foundation
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings › Burners & Network

extension KroutonSettingsWindowView {
    /// The drives connected to this Mac (from `KroutonOpticalDriveBank`), paired Krouton
    /// Servers, and Auto-Load for burning several copies in a row.
    var burnersNetworkPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Burners Connected to This Mac") {
                HStack {
                    Text(driveManager.hardwareStatusLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    pillToggleButton(title: "Rescan", sfSymbol: "arrow.clockwise", isSelected: false) {
                        driveManager.refreshDrives()
                    }
                }
                Divider()

                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(KroutonL10n.tr("No optical drive found. Connect a burner, then click Rescan."))
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
                                    Text("Writes: \(drive.capabilitiesSummary)")
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
                                    pillToggleButton(title: "Quick Erase", sfSymbol: "eraser.fill", isSelected: false) {
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

            settingsCard(title: "Auto-Load") {
                Toggle(KroutonL10n.tr("Auto-Load the next disc: eject each finished disc and start the next burn when a blank goes in"), isOn: Bindable(store).autoLoadNextDiscBatchMode)
                    .fontWeight(.semibold)
                Text(KroutonL10n.tr("For several copies, or files spread over several discs: swap discs when asked, and Krouton carries on by itself."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Wait After a Blank Goes In"))
                        Text(KroutonL10n.tr("Gives the drive time to spin up and read the new blank before the burn starts"))
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
