import SwiftUI
import Foundation
import OpticalCore

extension KroutonDestinationCardView {
    @ViewBuilder
    var destinationCardTopHeaderBar: some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive strictly from unclaimed drives (never steal a drive in otherUsedDriveIDs!)
        let hasUnclaimedPhysicalBurner = driveManager.availableDrives.contains(where: { !otherUsedDriveIDs.contains($0.id) })
        let cardDrive: KroutonOpticalDriveInfo? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID && !otherUsedDriveIDs.contains($0.id) }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) })
        }()

        let activeCardDriveID = (item.kind == .networkBurner) ? "network-spool-drive" : (cardDrive?.id ?? "")

        let scopeTel = driveManager.telemetryForDrive(activeCardDriveID)
        let isFloatingOpen = scopeTel?.isFloatingWindowOpen ?? false
        let isInlineVisible = ((scopeTel?.isActive ?? false) || (scopeTel?.isManuallyPinnedInline ?? false)) && !isFloatingOpen

        let isDriveBusy = driveManager.isExecutingQueue || (scopeTel?.isActive == true)
        let canEject = (cardDrive?.isMediaPresent == true) && !isDriveBusy
        HStack(spacing: 5) {
                Menu {
                    ForEach(store.allowedDestinationsForCurrentCategory) { kind in
                        let isUSBAlreadyExhausted = (kind == .physicalBurner && item.kind != .physicalBurner && !hasUnclaimedPhysicalBurner)
                        Button {
                            guard !isUSBAlreadyExhausted else { return }
                            store.updateQueueItem(cardID) { qItem in
                                qItem.kind = kind
                                switch kind {
                                case .physicalBurner:
                                    if let freeDrive = driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) }) {
                                        qItem.targetDriveID = freeDrive.id
                                        qItem.hardwareOrPath = freeDrive.displayName
                                    }
                                case .networkBurner:
                                    qItem.targetDriveID = ""
                                    if !spoolClient.discoveredNodes.map(\.hostPort).contains(qItem.hardwareOrPath) {
                                        qItem.hardwareOrPath = spoolClient.discoveredNodes.first?.hostPort ?? "localhost:7420"
                                    }
                                case .discImage:
                                    let imgTarget = store.defaultDiscImageTarget
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = imgTarget.path
                                    qItem.speedOrCodec = imgTarget.description
                                case .audioRip:
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = "~/Music/Krouton Rips/Apple Lossless"
                                case .videoExtract:
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = "~/Movies/Krouton Extracts"
                                case .discPrinter:
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = "Epson EcoTank Photo ET-8550 (CD/DVD Tray)"
                                case .pdfVector:
                                    qItem.targetDriveID = ""
                                    qItem.hardwareOrPath = "~/Desktop/\(store.discVolumeTitle)_Label.pdf"
                                }
                            }
                            store.reconcileUniqueDriveAssignments(driveManager: driveManager)
                        } label: {
                            HStack {
                                if item.kind == kind { Image(systemName: "checkmark") }
                                Text(
                                    kind == .physicalBurner
                                        ? (isUSBAlreadyExhausted ? KroutonL10n.tr("USB Burner — In Use") : KroutonL10n.tr("USB Burner"))
                                        : KroutonL10n.tr(kind.rawValue)
                                )
                            }
                        }
                        .disabled(isUSBAlreadyExhausted)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.kind.sfSymbol)
                            .foregroundStyle(store.uiSecondaryAccent)
                        Text(
                            isRightQueueCompact ? item.kind.compactBadgeTitle : (item.kind == .physicalBurner ? KroutonL10n.tr("USB Burner") : KroutonL10n.tr(item.kind.rawValue))
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 2)

                if item.kind == .physicalBurner {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if isFloatingOpen {
                                KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: activeCardDriveID, suckIntoMiniGraph: true)
                            } else if isInlineVisible {
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: false)
                                if var t = driveManager.driveTelemetry[activeCardDriveID] {
                                    t.isActive = false
                                    driveManager.driveTelemetry[activeCardDriveID] = t
                                }
                            } else {
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: true)
                                driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isFloatingOpen ? "arrow.down.right.and.arrow.up.left" : "waveform.path.ecg")
                            if !isRightQueueCompact { Text(isFloatingOpen ? "Dock" : "Scope").lineLimit(1) }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            isFloatingOpen
                                ? (store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent)
                                : (isInlineVisible ? store.uiSecondaryAccent : store.uiSecondaryAccent.opacity(0.18))
                        )
                        .foregroundStyle((isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : store.uiSecondaryAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel(isFloatingOpen ? "Dock Phase Scope Inline" : "Toggle Phase Scope")
                    .help(isFloatingOpen ? "Pull Floating Phase Scope window back into inline mini graph" : "Toggle inline Phase Scope mini graph")

                    if canEject {
                        Button {
                            driveManager.ejectDrive(id: activeCardDriveID)
                        } label: {
                            Group {
                                if isRightQueueCompact {
                                    Image(systemName: "eject.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eject.fill")
                                        Text(KroutonL10n.tr("Eject")).lineLimit(1)
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                }
                            }
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("Eject \(cardDrive?.displayName ?? "Disc")")
                        .help("Eject \(cardDrive?.displayName ?? "Disc")")
                    }
                }

                if store.destinationQueue.count > 1 {
                    Button {
                        store.destinationQueue.removeAll { $0.id == cardID }
                        store.reconcileUniqueDriveAssignments(driveManager: driveManager)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
    }

    @ViewBuilder
    var physicalBurnerDriveAndSpeedSection: some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive strictly from unclaimed drives (never steal a drive in otherUsedDriveIDs!)
        let cardDrive: KroutonOpticalDriveInfo? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID && !otherUsedDriveIDs.contains($0.id) }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) })
        }()

        let activeCardDriveID = (item.kind == .networkBurner) ? "network-spool-drive" : (cardDrive?.id ?? "")
        let validSpeeds = cardDrive?.availableWriteSpeeds ?? ["Max Safe (Auto)"]


        VStack(alignment: .leading, spacing: 10) {
                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(KroutonL10n.tr("No USB Optical Drive Connected")).font(.system(size: 11, weight: .semibold))
                    }
                } else {
                    Menu {
                        ForEach(driveManager.availableDrives) { d in
                            let isTakenByOther = otherUsedDriveIDs.contains(d.id)
                            Button {
                                guard !isTakenByOther else { return }
                                store.updateQueueItem(cardID) { qItem in
                                    qItem.targetDriveID = d.id
                                    qItem.hardwareOrPath = d.displayName
                                    driveManager.selectedDrive = d
                                }
                            } label: {
                                HStack {
                                    if d.id == activeCardDriveID { Image(systemName: "checkmark") }
                                    Text(isTakenByOther ? "\(d.displayName) — In Use" : d.displayName)
                                }
                            }
                            .disabled(isTakenByOther)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(cardDrive?.displayName ?? "Select Optical Burner")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(store.enableSecondaryAccentUITints ? store.uiSecondaryAccent.opacity(0.11) : Color.clear)
                        .background(Color.kroutonControlSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if let activeDrive = cardDrive {
                        HStack(spacing: 6) {
                            Button {
                                activeDiscPopoverCardID = (activeDiscPopoverCardID == cardID) ? nil : cardID
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary)
                                        .frame(width: 6, height: 6)
                                    Text(activeDrive.statusBadgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((activeDrive.isMediaPresent ? store.uiSecondaryAccent : Color.secondary).opacity(0.15))
                                .foregroundStyle(activeDrive.isMediaPresent ? store.uiSecondaryAccent : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(
                                get: { activeDiscPopoverCardID == cardID },
                                set: { if !$0 { activeDiscPopoverCardID = nil } }
                            ), arrowEdge: .leading) {
                                KroutonDiscMediaPopover(drive: activeDrive, accent: store.uiSecondaryAccent)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                // Adaptive Single-Row / Two-Row: Speed ('Max') + Sim + Verify + Copies ('1x')
                let activeSpd = validSpeeds.contains(item.speedOrCodec) ? item.speedOrCodec : "Max Safe (Auto)"
                let shortSpd = activeSpd.hasPrefix("Max") ? "Max" : (activeSpd.components(separatedBy: " ").first ?? activeSpd)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        speedPickerMenu(cardID: cardID, validSpeeds: validSpeeds, activeSpd: activeSpd, shortSpd: shortSpd).fixedSize()
                        Spacer(minLength: 2)
                        simCheckboxToggle(cardID: cardID, label: isRightQueueCompact ? "Sim" : KroutonL10n.tr("Simulate")).fixedSize()
                        Spacer(minLength: 2)
                        verifyCheckboxToggle(cardID: cardID).fixedSize()
                        Spacer(minLength: 2)
                        copiesStepperView(cardID: cardID).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            speedPickerMenu(cardID: cardID, validSpeeds: validSpeeds, activeSpd: activeSpd, shortSpd: shortSpd)
                            Spacer(minLength: 4)
                            copiesStepperView(cardID: cardID)
                        }
                        HStack(spacing: 10) {
                            simCheckboxToggle(cardID: cardID, label: "Sim")
                            verifyCheckboxToggle(cardID: cardID)
                            Spacer(minLength: 0)
                        }
                    }
                }

                }
        }

    @ViewBuilder
    var physicalBurnerBatchAndOptionsSection: some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive strictly from unclaimed drives (never steal a drive in otherUsedDriveIDs!)
        let cardDrive: KroutonOpticalDriveInfo? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID && !otherUsedDriveIDs.contains($0.id) }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) })
        }()

        let activeCardDriveID = (item.kind == .networkBurner) ? "network-spool-drive" : (cardDrive?.id ?? "")


        VStack(alignment: .leading, spacing: 10) {
            if !driveManager.availableDrives.isEmpty {
                if (store.forceDVDROMBookType && !isRightQueueCompact) || (item.copiesToBurn > 1 && store.autoLoadNextDiscBatchMode) {
                    HStack(spacing: 6) {
                        if store.forceDVDROMBookType && !isRightQueueCompact {
                            HStack(spacing: 3) {
                                Image(systemName: "seal.fill")
                                    .font(.system(size: 8))
                                Text(KroutonL10n.tr("DVD-ROM Bitset")).lineLimit(1)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent).opacity(0.16))
                            .foregroundStyle((store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : store.uiSecondaryAccent))
                            .clipShape(Capsule())
                            .help("MMC Bitsetting Active: Stamps DVD+R / DVD+R DL lead-in Book Type as DVD-ROM (0x00)")
                        }

                        if item.copiesToBurn > 1 && store.autoLoadNextDiscBatchMode {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 9))
                                Text("Auto-Load (\(store.autoLoadCountdownSeconds)s)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(store.uiSecondaryAccent.opacity(0.18))
                            .foregroundStyle(store.uiSecondaryAccent)
                            .clipShape(Capsule())
                        }
                        Spacer(minLength: 0)
                    }
                }

                // Live Hands-Free Auto-Load Next Disc Banner (Appears between copies in a batch)
                if let batchSt = driveManager.batchStates[activeCardDriveID] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: batchSt.countdownSecondsRemaining != nil ? "timer" : "opticaldisc.fill")
                                .foregroundStyle(batchSt.countdownSecondsRemaining != nil ? .orange : store.uiSecondaryAccent)
                            Text(batchSt.statusMessage)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            if batchSt.countdownSecondsRemaining == nil {
                                Button {
                                    driveManager.triggerImmediateBatchCountdownForTesting(
                                        driveID: activeCardDriveID,
                                        countdownSeconds: store.autoLoadCountdownSeconds
                                    ) {
                                        store.executeSingleDestination(item, driveManager: driveManager, primarySelectedDrive: primarySelectedDrive, enableCustomFinderLayoutTab: enableCustomFinderLayoutTab, finderIconSize: finderIconSize)
                                    }
                                } label: {
                                    Text("Simulate Blank Disc Insert (\(store.autoLoadCountdownSeconds)s)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(store.uiSecondaryAccent)
                                        .foregroundStyle(store.activeOnAccentText)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                driveManager.cancelBatchDuplication(for: activeCardDriveID)
                            } label: {
                                Text(KroutonL10n.tr("Cancel Batch"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.18))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    .padding(8)
                    .background(store.uiSecondaryAccent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.uiSecondaryAccent.opacity(0.38), lineWidth: 1))
                }
        }
        }
    }
}
