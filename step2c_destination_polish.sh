#!/bin/zsh
set -e

cd ~/Developer/krouton

python3 - << 'EOF_PY'
path = "Sources/KroutonApp/KroutonApp.swift"
with open(path, "r") as f:
    text = f.read()

# 1. Menu Bar Settings Option: Put a gear icon before "Settings..."
old_menu_settings = """            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    KroutonWindowManager.shared.openSettingsWindow(
                        store: KroutonWindowManager.shared.store,
                        driveManager: KroutonWindowManager.shared.driveManager
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }"""

new_menu_settings = """            CommandGroup(replacing: .appSettings) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(
                        store: KroutonWindowManager.shared.store,
                        driveManager: KroutonWindowManager.shared.driveManager
                    )
                } label: {
                    Label("Settings...", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }"""

assert old_menu_settings in text, "old_menu_settings not found"
text = text.replace(old_menu_settings, new_menu_settings, 1)

# 2. Left Format Chooser Column: Hide "New & Image" badge so titles have room
old_task_badge = """                Text(badge)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.85) : .secondary)"""

new_task_badge = """                if badge != "New & Image" && !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.85) : .secondary)
                }"""

assert old_task_badge in text, "old_task_badge not found"
text = text.replace(old_task_badge, new_task_badge, 1)

# 3. Disc Media Inspector Popout: "NEGOTIATED WRITE SPEEDS"
old_speeds_title = 'Text("NEGOTIATED HARDWARE WRITE SPEEDS (\(drive.displayName))")'
new_speeds_title = 'Text("NEGOTIATED WRITE SPEEDS")'

assert old_speeds_title in text, "old_speeds_title not found"
text = text.replace(old_speeds_title, new_speeds_title, 1)

# 4. Prevent Destination Column Squishing & Upgrade Destination Cards
text = text.replace(
    ".frame(minWidth: 350, idealWidth: 385, maxWidth: 435)",
    ".frame(minWidth: 380, idealWidth: 400, maxWidth: 450)"
)

start_dest = "    private func destinationCard(item: DestinationQueueItem) -> some View {"
end_dest = "    private var allowedDestinationsForCurrentCategory: [DestinationOutputKind] {"

assert start_dest in text and end_dest in text, "destinationCard markers not found"
prefix = text[:text.index(start_dest)]
suffix = text[text.index(end_dest):]

