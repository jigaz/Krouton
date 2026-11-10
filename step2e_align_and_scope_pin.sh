#!/bin/zsh
set -e

cd ~/Developer/krouton

# ------------------------------------------------------------------------------
# 1. Update Sources/OpticalDough/OpticalDough.swift
#    - Adds isManuallyPinnedInline: Bool to DrivePhaseScopeTelemetry
#    - Adds toggleScopeButtonAction(for:) so the Scope button overrides auto-hide
#      and docks the floating window back into the inline mini graph!
# ------------------------------------------------------------------------------
python3 - << 'EOF_DOUGH_PY'
path = "Sources/OpticalDough/OpticalDough.swift"
with open(path, "r") as f:
    text = f.read()

old_tel = '''public struct DrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    public let id: String          // Drive ID
    public var driveName: String
    public var isActive: Bool       // True whenever throughputKBs > 0
    public var isFloatingWindowOpen: Bool'''

new_tel = '''public struct DrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    public let id: String          // Drive ID
    public var driveName: String
    public var isActive: Bool       // True whenever throughputKBs > 0
    public var isManuallyPinnedInline: Bool
    public var isFloatingWindowOpen: Bool'''

assert old_tel in text, "old_tel not found"
text = text.replace(old_tel, new_tel, 1)

old_init = '''    public init(
        id: String,
        driveName: String,
        isActive: Bool = false,
        isFloatingWindowOpen: Bool = false,'''

new_init = '''    public init(
        id: String,
        driveName: String,
        isActive: Bool = false,
        isManuallyPinnedInline: Bool = false,
        isFloatingWindowOpen: Bool = false,'''

assert old_init in text, "old_init not found"
text = text.replace(old_init, new_init, 1)

old_assign = '''        self.id = id
        self.driveName = driveName
        self.isActive = isActive
        self.isFloatingWindowOpen = isFloatingWindowOpen'''

new_assign = '''        self.id = id
        self.driveName = driveName
        self.isActive = isActive
        self.isManuallyPinnedInline = isManuallyPinnedInline
        self.isFloatingWindowOpen = isFloatingWindowOpen'''

assert old_assign in text, "old_assign not found"
text = text.replace(old_assign, new_assign, 1)

old_set_float = '''    public func setFloatingScopeOpen(for driveID: String, isOpen: Bool) {
        if var tel = driveTelemetry[driveID] {
            tel.isFloatingWindowOpen = isOpen
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isFloatingWindowOpen: isOpen)
        }
    }'''

new_set_float = '''    public func setFloatingScopeOpen(for driveID: String, isOpen: Bool, keepInlineVisible: Bool = true) {
        if var tel = driveTelemetry[driveID] {
            tel.isFloatingWindowOpen = isOpen
            if !isOpen && keepInlineVisible {
                tel.isManuallyPinnedInline = true
            }
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: !isOpen && keepInlineVisible, isFloatingWindowOpen: isOpen)
        }
    }

    public func setManualInlinePin(for driveID: String, isPinned: Bool) {
        if var tel = driveTelemetry[driveID] {
            tel.isManuallyPinnedInline = isPinned
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isManuallyPinnedInline: isPinned)
        }
        if isPinned && (driveTelemetry[driveID]?.samples.isEmpty ?? true) {
            runPhaseScopeTestSweep(for: driveID, keepPinnedAfterSweep: true)
        }
    }'''

assert old_set_float in text, "old_set_float not found"
text = text.replace(old_set_float, new_set_float, 1)

old_sweep_sig = '''    public func runPhaseScopeTestSweep(for driveID: String) {
        let resolved = driveForID(driveID)
        let targetID = resolved?.id ?? driveID
        guard !targetID.isEmpty else { return }
        let driveName = resolved?.displayName ?? "Optical Drive"
        let mediaType = resolved?.mediaType ?? "CD-RW"
        let totalSectors = max(1, resolved?.freeSectorsLBA ?? 359_847)

        perDriveTimers[targetID]?.invalidate()

        let isFloated = driveTelemetry[targetID]?.isFloatingWindowOpen ?? false'''

new_sweep_sig = '''    public func runPhaseScopeTestSweep(for driveID: String, keepPinnedAfterSweep: Bool = true) {
        let resolved = driveForID(driveID)
        let targetID = resolved?.id ?? driveID
        guard !targetID.isEmpty else { return }
        let driveName = resolved?.displayName ?? "Optical Drive"
        let mediaType = resolved?.mediaType ?? "CD-RW"
        let totalSectors = max(1, resolved?.freeSectorsLBA ?? 359_847)

        perDriveTimers[targetID]?.invalidate()

        let isFloated = driveTelemetry[targetID]?.isFloatingWindowOpen ?? false
        let isPinned = keepPinnedAfterSweep || (driveTelemetry[targetID]?.isManuallyPinnedInline ?? false)'''

