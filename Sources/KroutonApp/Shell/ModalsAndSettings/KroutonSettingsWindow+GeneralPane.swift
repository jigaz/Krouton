import NetworkSpool
import DriveKit
import SwiftUI
import UniformTypeIdentifiers
import OpticalCore


// MARK: - Settings Window: General Pane

extension KroutonSettingsWindowView {
    var generalPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Theme, Appearance & Accent Color") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Color"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr(store.selectedAccentIndex == -1 ? "Multicolor (Adapts per workspace)" : "Krouton Accent Swatch"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 9) {
                        ForEach(KroutonAccentColorPreset.allPresets) { preset in
                            Button {
                                store.selectedAccentIndex = preset.id
                            } label: {
                                ZStack {
                                    if preset.id == -1 {
                                        Circle()
                                            .fill(
                                                AngularGradient(
                                                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 22, height: 22)
                                    } else if preset.isMonochrome {
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
                                            .fill(preset.swatchColor)
                                            .frame(width: 22, height: 22)
                                    }
                                    Circle()
                                        .stroke(
                                            store.selectedAccentIndex == preset.id ? Color.primary : Color.secondary.opacity(0.35),
                                            lineWidth: store.selectedAccentIndex == preset.id ? 2.5 : 1.0
                                        )
                                        .frame(width: 27, height: 27)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.id == -1 ? "Multicolor Accent" : (preset.isMonochrome ? "Monochrome High Contrast" : "Accent Swatch \(preset.id)"))
                        }
                    }
                }

                Divider()

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Window & UI Harmony")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent : Color.primary)
                                Text("Tint windows & UI accents with secondary harmony color")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            KroutonDualHarmonySwitch(
                                isOn: $store.enableSecondaryAccentUITints,
                                primaryColor: store.activeAccent,
                                secondaryColor: store.activeSecondaryAccent
                            )
                        }

                        Divider()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Icon & widget style"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr("Controls how format badges, drive icons, and telemetry tiles render"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        ForEach(KroutonGarnishStyleMode.allCases) { style in
                            Button {
                                store.iconWidgetStyle = style
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(
                                                style == .defaultStyle ? LinearGradient(colors: [store.activeAccent, store.activeAccent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                (style == .dark ? LinearGradient(colors: [Color(white: 0.16), Color(white: 0.08)], startPoint: .top, endPoint: .bottom) :
                                                (style == .clear ? LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom) :
                                                (store.resolvedColorScheme == .light
                                                    ? LinearGradient(colors: [Color(white: 0.98), Color(white: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    : LinearGradient(colors: [Color(white: 0.15), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))))
                                            )
                                            .overlay(
                                                Group {
                                                    if style == .tinted && store.enableSecondaryAccentUITints {
                                                        let pid = store.selectedAccentIndex >= 0 ? store.selectedAccentIndex : store.multicolorPresetID(forTaskID: store.selectedTaskID, category: store.selectedCategory)
                                                        let brightHarmony = KroutonStateStore.secondaryHarmonyForPresetID(pid, scheme: .dark)
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .fill(store.resolvedColorScheme == .light ? brightHarmony.opacity(0.40) : store.activeSecondaryAccent.opacity(0.28))
                                                    } else if style == .tinted && store.resolvedColorScheme == .light {
                                                        RoundedRectangle(cornerRadius: 9)
                                                            .fill(store.activeAccent.opacity(0.15))
                                                    }
                                                }
                                            )
                                            .frame(width: 44, height: 38)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 9)
                                                    .stroke(
                                                        store.iconWidgetStyle == style
                                                            ? store.uiSecondaryAccent
                                                            : (style == .tinted && store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.55) : Color.primary.opacity(0.18)),
                                                        lineWidth: store.iconWidgetStyle == style ? 2.5 : 1.0
                                                    )
                                            )
                                        Image(systemName: "opticaldisc.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(style == .tinted ? store.activeAccent : (style == .clear ? Color.primary : .white))
                                    }
                                    Text(KroutonL10n.tr(style.rawValue))
                                        .font(.system(size: 10, weight: store.iconWidgetStyle == style ? .bold : .regular))
                                        .foregroundStyle(store.iconWidgetStyle == style ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Appearance Mode"))
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(KroutonRoastAppearanceMode.allCases) { mode in
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
                    Text(KroutonL10n.tr("Folder color"))
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(store.resolvedFolderIconColor)
                        Picker("", selection: $store.folderColorMode) {
                            ForEach(KroutonStageFolderColorMode.allCases) { fMode in
                                Text(KroutonL10n.tr(fMode.rawValue)).tag(fMode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 175)
                    }
                }
            }
                generalPaneBottomSection
        }
    }

    @ViewBuilder
    private var generalPaneBottomSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            settingsCard(title: "Windows, Sidebar & Language") {
                HStack {
                    Text(KroutonL10n.tr("Sidebar icon size"))
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $store.sidebarIconSize) {
                        ForEach(KroutonTrackIconSizeMode.allCases) { sz in
                            Text(KroutonL10n.tr(sz.rawValue)).tag(sz)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Application Language (Live UI Localization)"))
                            .fontWeight(.medium)
                        Text(KroutonL10n.tr("Switches workspace headers, buttons & VoiceOver labels immediately without restarting"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $store.appLanguage) {
                        ForEach(KroutonLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }
            }

            settingsCard(title: "Startup & Units") {
                HStack {
                    Toggle(KroutonL10n.tr("Automatically remember application state, staged files, and active task on launch (offers to start empty if a crash is detected)"), isOn: $store.rememberLastTaskOnLaunch)
                    Spacer()
                    Button(KroutonL10n.tr("Test Crash Prompt")) {
                        KroutonCrashRecoveryController.shared.simulateUncleanCrashFlagForTesting(store: store)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Capacity & Addressing Units"))
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
            }

            settingsCard(title: "Scratch Disk & System Permissions") {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KroutonL10n.tr("Temporary Mastering Cache"))
                        Text(KroutonL10n.tr("Available Free Space: 412.8 GB on Macintosh HD (APFS)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Path", text: $store.scratchDiskPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    pillToggleButton(title: "Choose...", sfSymbol: "folder.fill", isSelected: false) {
                        isShowingScratchFolderImporter = true
                    }
                    .fileImporter(
                        isPresented: $isShowingScratchFolderImporter,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            store.scratchDiskPath = url.path
                        }
                    }
                }
                Divider()
                Toggle(KroutonL10n.tr("Automatically purge temporary muxing files after verified burn"), isOn: $store.autoPurgeScratch)
                Divider()
                HStack(spacing: 18) {
                    Label(KroutonL10n.tr("Optical MMC Access: Granted"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label(KroutonL10n.tr("Local Network Discovery: Active"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Label(KroutonL10n.tr("FSKit Mount Extension: Registered"), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }
}