new_dest_section = r"""    private func destinationCard(item: DestinationQueueItem) -> some View {
        let cardID = item.id
        let cardDrive = driveManager.driveForID(item.targetDriveID)
        let activeCardDriveID = cardDrive?.id ?? ""
        let validSpeeds = cardDrive?.availableWriteSpeeds ?? ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

        // Physical drives selected in OTHER destination cards are greyed out in this menu
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        let isDriveBusy = driveManager.isExecutingQueue || (driveManager.telemetryForDrive(activeCardDriveID)?.isActive == true)
        let canEject = (cardDrive?.isMediaPresent == true) && !isDriveBusy
        let canErase = (cardDrive?.isMediaPresent == true) && (cardDrive?.isMediaErasable == true) && !isDriveBusy

        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: Output Kind Picker + Scope + (Conditional) Eject + Remove Card
            HStack(spacing: 6) {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.activeAccent)

                Picker("", selection: Binding(
                    get: { item.kind },
                    set: { newKind in updateQueueItem(cardID) { $0.kind = newKind } }
                )) {
                    ForEach(allowedDestinationsForCurrentCategory) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 135, maxWidth: 175)
                .layoutPriority(1)

                Spacer(minLength: 4)

                if item.kind == .physicalBurner {
                    Button {
                        let currentTel = driveManager.telemetryForDrive(activeCardDriveID)
                        if currentTel?.isActive == true {
                            KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                        } else {
                            driveManager.runPhaseScopeTestSweep(for: activeCardDriveID)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path.ecg")
                            Text(driveManager.telemetryForDrive(activeCardDriveID)?.isFloatingWindowOpen == true ? "Scope Window" : "Scope")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.16))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Start Phase Scope telemetry sweep (or click while active to pop out Floating Phase Scope window)")

                    if canEject {
                        Button {
                            driveManager.ejectDrive(id: activeCardDriveID)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eject.fill")
                                Text("Eject")
                                    .lineLimit(1)
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Eject \(cardDrive?.displayName ?? "Disc")")
                    }
                }

                if store.destinationQueue.count > 1 {
                    Button {
                        store.destinationQueue.removeAll { $0.id == cardID }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this output from the queue")
                }
            }

            if item.kind == .physicalBurner {
                if driveManager.availableDrives.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("No USB Optical Drive Connected")
                            .font(.system(size: 11, weight: .semibold))
                    }
                } else {
                    Picker("Drive:", selection: Binding(
                        get: { activeCardDriveID },
                        set: { newDriveID in
                            guard !otherUsedDriveIDs.contains(newDriveID) else { return }
                            updateQueueItem(cardID) { qItem in
                                qItem.targetDriveID = newDriveID
                                if let chosen = driveManager.driveForID(newDriveID) {
                                    qItem.hardwareOrPath = chosen.displayName
                                    driveManager.selectedDrive = chosen
                                }
                            }
                        }
                    )) {
                        ForEach(driveManager.availableDrives) { d in
                            let isTaken = otherUsedDriveIDs.contains(d.id)
                            Text(isTaken ? "\(d.displayName) (In Use)" : d.displayName)
                                .tag(d.id)
                                .disabled(isTaken)
                        }
                    }
                    .labelsHidden()

                    if let activeDrive = cardDrive {
                        HStack(spacing: 8) {
                            Button {
                                activeDiscPopoverCardID = (activeDiscPopoverCardID == cardID) ? nil : cardID
                            } label: {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(activeDrive.isMediaPresent ? Color.green : Color.secondary)
                                        .frame(width: 7, height: 7)
                                    Text(activeDrive.statusBadgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background((activeDrive.isMediaPresent ? Color.green : Color.secondary).opacity(0.15))
                                .foregroundStyle(activeDrive.isMediaPresent ? .green : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .fixedSize()
                            .help("Click to inspect ATIP/MID manufacturer, dye chemistry, sessions, and sector topology")
                            .popover(isPresented: Binding(
                                get: { activeDiscPopoverCardID == cardID },
                                set: { if !$0 { activeDiscPopoverCardID = nil } }
                            ), arrowEdge: .leading) {
                                DiscMediaInspectorPopover(drive: activeDrive, accent: store.activeAccent)
                            }

                            // Replaced Firmware tag with Erase RW button (only appears when disc is erasable & ready!)
                            if canErase {
                                Menu {
                                    Button("Quick Erase (Fast TOC Blank — ~30s)") {
                                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: false) { _ in }
                                    }
                                    Button("Full Erase (Zero All Sectors)") {
                                        driveManager.eraseRewritableDisc(driveID: activeCardDriveID, fullErase: true) { _ in }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eraser.fill")
                                        Text("Erase RW")
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(store.activeAccent.opacity(0.16))
                                .clipShape(Capsule())
                                .help("Erase rewritable disc in \(activeDrive.displayName)")
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                HStack {
                    Text("Write Speed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: {
                            validSpeeds.contains(item.speedOrCodec) ? item.speedOrCodec : "Max Safe (Auto)"
                        },
                        set: { newVal in
                            updateQueueItem(cardID) { $0.speedOrCodec = newVal }
                        }
                    )) {
                        ForEach(validSpeeds, id: \.self) { spd in
                            Text(spd).tag(spd)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 155)
                }
            } else if item.kind == .networkBurner {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Text("LAN Node Online • 256 MB Ring Buffer")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                }
            } else if item.kind == .discImage {
                HStack(spacing: 6) {
                    TextField("~/Desktop/Krouton_Master.dmg", text: Binding(
                        get: { item.hardwareOrPath },
                        set: { newPath in updateQueueItem(cardID) { $0.hardwareOrPath = newPath } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    Button("Save As...") {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = "\(store.discVolumeTitle).dmg"
                        if panel.runModal() == .OK, let url = panel.url {
                            updateQueueItem(cardID) { $0.hardwareOrPath = url.path }
                        }
                    }
                    .controlSize(.small)
                }
            } else {
                Text(item.hardwareOrPath)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Bottom Row: Options on Left + Dedicated Per-Card Action Button (Burn / Save / Print) on Right!
            HStack(spacing: 10) {
                if item.kind == .physicalBurner || item.kind == .networkBurner {
                    HStack(spacing: 10) {
                        Toggle("Simulate", isOn: Binding(
                            get: { item.simulationMode },
                            set: { val in updateQueueItem(cardID) { $0.simulationMode = val } }
                        ))
                        .font(.caption)
                        Toggle("Verify", isOn: Binding(
                            get: { item.verifyAfterBurn },
                            set: { val in updateQueueItem(cardID) { $0.verifyAfterBurn = val } }
                        ))
                        .font(.caption)
                    }
                } else if item.kind == .discImage {
                    Toggle("Compress Image", isOn: Binding(
                        get: { item.compressAfterCreation },
                        set: { val in updateQueueItem(cardID) { $0.compressAfterCreation = val } }
                    ))
                    .font(.caption)
                }

                Spacer(minLength: 4)

                Button {
                    executeSingleDestination(item)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: cardActionSymbol(for: item.kind))
                            .font(.system(size: 10, weight: .bold))
                        Text(cardActionTitle(for: item.kind))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(store.activeAccent)
                    .foregroundStyle(store.activeOnAccentText)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(driveManager.isExecutingQueue)
                .help("Execute only this destination card (\(item.kind.rawValue))")
            }

            // Auto-Hiding Per-Burner Inline Mini Phase Scope (Appears only when throughput > 0 KB/s and not popped out)
            if item.kind == .physicalBurner,
               let scopeTel = driveManager.telemetryForDrive(activeCardDriveID),
               scopeTel.isActive && !scopeTel.isFloatingWindowOpen {
                InlineMiniPhaseScopeView(telemetry: scopeTel, accent: store.activeAccent) {
                    KroutonWindowManager.shared.openFloatingPhaseScopeWindow(driveID: activeCardDriveID)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(store.activeAccent.opacity(0.35), lineWidth: 1)
        )
    }

    private func cardActionTitle(for kind: DestinationOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "Burn Disc"
        case .discImage:
            return "Save Image"
        case .audioRip:
            return "Rip Audio"
        case .videoExtract:
            return "Extract Video"
        case .discPrinter:
            return "Print Label"
        case .pdfVector:
            return "Save PDF"
        }
    }

    private func cardActionSymbol(for kind: DestinationOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "flame.fill"
        case .discImage:
            return "internaldrive.fill"
        case .audioRip:
            return "waveform"
        case .videoExtract:
            return "film"
        case .discPrinter:
            return "printer.fill"
        case .pdfVector:
            return "doc.richtext.fill"
        }
    }

    private func executeSingleDestination(_ target: DestinationQueueItem) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = BurnCompletionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the operation."
            )
            return
        }

        Task { @MainActor in
            await runTargetDestination(target)
        }
    }

    private func runTargetDestination(_ target: DestinationQueueItem) async {
        switch target.kind {
        case .discImage:
            _ = await driveManager.createDiscImageFile(
                stagedFiles: store.stagedFiles,
                volumeTitle: store.discVolumeTitle,
                outputPathString: target.hardwareOrPath,
                compressImage: target.compressAfterCreation,
                enableCustomLayout: enableCustomFinderLayoutTab,
                iconSizePx: Int(finderIconSize)
            )

        case .physicalBurner:
            driveManager.startPhysicalDataBurn(
                driveID: target.targetDriveID,
                stagedFiles: store.stagedFiles,
                volumeTitle: store.discVolumeTitle,
                requestedSpeedLabel: target.speedOrCodec,
                simulationMode: target.simulationMode,
                verifyDisc: target.verifyAfterBurn
            ) { _ in }

        default:
            break
        }
    }

    private func executeDestinationQueue() {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = BurnCompletionReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the burn."
            )
            return
        }

        Task { @MainActor in
            for target in store.destinationQueue {
                await runTargetDestination(target)
            }
        }
    }

"""

with open(path, "w") as f:
    f.write(prefix + new_dest_section + suffix)
print("[OK] Updated KroutonApp.swift with all 8 UI & Destination Card refinements")
EOF_PY

swift build
git add -A
git commit -m "feat(destinations): refine card layout, add per-card action buttons, grey out used drives, and conditionally show Erase/Eject" || true
echo "===================================================="
echo " [SUCCESS] Destination Card & Format Chooser Polish Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "===================================================="