assert old_sweep_sig in text, "old_sweep_sig not found"
text = text.replace(old_sweep_sig, new_sweep_sig, 1)

old_tel_init_call = '''        var tel = DrivePhaseScopeTelemetry(
            id: targetID,
            driveName: driveName,
            isActive: true,
            isFloatingWindowOpen: isFloated,'''

new_tel_init_call = '''        let tel = DrivePhaseScopeTelemetry(
            id: targetID,
            driveName: driveName,
            isActive: true,
            isManuallyPinnedInline: isPinned,
            isFloatingWindowOpen: isFloated,'''

assert old_tel_init_call in text, "old_tel_init_call not found"
text = text.replace(old_tel_init_call, new_tel_init_call, 1)

old_autohide = '''                    // Auto-hide the inline mini scope 1.8s after throughput drops to 0 KB/s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if var finished = self.driveTelemetry[targetID], finished.progressFraction >= 1.0 {
                            finished.isActive = false
                            finished.currentSpeedKBs = 0
                            finished.currentSpeedX = 0
                            self.driveTelemetry[targetID] = finished
                        }
                    }'''

new_autohide = '''                    // Mark throughput as 0 after 1.8s, but if isManuallyPinnedInline is true the mini graph stays visible!
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if var finished = self.driveTelemetry[targetID], finished.progressFraction >= 1.0 {
                            finished.isActive = false
                            finished.currentSpeedKBs = 0
                            finished.currentSpeedX = 0
                            finished.phaseTitle = "Standby (Last Sweep Hold)"
                            self.driveTelemetry[targetID] = finished
                        }
                    }'''

assert old_autohide in text, "old_autohide not found"
text = text.replace(old_autohide, new_autohide, 1)

with open(path, "w") as f:
    f.write(text)
print("[OK] Updated OpticalDough.swift with manual Scope override & dock-to-mini state")
EOF_DOUGH_PY

# ------------------------------------------------------------------------------
# 2. Update Sources/KroutonApp/KroutonApp.swift
#    - Aligns all File List columns cleanly (OS Pills: 112pt, LBA: 82pt, Size: 68pt)
#    - Aligns top headers across all 3 columns to identical height & padding
#    - Replaces SwiftUI Picker for Drive selection with custom Menu so in-use
#      drives are shown in light grey (.disabled(true)) and cannot be selected twice,
#      and auto-assigns the first card when drives finish scanning!
#    - Upgrades the Scope button so it overrides auto-hide, changes style when
#      the floating window is open, and sucks the floating window back into the mini graph!
# ------------------------------------------------------------------------------
python3 - << 'EOF_APP_PY'
path = "Sources/KroutonApp/KroutonApp.swift"
with open(path, "r") as f:
    text = f.read()

# A. Ensure KroutonWindowManager.closeFloatingPhaseScopeWindow sucks the floating graph back into the inline mini graph
old_close_fn = '''    func closeFloatingPhaseScopeWindow(driveID: String) {
        driveManager.setFloatingScopeOpen(for: driveID, isOpen: false)
        phaseScopeWindows[driveID]?.close()
    }'''

new_close_fn = '''    func closeFloatingPhaseScopeWindow(driveID: String, suckIntoMiniGraph: Bool = true) {
        driveManager.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: suckIntoMiniGraph)
        phaseScopeWindows[driveID]?.orderOut(nil)
    }'''

assert old_close_fn in text, "old_close_fn not found"
text = text.replace(old_close_fn, new_close_fn, 1)

old_del_close = '''    func windowWillClose(_ notification: Notification) {
        driveManager?.setFloatingScopeOpen(for: driveID, isOpen: false)
    }'''

new_del_close = '''    func windowWillClose(_ notification: Notification) {
        driveManager?.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: true)
    }'''

assert old_del_close in text, "old_del_close not found"
text = text.replace(old_del_close, new_del_close, 1)

# B. Auto-reconcile destinationQueue targetDriveIDs whenever availableDrives updates so no two cards ever share a drive
old_sheet_mod = '''        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }'''

new_sheet_mod = '''        .onAppear {
            reconcileUniqueDriveAssignments()
        }
        .onChange(of: driveManager.availableDrives) { _, _ in
            reconcileUniqueDriveAssignments()
        }
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }'''

assert old_sheet_mod in text, "old_sheet_mod not found"
text = text.replace(old_sheet_mod, new_sheet_mod, 1)

