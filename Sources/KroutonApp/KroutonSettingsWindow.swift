import SwiftUI
import AppKit

public enum KroutonSettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case taskChooser = "Task Chooser"
    case audioVideo = "Audio & Video"
    case rippingTranscoding = "Ripping & Transcoding"
    case burnersNetwork = "Burners & Network"
    case notifications = "Notifications"

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .general: return "gearshape"
        case .taskChooser: return "sidebar.left"
        case .audioVideo: return "waveform"
        case .rippingTranscoding: return "arrow.triangle.2.circlepath"
        case .burnersNetwork: return "externaldrive.connected.to.line.below"
        case .notifications: return "bell"
        }
    }
}

public struct KroutonSettingsWindowView: View {
    @ObservedObject var store: KroutonStateStore
    @State private var selectedPane: KroutonSettingsCategory = .general
    @State private var searchText: String = ""
    @State private var taskChooserSubTab: Int = 0
    @State private var newPresetName: String = "Custom Disc Tray Preset"
    @State private var newOuterMM: Double = 120.0
    @State private var newInnerMM: Double = 18.0
    @State private var newOffsetX: Double = 0.0
    @State private var newOffsetY: Double = 0.0

    public init(store: KroutonStateStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search settings", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .padding(.horizontal, 10)
                .padding(.top, 8)

                List(KroutonSettingsCategory.allCases, selection: $selectedPane) { pane in
                    HStack(spacing: 10) {
                        Image(systemName: pane.sfSymbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedPane == pane ? store.activeAccent : .secondary)
                            .frame(width: 20)
                        Text(pane.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 4)
                    .tag(pane)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(selectedPane.rawValue)
                        .font(.title2.bold())

                    switch selectedPane {
                    case .general:
                        generalPane
                    case .taskChooser:
                        taskChooserPane
                    case .audioVideo:
                        audioVideoPane
                    case .rippingTranscoding:
                        rippingTranscodingPane
                    case .burnersNetwork:
                        burnersNetworkPane
                    case .notifications:
                        notificationsPane
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 940, idealWidth: 1040, minHeight: 560, idealHeight: 680)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .tint(store.activeAccent)
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Appearance & Accent Color") {
                HStack {
                    Text("Appearance")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            pillToggleButton(
                                title: mode.rawValue,
                                sfSymbol: mode.sfSymbol,
                                isSelected: store.appearanceMode == mode
                            ) {
                                store.appearanceMode = mode
                            }
                        }
                    }
                }
                Divider()
                HStack {
                    Text("Accent Color")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(AccentColorPreset.allPresets) { preset in
                            Button {
                                store.selectedAccentIndex = preset.id
                            } label: {
                                ZStack {
                                    if preset.isMonochrome {
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [.white, .white, .black, .black],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    } else {
                                        Circle()
                                            .fill(preset.primary)
                                            .frame(width: 22, height: 22)
                                    }
                                    Circle()
                                        .stroke(
                                            store.selectedAccentIndex == preset.id ? Color.primary : Color.secondary.opacity(0.35),
                                            lineWidth: store.selectedAccentIndex == preset.id ? 2.5 : 1.0
                                        )
                                        .frame(width: 26, height: 26)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            settingsCard(title: "Startup & Units") {
                Toggle("Remember Last Used Task on Launch", isOn: $store.rememberLastTaskOnLaunch)
                Divider()
                HStack {
                    Text("Capacity & Addressing Units")
                    Spacer()
                    HStack(spacing: 8) {
                        pillToggleButton(title: "Base-10 (4.7 GB / 25 GB)", sfSymbol: "opticaldisc", isSelected: store.useBase10Units) {
                            store.useBase10Units = true
                        }
                        pillToggleButton(title: "Binary (4.37 GiB / LBA)", sfSymbol: "number.square", isSelected: !store.useBase10Units) {
                            store.useBase10Units = false
                        }
                    }
                }
                Divider()
                Toggle("Show Krouton Status Icon in macOS Menu Bar", isOn: $store.showMenuBarHelper)
            }

            settingsCard(title: "Scratch Disk & System Permissions") {
                HStack {
                    Text("Temporary Mastering Cache")
                    Spacer()
                    TextField("Path", text: $store.scratchDiskPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
                Divider()
                Toggle("Automatically purge temporary muxing files after verified burn", isOn: $store.autoPurgeScratch)
                Divider()
                HStack(spacing: 18) {
                    Label("Optical MMC Access: Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("Local Network Discovery: Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label("FSKit Mount Extension: Registered", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }

    private var taskChooserPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                pillToggleButton(
                    title: "BURN — Optical Format Catalog (\(store.discFormats.count) Formats)",
                    sfSymbol: "opticaldisc.fill",
                    isSelected: taskChooserSubTab == 0
                ) {
                    taskChooserSubTab = 0
                }
                pillToggleButton(
                    title: "LABEL — Geometry Presets & Artwork Lookup",
                    sfSymbol: "printer.dotmatrix.fill",
                    isSelected: taskChooserSubTab == 1
                ) {
                    taskChooserSubTab = 1
                }
                Spacer()
            }

            if taskChooserSubTab == 0 {
                settingsCard(title: "Master Optical Disc Format Matrix (1982 – 2026)") {
                    HStack(spacing: 10) {
                        Text("Show").frame(width: 44, alignment: .leading)
                        Text("Format & Colloquial Name").frame(width: 245, alignment: .leading)
                        Text("Year").frame(width: 45, alignment: .leading)
                        Text("Capacity").frame(width: 95, alignment: .leading)
                        Text("Laser").frame(width: 85, alignment: .leading)
                        Text("Platform / Plays On").frame(width: 155, alignment: .leading)
                        Text("Status").frame(width: 95, alignment: .leading)
                        Text("Standard / Mode").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                    Divider()

                    ForEach(Array(store.discFormats.enumerated()), id: \.element.id) { idx, fmt in
                        VStack(spacing: 6) {
                            HStack(spacing: 10) {
                                Toggle("", isOn: $store.discFormats[idx].showInTaskChooser)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .frame(width: 44, alignment: .leading)

                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Image(systemName: fmt.sfSymbol)
                                        .foregroundStyle(store.activeAccent)
                                        .font(.system(size: 11))
                                    Text(fmt.technicalName)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(fmt.colloquialName)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 245, alignment: .leading)
                                .lineLimit(1)

                                Text(fmt.launchYear)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 45, alignment: .leading)

                                Text(fmt.capacity)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 95, alignment: .leading)

                                Text(fmt.laserType)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 85, alignment: .leading)

                                Text(fmt.platform)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 155, alignment: .leading)
                                    .lineLimit(1)

                                Text(fmt.deprecationStatus)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(fmt.deprecationStatus == "Current" ? .green : .secondary)
                                    .frame(width: 95, alignment: .leading)

                                Text("\(fmt.sourceSupport) • \(fmt.bookOrFileSystem)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                            if idx < store.discFormats.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } else {
                settingsCard(title: "Saved Disc Label Geometry & Tray Offset Presets (Available in Workspace)") {
                    ForEach(Array(store.labelPresets.enumerated()), id: \.element.id) { idx, preset in
                        HStack {
                            Image(systemName: "circle.circle")
                                .foregroundStyle(store.activeAccent)
                            Text(preset.name)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "Outer: %.1fmm | Hole: %.1fmm | Offset X:%.1f Y:%.1fmm", preset.outerDiameterMM, preset.innerDiameterMM, preset.offsetXMM, preset.offsetYMM))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if store.labelPresets.count > 1 {
                                Button {
                                    store.labelPresets.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Divider()
                    }

                    HStack(spacing: 10) {
                        TextField("Preset Name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 210)
                        Text("Outer:")
                            .font(.caption)
                        TextField("120", value: $newOuterMM, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 55)
                        Text("Inner:")
                            .font(.caption)
                        TextField("18", value: $newInnerMM, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("X/Y Offset:")
                            .font(.caption)
                        TextField("0.0", value: $newOffsetX, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        TextField("0.0", value: $newOffsetY, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 45)
                        Spacer()
                        Button {
                            store.labelPresets.append(
                                LabelGeometryPreset(
                                    name: newPresetName,
                                    outerDiameterMM: newOuterMM,
                                    innerDiameterMM: newInnerMM,
                                    offsetXMM: newOffsetX,
                                    offsetYMM: newOffsetY
                                )
                            )
                        } label: {
                            Label("Save Preset", systemImage: "plus.circle.fill")
                        }
                    }
                }

                settingsCard(title: "Automatic Label Artwork Lookup & Vision Framing") {
                    Toggle("Use Apple Vision Subject Detection to keep faces/logos out of the 18mm center hole", isOn: $store.visionHoleAvoidance)
                    Divider()
                    Text("Zero-Key Databases Enabled: MusicBrainz / Cover Art Archive, Apple iTunes, TVMaze, GameTDB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        TextField("Optional TMDB API Key (Movies & TV)", text: $store.customTMDBKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Optional Fanart.tv Key (Transparent Circular Disc Art)", text: $store.customFanartKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    private var audioVideoPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Red Book Audio CD & Jam Crossfade Defaults") {
                Toggle("Analyze BPM & Beat Grid automatically via Apple SoundAnalysis on import", isOn: $store.autoBeatmatchSoundAnalysis)
                Divider()
                HStack {
                    Text(String(format: "Default Equal-Power Crossfade Overlap: %.1f seconds", store.defaultCrossfadeSec))
                    Spacer()
                    Slider(value: $store.defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Car-Stereo Safe MP3 Mode (Enforce ID3v2.3 & strip hidden macOS ._* files)", isOn: $store.carSafeMP3Mode)
            }

            settingsCard(title: "Video Authoring & Menu Defaults") {
                Toggle("Single Video Track: Play immediately on disc insert (skip menu)", isOn: $store.singleVideoFirstPlay)
                Divider()
                Text("When 2 or more video tracks are staged, Krouton automatically enables the Minimalist Title/Episode Menu in the workspace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Optical Drive Read Offset & Error Recovery (CD / DVD / BD Ripping)") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Drive Sample Read Offset Correction")
                        Text("Compensates for physical laser lead-in/lead-out offset on Pioneer/LG drives")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Offset", value: $store.driveReadOffsetSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("samples")
                        .font(.caption)
                }
                Divider()
                HStack {
                    Text("Paranoia Scratched Sector Re-Read Retries")
                    Spacer()
                    Stepper("\(store.paranoiaErrorRetries) passes", value: $store.paranoiaErrorRetries, in: 1...64)
                }
                Divider()
                Toggle("Verify ripped audio tracks against AccurateRip & MusicBrainz database", isOn: $store.verifyAccurateRip)
                Divider()
                Toggle("Generate archival .cue sheet and extraction .log alongside ALAC / FLAC rips", isOn: $store.writeCueSheetLog)
            }

            settingsCard(title: "Video Disc Extraction & Hardware VideoToolbox") {
                Toggle("Hardware Motion-Compensated Deinterlacing (480i / 1080i -> Progressive H.265)", isOn: $store.hardwareDeinterlaceVideo)
                Divider()
                Toggle("Passthrough lossless Dolby Atmos / TrueHD / DTS-HD Master Audio bitstreams", isOn: $store.passthroughAtmosTrueHD)
            }

            settingsCard(title: "Smart File & Track Naming Pattern (Zero-Script Token Builder)") {
                HStack(spacing: 8) {
                    ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]"], id: \.self) { token in
                        pillToggleButton(title: token, sfSymbol: "tag.fill", isSelected: false) {
                            store.namingTokens.append(" - ")
                            store.namingTokens.append(token)
                        }
                    }
                    Spacer()
                    Button("Reset") {
                        store.namingTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                    }
                }
                Text("Preview: 01 - The Krouton Trio - Analogue Horizon.m4a")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }

    private var burnersNetworkPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Network Optical Server (krouton-node) & Buffer Protection") {
                Toggle("Share this Mac's connected optical drives on the local network", isOn: $store.enableNetworkServerSharing)
                Divider()
                HStack {
                    Text("Server RAM Ring Buffer Allocation: \(Int(store.serverRingBufferMB)) MB")
                    Spacer()
                    Slider(value: $store.serverRingBufferMB, in: 64...1024, step: 64)
                        .frame(width: 220)
                }
                Divider()
                Toggle("Pre-stage full compiled disc image to remote server SSD before igniting laser", isOn: $store.preStageImageToServerSSD)
            }

            settingsCard(title: "Optical Drive Hardware & MMC Bitsetting") {
                Toggle("Force DVD+R / DVD+R DL BookType to DVD-ROM (Maximizes standalone player compatibility)", isOn: $store.forceDVDROMBookType)
                Divider()
                Toggle("Disable BD-R Defect Management Spare Area on Video Blu-rays (Enables full rated write speed)", isOn: $store.disableBDDefectManagementForVideo)
            }
        }
    }

    private var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Alerts, iPhone Live Activities & Apple Watch Notifications") {
                ForEach(Array(store.notificationMatrix.enumerated()), id: \.element.id) { idx, row in
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.eventTitle)
                                    .font(.system(size: 13, weight: .medium))
                                Text(row.eventSubtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                iconCircleToggle(
                                    sfSymbol: "bell.fill",
                                    helpText: "macOS Notification Banner",
                                    isOn: $store.notificationMatrix[idx].bannerEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "iphone",
                                    helpText: "iPhone Live Activity",
                                    isOn: $store.notificationMatrix[idx].iPhoneEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "applewatch",
                                    helpText: "Apple Watch Smart Stack & Wrist Tap",
                                    isOn: $store.notificationMatrix[idx].watchEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "speaker.wave.2.fill",
                                    helpText: "Play Audio Alert Sound",
                                    isOn: $store.notificationMatrix[idx].soundEnabled
                                )
                            }
                        }
                        if idx < store.notificationMatrix.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                Label("macOS Notification Center", systemImage: "bell.fill")
                Label("iPhone Live Activity", systemImage: "iphone")
                Label("Apple Watch Alert", systemImage: "applewatch")
                Label("Sound Effect", systemImage: "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func pillToggleButton(title: String, sfSymbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? store.activeAccent.opacity(0.22) : Color(NSColor.windowBackgroundColor))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? store.activeAccent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 1.0)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconCircleToggle(sfSymbol: String, helpText: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: sfSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isOn.wrappedValue ? store.activeAccent : Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}
