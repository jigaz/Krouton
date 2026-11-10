#!/bin/zsh
set -e

cd ~/Developer/krouton

# ------------------------------------------------------------------------------
# 1. Update project_history.md to v0.2.0-alpha.4 (Step 2B: Per-Drive Inline Mini Phase Scope)
# ------------------------------------------------------------------------------
cat << 'EOF_HISTORY' > project_history.md
# Krouton Project History & Architecture Log

## Current Version: `v0.2.0-alpha.4` (Step 2B — Per-Drive Inline Mini Phase Scope)
* **Target OS:** macOS 26 (Tahoe) / Apple Silicon (`arm64`)
* **Domain:** [krouton.app](https://krouton.app)

### Phase Scope 3-Step Implementation Plan
* **Step 2A (`v0.2.0-alpha.3` — Completed):**
  1. Fixed `ContiguousArrayBuffer` out-of-range crash by using `UUID`-based destination card bindings.
  2. Built the textured, card-based **Disc Media Inspector Popover** with media-accurate disc icons (`CD-RW`, `CD-R`, `DVD-R`, `BD-R`, `M-DISC`, `DVD-RAM`), mounted volume/file scanning, and removed all non-clickable fake pills across the app.
  3. Implemented deterministic AppKit `NSWindow` launch inside `KroutonWindowManager`.
* **Step 2B (`v0.2.0-alpha.4` — Current Commit):**
  1. Added `DrivePhaseScopeTelemetry` per-drive dictionary (`driveTelemetry: [String: DrivePhaseScopeTelemetry]`) inside `DriveManager` so each connected optical burner tracks its own independent speed, spindle RPM, buffer fill, LBA sector cursor, and waveform samples.
  2. Added a per-drive `Timer` Registry (`driveTimers: [String: Timer]`) so simultaneous multi-drive burns update each burner's telemetry independently.
  3. Embedded the auto-hiding **`InlineMiniPhaseScopeView`** inside each physical burner destination card: hidden when idle (`0 KB/s`), and automatically expands with a live CRT grid, Emerald Write Speed curve, Amber Spindle RPM curve, and Red LBA cursor whenever that specific drive has active throughput (`> 0 KB/s`).
  4. Added a **"Test Scope"** pill button inside each burner card so you can test-fire a 6-second simulated P-CAV laser telemetry sweep on any drive without burning a disc.
* **Step 2C (`v0.2.0-alpha.5` — Next Commit):**
  1. Clicking the inline mini Phase Scope pops out a dedicated, resizable **Floating Phase Scope Window** (`NSWindow`) for that burner (automatically hiding the inline mini graph while its floating window is open).
  2. Render multi-layer high-detail curves: translucent Emerald Write Speed area, dashed Cyan Target P-CAV curve, Amber Spindle RPM curve, Purple Buffer Fill ribbon, and Red Radial LBA (`r = 24.0 mm -> 58.0 mm`) cursor.
EOF_HISTORY
echo "[OK] Updated project_history.md to v0.2.0-alpha.4"

# ------------------------------------------------------------------------------
# 2. Update Sources/OpticalDough/OpticalDough.swift
#    Adds per-drive DrivePhaseScopeTelemetry dictionary & Test Sweep generator
# ------------------------------------------------------------------------------
python3 - << 'EOF_DOUGH_PY'
path = "Sources/OpticalDough/OpticalDough.swift"
with open(path, "r") as f:
    text = f.read()

# A. Add DrivePhaseScopeTelemetry struct right after NeroTelemetrySample
target_sample = """public struct NeroTelemetrySample: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let progressFraction: Double
    public let speedMultiplierX: Double
    public let spindleRPM: Double
    public let throughputKBs: Double

    public init(
        id: UUID = UUID(),
        progressFraction: Double,
        speedMultiplierX: Double,
        spindleRPM: Double,
        throughputKBs: Double
    ) {
        self.id = id
        self.progressFraction = progressFraction
        self.speedMultiplierX = speedMultiplierX
        self.spindleRPM = spindleRPM
        self.throughputKBs = throughputKBs
    }
}"""

telemetry_struct = target_sample + """

public struct DrivePhaseScopeTelemetry: Identifiable, Hashable, Sendable {
    public let id: String          // Drive ID
    public var driveName: String
    public var isActive: Bool       // True whenever throughputKBs > 0
    public var isFloatingWindowOpen: Bool
    public var phaseTitle: String
    public var progressFraction: Double
    public var currentSpeedX: Double
    public var currentSpeedKBs: Double
    public var peakSpeedX: Double
    public var averageSpeedX: Double
    public var targetSpeedX: Double
    public var currentSpindleRPM: Int
    public var currentSectorLBA: Int64
    public var totalSectorsLBA: Int64
    public var bufferFillPercent: Double
    public var laserWavelengthText: String
    public var writeStrategyText: String
    public var elapsedSeconds: Int
    public var samples: [NeroTelemetrySample]

    public init(
        id: String,
        driveName: String,
        isActive: Bool = false,
        isFloatingWindowOpen: Bool = false,
        phaseTitle: String = "Idle",
        progressFraction: Double = 0.0,
        currentSpeedX: Double = 0.0,
        currentSpeedKBs: Double = 0.0,
        peakSpeedX: Double = 0.0,
        averageSpeedX: Double = 0.0,
        targetSpeedX: Double = 16.0,
        currentSpindleRPM: Int = 0,
        currentSectorLBA: Int64 = 0,
        totalSectorsLBA: Int64 = 359_847,
        bufferFillPercent: Double = 98.0,
        laserWavelengthText: String = "780 nm IR",
        writeStrategyText: String = "P-CAV",
        elapsedSeconds: Int = 0,
        samples: [NeroTelemetrySample] = []
    ) {
        self.id = id
        self.driveName = driveName
        self.isActive = isActive
        self.isFloatingWindowOpen = isFloatingWindowOpen
        self.phaseTitle = phaseTitle
        self.progressFraction = progressFraction
        self.currentSpeedX = currentSpeedX
        self.currentSpeedKBs = currentSpeedKBs
        self.peakSpeedX = peakSpeedX
        self.averageSpeedX = averageSpeedX
        self.targetSpeedX = targetSpeedX
        self.currentSpindleRPM = currentSpindleRPM
        self.currentSectorLBA = currentSectorLBA
        self.totalSectorsLBA = totalSectorsLBA
        self.bufferFillPercent = bufferFillPercent
        self.laserWavelengthText = laserWavelengthText
        self.writeStrategyText = writeStrategyText
        self.elapsedSeconds = elapsedSeconds
        self.samples = samples
    }

    public var radialMillimeters: Double {
        24.0 + (34.0 * min(1.0, max(0.0, progressFraction)))
    }
}"""

assert target_sample in text, "NeroTelemetrySample block not found"
text = text.replace(target_sample, telemetry_struct, 1)

# B. Add @Published public var driveTelemetry: [String: DrivePhaseScopeTelemetry] = [:] to DriveManager
old_published = """    @Published public var isExecutingQueue: Bool = false
    @Published public var activeJobPhase: String = "Idle"
    @Published public var activeJobProgress: Double = 0.0
    @Published public var activeJobDetail: String = "" """.strip()

new_published = """    @Published public var isExecutingQueue: Bool = false
    @Published public var activeJobPhase: String = "Idle"
    @Published public var activeJobProgress: Double = 0.0
    @Published public var activeJobDetail: String = ""
    @Published public var driveTelemetry: [String: DrivePhaseScopeTelemetry] = [:]
    private var perDriveTimers: [String: Timer] = [:]"""

assert old_published in text, "old_published not found"
text = text.replace(old_published, new_published, 1)

# C. Add helper methods for per-drive telemetry lookup, updates, and a 6-second Test Scope sweep
helper_anchor = """    public func driveForID(_ id: String) -> OpticalDriveDevice? {"""

telemetry_helpers = """    public func telemetryForDrive(_ driveID: String) -> DrivePhaseScopeTelemetry? {
        if let existing = driveTelemetry[driveID] {
            return existing
        }
        return nil
    }

    public func setFloatingScopeOpen(for driveID: String, isOpen: Bool) {
        if var tel = driveTelemetry[driveID] {
            tel.isFloatingWindowOpen = isOpen
            driveTelemetry[driveID] = tel
        } else {
            let name = driveForID(driveID)?.displayName ?? "Optical Drive"
            driveTelemetry[driveID] = DrivePhaseScopeTelemetry(id: driveID, driveName: name, isFloatingWindowOpen: isOpen)
        }
    }

    // Runs a live 6-second P-CAV Phase Scope telemetry sweep on a specific drive card so users can test & inspect the inline/floating scope anytime!
    public func runPhaseScopeTestSweep(for driveID: String) {
        let resolved = driveForID(driveID)
        let targetID = resolved?.id ?? driveID
        guard !targetID.isEmpty else { return }
        let driveName = resolved?.displayName ?? "Optical Drive"
        let mediaType = resolved?.mediaType ?? "CD-RW"
        let totalSectors = max(1, resolved?.freeSectorsLBA ?? 359_847)

        perDriveTimers[targetID]?.invalidate()

        let isFloated = driveTelemetry[targetID]?.isFloatingWindowOpen ?? false
        let divisor: Double = mediaType.contains("BD") ? 4500.0 : (mediaType.contains("DVD") ? 1385.0 : 176.4)
        let laserStr = mediaType.contains("BD") ? "405 nm Violet" : (mediaType.contains("DVD") ? "650 nm Red" : "780 nm IR")

        var tel = DrivePhaseScopeTelemetry(
            id: targetID,
            driveName: driveName,
            isActive: true,
            isFloatingWindowOpen: isFloated,
            phaseTitle: "Phase Scope Calibration Sweep...",
            progressFraction: 0.02,
            currentSpeedX: 4.0,
            currentSpeedKBs: 4.0 * divisor,
            peakSpeedX: 4.0,
            averageSpeedX: 4.0,
            targetSpeedX: 16.0,
            currentSpindleRPM: 2400,
            currentSectorLBA: 0,
            totalSectorsLBA: totalSectors,
            bufferFillPercent: 99.0,
            laserWavelengthText: laserStr,
            writeStrategyText: "P-CAV Telemetry",
            elapsedSeconds: 0,
            samples: []
        )
        driveTelemetry[targetID] = tel

        let startDate = Date()
        perDriveTimers[targetID] = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, var current = self.driveTelemetry[targetID] else { return }
                let nextFrac = min(1.0, current.progressFraction + 0.032)
                // Classic Nero P-CAV curve with tiny realistic optical servo jitter
                let jitter = Double((Int(nextFrac * 100) % 5) - 2) * 0.12
                let speedX = max(2.0, 4.2 + (11.8 * pow(nextFrac, 0.78)) + jitter)
                let kbs = speedX * divisor
                let rpm = Int(2250.0 + (speedX * 165.0 * (1.0 - nextFrac * 0.38)))

                current.progressFraction = nextFrac
                current.currentSpeedX = speedX
                current.currentSpeedKBs = kbs
                if speedX > current.peakSpeedX { current.peakSpeedX = speedX }
                current.currentSpindleRPM = rpm
                current.currentSectorLBA = Int64(Double(totalSectors) * nextFrac)
                current.bufferFillPercent = Double(95 + (Int(nextFrac * 50) % 5))
                current.elapsedSeconds = max(1, Int(Date().timeIntervalSince(startDate)))
                current.phaseTitle = nextFrac < 0.99 ? "Phase Scope Active (\(String(format: "%.1fx", speedX)))" : "Sweep Complete"

                current.samples.append(NeroTelemetrySample(
                    progressFraction: nextFrac,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(rpm),
                    throughputKBs: kbs
                ))
                let sumX = current.samples.reduce(0.0) { $0 + $1.speedMultiplierX }
                current.averageSpeedX = sumX / Double(max(1, current.samples.count))

                if nextFrac >= 1.0 {
                    self.perDriveTimers[targetID]?.invalidate()
                    self.perDriveTimers.removeValue(forKey: targetID)
                    self.driveTelemetry[targetID] = current
                    // Auto-hide the inline mini scope 1.8s after throughput drops to 0 KB/s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if var finished = self.driveTelemetry[targetID], finished.progressFraction >= 1.0 {
                            finished.isActive = false
                            finished.currentSpeedKBs = 0
                            finished.currentSpeedX = 0
                            self.driveTelemetry[targetID] = finished
                        }
                    }
                } else {
                    self.driveTelemetry[targetID] = current
                }
            }
        }
    }

    public func driveForID(_ id: String) -> OpticalDriveDevice? {"""

assert helper_anchor in text, "helper_anchor not found"
text = text.replace(helper_anchor, telemetry_helpers, 1)

# D. Hook eraseRewritableDisc and startPhysicalDataBurn into driveTelemetry[activeDriveID] so real burns/erases drive the per-card Phase Scope!
old_erase_sample = """                self.neroSamples.append(NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: simulatedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: self.currentSpeedKBs
                ))"""

new_erase_sample = """                let sample = NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: simulatedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: self.currentSpeedKBs
                )
                self.neroSamples.append(sample)
                let targetKey = resolvedMeta?.id ?? (driveID ?? "")
                if !targetKey.isEmpty {
                    var dTel = self.driveTelemetry[targetKey] ?? DrivePhaseScopeTelemetry(id: targetKey, driveName: driveName)
                    dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
                    dTel.phaseTitle = self.activeJobPhase
                    dTel.progressFraction = clampedPct
                    dTel.currentSpeedX = simulatedX
                    dTel.currentSpeedKBs = self.currentSpeedKBs
                    if simulatedX > dTel.peakSpeedX { dTel.peakSpeedX = simulatedX }
                    dTel.currentSpindleRPM = self.currentSpindleRPM
                    dTel.currentSectorLBA = self.currentSectorLBA
                    dTel.totalSectorsLBA = self.totalTargetSectorsLBA
                    dTel.laserWavelengthText = self.laserWavelengthText
                    dTel.writeStrategyText = self.writeStrategyText
                    dTel.elapsedSeconds = self.elapsedSeconds
                    dTel.samples.append(sample)
                    let sSum = dTel.samples.reduce(0.0) { $0 + $1.speedMultiplierX }
                    dTel.averageSpeedX = sSum / Double(max(1, dTel.samples.count))
                    self.driveTelemetry[targetKey] = dTel
                }"""

assert old_erase_sample in text, "old_erase_sample not found"
text = text.replace(old_erase_sample, new_erase_sample, 1)

old_burn_sample = """                self.neroSamples.append(NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: reportedKBs
                ))
                let sumX = self.neroSamples.reduce(0.0) { $0 + $1.speedMultiplierX }
                self.averageSpeedX = sumX / Double(max(1, self.neroSamples.count))"""

new_burn_sample = """                let sample = NeroTelemetrySample(
                    progressFraction: clampedPct,
                    speedMultiplierX: speedX,
                    spindleRPM: Double(self.currentSpindleRPM),
                    throughputKBs: reportedKBs
                )
                self.neroSamples.append(sample)
                let sumX = self.neroSamples.reduce(0.0) { $0 + $1.speedMultiplierX }
                self.averageSpeedX = sumX / Double(max(1, self.neroSamples.count))

                let targetKey = resolvedMeta?.id ?? (driveID ?? "")
                if !targetKey.isEmpty {
                    var dTel = self.driveTelemetry[targetKey] ?? DrivePhaseScopeTelemetry(id: targetKey, driveName: driveName)
                    dTel.isActive = (rawState != DRStatusStateDone && rawState != DRStatusStateFailed)
                    dTel.phaseTitle = self.activeJobPhase
                    dTel.progressFraction = clampedPct
                    dTel.currentSpeedX = speedX
                    dTel.currentSpeedKBs = reportedKBs
                    if speedX > dTel.peakSpeedX { dTel.peakSpeedX = speedX }
                    dTel.averageSpeedX = self.averageSpeedX
                    dTel.currentSpindleRPM = self.currentSpindleRPM
                    dTel.currentSectorLBA = self.currentSectorLBA
                    dTel.totalSectorsLBA = totalLBA
                    dTel.bufferFillPercent = self.driveBufferFillPercent
                    dTel.laserWavelengthText = self.laserWavelengthText
                    dTel.writeStrategyText = self.writeStrategyText
                    dTel.elapsedSeconds = self.elapsedSeconds
                    dTel.samples.append(sample)
                    self.driveTelemetry[targetKey] = dTel
                }"""

assert old_burn_sample in text, "old_burn_sample not found"
text = text.replace(old_burn_sample, new_burn_sample, 1)

with open(path, "w") as f:
    f.write(text)
print("[OK] Updated Sources/OpticalDough/OpticalDough.swift with per-drive DrivePhaseScopeTelemetry")
EOF_DOUGH_PY

# ------------------------------------------------------------------------------
# 3. Update Sources/KroutonApp/KroutonApp.swift
#    Embeds auto-hiding InlineMiniPhaseScopeView inside each physical burner card
#    (plus a clickable 'Test Scope' pill button so you can trigger a live sweep anytime!)
# ------------------------------------------------------------------------------
python3 - << 'EOF_APP_PY'
path = "Sources/KroutonApp/KroutonApp.swift"
with open(path, "r") as f:
    text = f.read()

# A. Add a 'Test Scope' pill button right next to Erase RW & Eject in destinationCard
old_card_buttons = """                    Button {
                        driveManager.ejectDrive(id: activeCardDriveID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eject.fill")
                            Text("Eject")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Eject \\(cardDrive?.displayName ?? "Disc")")"""

new_card_buttons = """                    Button {
                        driveManager.runPhaseScopeTestSweep(for: activeCardDriveID)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "waveform.path.ecg")
                            Text("Scope")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.16))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Trigger a 6-second Phase Scope telemetry sweep on this burner")

                    Button {
                        driveManager.ejectDrive(id: activeCardDriveID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eject.fill")
                            Text("Eject")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Eject \\(cardDrive?.displayName ?? "Disc")")"""

assert old_card_buttons in text, "old_card_buttons not found"
text = text.replace(old_card_buttons, new_card_buttons, 1)

# B. Inject the auto-hiding InlineMiniPhaseScopeView at the bottom of each physicalBurner card
old_sim_toggles = """            if item.kind == .physicalBurner || item.kind == .networkBurner {
                HStack(spacing: 12) {
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
            }"""

new_sim_toggles = old_sim_toggles + """

            // Auto-Hiding Per-Burner Inline Mini Phase Scope (Appears only when throughput > 0 KB/s and not popped out)
            if item.kind == .physicalBurner,
               let scopeTel = driveManager.telemetryForDrive(activeCardDriveID),
               scopeTel.isActive && !scopeTel.isFloatingWindowOpen {
                InlineMiniPhaseScopeView(telemetry: scopeTel, accent: store.activeAccent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }"""

assert old_sim_toggles in text, "old_sim_toggles not found"
text = text.replace(old_sim_toggles, new_sim_toggles, 1)

# C. Append InlineMiniPhaseScopeView struct at the bottom of KroutonApp.swift
mini_scope_struct = """

// MARK: - Step 2B: Per-Burner Auto-Hiding Inline Mini Phase Scope
struct InlineMiniPhaseScopeView: View {
    let telemetry: DrivePhaseScopeTelemetry
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("PHASE SCOPE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.green)
                Spacer()
                Text(String(format: "%.1fx (%.0f KB/s)", telemetry.currentSpeedX, telemetry.currentSpeedKBs))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\\(telemetry.currentSpindleRPM) RPM")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }

            // Classic Nero CRT Grid + Emerald Write Speed Curve + Yellow RPM Curve + Red LBA Playhead
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.02, green: 0.03, blue: 0.07))

                Canvas { context, size in
                    let cols = 8
                    let rows = 4
                    let gridColor = Color(red: 0.08, green: 0.18, blue: 0.72).opacity(0.75)

                    for c in 0...cols {
                        let x = size.width * CGFloat(c) / CGFloat(cols)
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                    }
                    for r in 0...rows {
                        let y = size.height * CGFloat(r) / CGFloat(rows)
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(gridColor), lineWidth: 0.6)
                    }

                    let samples = telemetry.samples
                    if samples.count > 1 {
                        let maxScaleX: Double = 24.0
                        let maxScaleRPM: Double = 6000.0

                        var speedArea = Path()
                        var speedPath = Path()
                        var rpmPath = Path()

                        for (idx, s) in samples.enumerated() {
                            let x = size.width * CGFloat(min(1.0, max(0.0, s.progressFraction)))
                            let ySpeed = size.height * (1.0 - CGFloat(min(1.0, s.speedMultiplierX / maxScaleX)))
                            let yRPM = size.height * (1.0 - CGFloat(min(1.0, s.spindleRPM / maxScaleRPM)))

                            if idx == 0 {
                                speedArea.move(to: CGPoint(x: x, y: size.height))
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedPath.move(to: CGPoint(x: x, y: ySpeed))
                                rpmPath.move(to: CGPoint(x: x, y: yRPM))
                            } else {
                                speedArea.addLine(to: CGPoint(x: x, y: ySpeed))
                                speedPath.addLine(to: CGPoint(x: x, y: ySpeed))
                                rpmPath.addLine(to: CGPoint(x: x, y: yRPM))
                            }
                        }

                        if let last = samples.last {
                            let lastX = size.width * CGFloat(min(1.0, max(0.0, last.progressFraction)))
                            speedArea.addLine(to: CGPoint(x: lastX, y: size.height))
                            speedArea.closeSubpath()

                            context.fill(
                                speedArea,
                                with: .linearGradient(
                                    Gradient(colors: [Color.green.opacity(0.32), Color.green.opacity(0.02)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)
                                )
                            )

                            context.stroke(rpmPath, with: .color(.yellow), lineWidth: 1.3)
                            context.stroke(speedPath, with: .color(.green), lineWidth: 1.8)

                            var cursorPath = Path()
                            cursorPath.move(to: CGPoint(x: lastX, y: 0))
                            cursorPath.addLine(to: CGPoint(x: lastX, y: size.height))
                            context.stroke(cursorPath, with: .color(.red), lineWidth: 1.2)
                        }
                    }
                }
                .padding(3)
            }
            .frame(height: 68)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.45), lineWidth: 1))

            HStack {
                Text("LBA \\(telemetry.currentSectorLBA) / \\(telemetry.totalSectorsLBA)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "r = %.1f mm • Buf %.0f%%", telemetry.radialMillimeters, telemetry.bufferFillPercent))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.30), lineWidth: 1))
    }
}
"""

text = text + mini_scope_struct
with open(path, "w") as f:
    f.write(text)
print("[OK] Added InlineMiniPhaseScopeView and per-card Scope trigger to KroutonApp.swift")
EOF_APP_PY

swift build
git add -A
git commit -m "feat(scope): implement Step 2B per-drive auto-hiding Inline Mini Phase Scope in burner cards" || true
echo "===================================================="
echo " [SUCCESS] Step 2B (Inline Mini Phase Scope) Built!"
echo " Switch to Xcode and press Command + R to test!"
echo "===================================================="