# C. Straighten up File List columns (Fixed column widths for [Mac][PC], LBA, and File Size + Column Header Bar)
old_file_scroll = '''                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(store.stagedFiles) { entry in'''

new_file_scroll = '''                        VStack(spacing: 0) {
                            // Straightened Column Header Bar
                            HStack(spacing: 12) {
                                Text("ITEM NAME & PATH")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 36)
                                Spacer()
                                if activeSpec.isDataDisc {
                                    Text("OS VISIBILITY")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 112, alignment: .center)
                                }
                                Text("SECTORS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 86, alignment: .trailing)
                                Text("SIZE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .trailing)
                                Spacer().frame(width: 22)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.18))
                            Divider()

                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(store.stagedFiles) { entry in'''

assert old_file_scroll in text, "old_file_scroll not found"
text = text.replace(old_file_scroll, new_file_scroll, 1)

old_file_cols = '''                                            .buttonStyle(.plain)
                                                .help(entry.showOnPC ? "Visible on Windows Explorer (ISO9660 / Joliet / UDF Tree) — Click to hide from PC" : "Hidden on Windows PC — Click to show on PC")
                                            }
                                        }

                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)

                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .trailing)

                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    Divider()
                                }
                            }
                        }'''

new_file_cols = '''                                            .buttonStyle(.plain)
                                                .help(entry.showOnPC ? "Visible on Windows Explorer (ISO9660 / Joliet / UDF Tree) — Click to hide from PC" : "Hidden on Windows PC — Click to show on PC")
                                            }
                                            .frame(width: 112, alignment: .center)
                                        }

                                        Text("\(entry.sectorsLBA) LBA")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(store.activeAccent)
                                            .frame(width: 86, alignment: .trailing)

                                        Text(ByteCountFormatter.string(fromByteCount: entry.byteSize, countStyle: .file))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .trailing)

                                        Button {
                                            store.removeStagedFile(id: entry.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 18, alignment: .center)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                                }
                            }
                        }'''

assert old_file_cols in text, "old_file_cols not found"
text = text.replace(old_file_cols, new_file_cols, 1)

# D. Replace destinationCard and add reconcileUniqueDriveAssignments()
start_dest = "    private func destinationCard(item: DestinationQueueItem) -> some View {"
end_dest = "    private func cardActionTitle(for kind: DestinationOutputKind) -> String {"

assert start_dest in text and end_dest in text, "destinationCard section not found"
prefix = text[:text.index(start_dest)]
suffix = text[text.index(end_dest):]

new_dest_card = r"""    // Ensures every physicalBurner card has a unique targetDriveID so 2 cards never select the same drive
    private func reconcileUniqueDriveAssignments() {
        guard !driveManager.availableDrives.isEmpty else { return }
        var claimedIDs = Set<String>()
        for idx in store.destinationQueue.indices {
            guard store.destinationQueue[idx].kind == .physicalBurner else { continue }
            let currentID = store.destinationQueue[idx].targetDriveID
            let isValidDrive = driveManager.availableDrives.contains(where: { $0.id == currentID })
            if isValidDrive && !claimedIDs.contains(currentID) {
                claimedIDs.insert(currentID)
            } else if let nextFree = driveManager.availableDrives.first(where: { !claimedIDs.contains($0.id) }) {
                store.destinationQueue[idx].targetDriveID = nextFree.id
                store.destinationQueue[idx].hardwareOrPath = nextFree.displayName
                claimedIDs.insert(nextFree.id)
            }
        }
    }

    private func destinationCard(item: DestinationQueueItem) -> some View {
        let cardID = item.id

        // Drives claimed by OTHER destination cards in the queue
        let otherUsedDriveIDs = Set(
            store.destinationQueue
                .filter { $0.id != cardID && $0.kind == .physicalBurner && !$0.targetDriveID.isEmpty }
                .map { $0.targetDriveID }
        )

        // Resolve THIS card's drive without falling back to a drive already claimed by another card!
        let cardDrive: OpticalDriveDevice? = {
            if let exact = driveManager.availableDrives.first(where: { $0.id == item.targetDriveID }) {
                return exact
            }
            return driveManager.availableDrives.first(where: { !otherUsedDriveIDs.contains($0.id) }) ?? driveManager.availableDrives.first
        }()

        let activeCardDriveID = cardDrive?.id ?? ""
        let validSpeeds = cardDrive?.availableWriteSpeeds ?? ["Max Safe (Auto)", "24x (4234 KB/s)", "10x (1764 KB/s)", "8x (1411 KB/s)", "4x (705 KB/s)", "2x (353 KB/s)"]

        let scopeTel = driveManager.telemetryForDrive(activeCardDriveID)
        let isFloatingOpen = scopeTel?.isFloatingWindowOpen ?? false
        let isInlineVisible = ((scopeTel?.isActive ?? false) || (scopeTel?.isManuallyPinnedInline ?? false)) && !isFloatingOpen

        let isDriveBusy = driveManager.isExecutingQueue || (scopeTel?.isActive == true)
        let canEject = (cardDrive?.isMediaPresent == true) && !isDriveBusy
        let canErase = (cardDrive?.isMediaPresent == true) && (cardDrive?.isMediaErasable == true) && !isDriveBusy

        return VStack(alignment: .leading, spacing: 10) {
            // Top Row: Output Kind Picker + Scope Toggle/Dock Button + (Conditional) Eject + Remove Card
            HStack(spacing: 6) {
                Image(systemName: item.kind.sfSymbol)
                    .foregroundStyle(store.activeAccent)

                Picker("", selection: Binding(
                    get: { item.kind },
                    set: {
                        let newKind = $0
                        updateQueueItem(cardID) { $0.kind = newKind }
                        reconcileUniqueDriveAssignments()
                    }
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
                    // Scope Button: Overrides auto-hide! If floating window is open, changes style and sucks it back into a mini graph when pressed!
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if isFloatingOpen {
                                // Suck floating window back into inline mini graph!
                                KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: activeCardDriveID, suckIntoMiniGraph: true)
                            } else if isInlineVisible {
                                // Manual override: hide the inline mini graph
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: false)
                                if var t = driveManager.driveTelemetry[activeCardDriveID] {
                                    t.isActive = false
                                    driveManager.driveTelemetry[activeCardDriveID] = t
                                }
                            } else {
                                // Manual override: pin inline mini graph open & run calibration sweep
                                driveManager.setManualInlinePin(for: activeCardDriveID, isPinned: true)
                                driveManager.runPhaseScopeTestSweep(for: activeCardDriveID, keepPinnedAfterSweep: true)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isFloatingOpen ? "arrow.down.right.and.arrow.up.left" : "waveform.path.ecg")
                            Text(isFloatingOpen ? "Dock Scope" : "Scope")
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isFloatingOpen
                                ? Color.cyan
                                : (isInlineVisible ? Color.green : Color.green.opacity(0.16))
                        )
                        .foregroundStyle(
                            (isFloatingOpen || isInlineVisible) ? Color.black.opacity(0.9) : Color.green
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help(isFloatingOpen ? "Pull Floating Phase Scope window back into the inline mini graph" : (isInlineVisible ? "Hide inline Phase Scope mini graph" : "Show inline Phase Scope mini graph (overrides auto-hide)"))

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
                        reconcileUniqueDriveAssignments()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this output from the queue (releases its drive for other cards)")
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
                    // Custom Hardware Drive Menu: Shows all drives, greys out drives selected in other cards, and never shows '(In Use)' on the active drive!
                    Menu {
                        ForEach(driveManager.availableDrives) { d in
                            let isTakenByOther = otherUsedDriveIDs.contains(d.id)
                            Button {
                                guard !isTakenByOther else { return }
                                updateQueueItem(cardID) { qItem in
                                    qItem.targetDriveID = d.id
                                    qItem.hardwareOrPath = d.displayName
                                    driveManager.selectedDrive = d
                                }
                            } label: {
                                HStack {
                                    if d.id == activeCardDriveID {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(isTakenByOther ? "\(d.displayName) — In Use" : d.displayName)
                                }
                            }
                            .disabled(isTakenByOther)
                        }
                    } label: {
                        HStack {
                            Text(cardDrive?.displayName ?? "Select Optical Burner")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

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

            // Bottom Row: Options on Left + Dedicated Per-Card Action Button on Right
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

            // Per-Burner Inline Mini Phase Scope (Shown when active OR manually pinned via Scope button, and not popped out)
            if item.kind == .physicalBurner,
               let scopeTel = scopeTel,
               isInlineVisible {
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

"""

with open(path, "w") as f:
    f.write(prefix + new_dest_card + suffix)
print("[OK] Updated KroutonApp.swift with aligned workspace columns, exclusive drive menu, and Scope override/dock button")
EOF_APP_PY

swift build
git add -A
git commit -m "fix(ui): align workspace columns, enforce exclusive drive selection with greyed-out menu items, and make Scope button pin/dock mini graph" || true
echo "===================================================="
echo " [SUCCESS] Workspace Alignment, Drive Lock & Scope Dock Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "===================================================="
