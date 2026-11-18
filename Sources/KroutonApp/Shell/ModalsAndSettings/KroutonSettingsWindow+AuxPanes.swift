import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Window: Labels, Notifications, Accessibility & Shared Controls

extension KroutonSettingsWindowView {

    var labelsPrintersPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Saved Disc Label Geometry & Tray Offset Presets (Epson EcoTank ET-8550 & Standard Trays)") {
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
                            .accessibilityLabel(KroutonL10n.tr("Delete Label Preset"))
                            .help(KroutonL10n.tr("Delete Label Preset"))
                        }
                    }
                    Divider()
                }

                HStack(spacing: 10) {
                    TextField("Preset Name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                    Text(KroutonL10n.tr("Outer:"))
                        .font(.caption)
                    TextField("120", value: $newOuterMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 55)
                    Text(KroutonL10n.tr("Inner:"))
                        .font(.caption)
                    TextField("18", value: $newInnerMM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text(KroutonL10n.tr("X/Y Offset:"))
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
                            KroutonDiscLabelGeometry(
                                name: newPresetName,
                                outerDiameterMM: newOuterMM,
                                innerDiameterMM: newInnerMM,
                                offsetXMM: newOffsetX,
                                offsetYMM: newOffsetY
                            )
                        )
                    } label: {
                        Label(KroutonL10n.tr("Save Preset"), systemImage: "plus.circle.fill")
                    }
                }
            }

            settingsCard(title: "Automatic Label Artwork Lookup & Vision Hole-Avoidance") {
                Toggle(KroutonL10n.tr("Use Apple Vision Subject Detection to keep faces/logos out of the 18mm center hole"), isOn: Bindable(store).visionHoleAvoidance)
                Divider()
                Text(KroutonL10n.tr("Zero-Key Databases Enabled: MusicBrainz / Cover Art Archive, Apple iTunes, TVMaze, GameTDB"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("Optional TMDB API Key (Movies & TV)", text: Bindable(store).customTMDBKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Optional Fanart.tv Key (Transparent Circular Disc Art)", text: Bindable(store).customFanartKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Alerts, iPhone Live Activities & Apple Watch Notifications") {
                ForEach(Array(store.notificationMatrix.enumerated()), id: \.element.id) { idx, row in
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(KroutonL10n.tr(row.eventTitle))
                                    .font(.system(size: 13, weight: .medium))
                                Text(KroutonL10n.tr(row.eventSubtitle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                iconCircleToggle(
                                    sfSymbol: "bell.fill",
                                    helpText: "macOS Notification Banner",
                                    isOn: Bindable(store).notificationMatrix[idx].bannerEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "iphone",
                                    helpText: "iPhone Live Activity",
                                    isOn: Bindable(store).notificationMatrix[idx].iPhoneEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "applewatch",
                                    helpText: "Apple Watch Smart Stack & Wrist Tap",
                                    isOn: Bindable(store).notificationMatrix[idx].watchEnabled
                                )
                                iconCircleToggle(
                                    sfSymbol: "speaker.wave.2.fill",
                                    helpText: "Play Audio Alert Sound",
                                    isOn: Bindable(store).notificationMatrix[idx].soundEnabled
                                )
                            }
                        }
                        if idx < store.notificationMatrix.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "iPhone Live Activity & Apple Watch Smart Stack Telemetry Feed") {
                let comp = KroutonNotificationAndCompanionService.shared.latestCompanionPayload
                HStack(spacing: 14) {
                    Image(systemName: "applewatch.watchface")
                        .font(.system(size: 28))
                        .foregroundStyle(store.activeAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(comp.title) • \(Int(comp.progressFraction * 100))%")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(comp.subtitle) (\(comp.driveName) • \(comp.speedLabel))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(KroutonNotificationAndCompanionService.shared.lastDispatchedBannerText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(store.activeAccent)
                    }
                    Spacer()
                    pillToggleButton(title: "Send Test Alert", sfSymbol: "bell.badge.fill", isSelected: false) {
                        KroutonNotificationAndCompanionService.shared.dispatchEvent(
                            id: "done",
                            title: "Krouton Mastering Verified",
                            subtitle: "Optical Disc & Companion Telemetry Online",
                            progress: 1.0,
                            driveName: driveManager.selectedDrive?.displayName ?? "ATAPI iHAS124 F",
                            speedLabel: "16.0x CAV",
                            store: store
                        )
                    }
                }
            }

            HStack(spacing: 20) {
                Label(KroutonL10n.tr("macOS Notification Center"), systemImage: "bell.fill")
                Label(KroutonL10n.tr("iPhone Live Activity"), systemImage: "iphone")
                Label(KroutonL10n.tr("Apple Watch Alert"), systemImage: "applewatch")
                Label(KroutonL10n.tr("Sound Effect"), systemImage: "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    var accessibilityLanguagePane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "VoiceOver & Spoken Hardware Telemetry") {
                Toggle(KroutonL10n.tr("Announce optical drive events, disc insertions, and burn phase changes via macOS VoiceOver"), isOn: Bindable(store).voiceOverSpokenTelemetry)
                    .fontWeight(.semibold)
                Text(KroutonL10n.tr("Posts priority VoiceOver Accessibility announcements when blank media is locked, when the 5-second Auto-Load timer counts down, and when verification completes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Test VoiceOver Telemetry Speech"))
                    Spacer()
                    pillToggleButton(title: "Speak Status Now", sfSymbol: "speaker.wave.3.fill", isSelected: false) {
                        let drv = driveManager.selectedDrive?.displayName ?? "Optical Burner"
                        store.announceForVoiceOver("Krouton Accessibility Ready. Active burner: \(drv).")
                        KroutonOSDesktopBridge.playAcousticCue()
                    }
                }
            }

            settingsCard(title: "Acoustic Telemetry Soundboard & DSP Lab") {
                KroutonAcousticSoundboardCardView(accent: store.activeAccent)
            }

            settingsCard(title: "Display, Contrast & Motion Accessibility") {
                Toggle(KroutonL10n.tr("Increase Contrast (High-contrast borders on Format Chooser, Tracklists & Phase Scope)"), isOn: Bindable(store).a11yIncreaseContrast)
                Divider()
                Toggle(KroutonL10n.tr("Differentiate Without Color (Show explicit status symbols alongside green/amber/red LEDs)"), isOn: Bindable(store).a11yDifferentiateWithoutColor)
                Divider()
                Toggle(KroutonL10n.tr("Reduce Motion (Disable continuous disc rotation & smooth Phase Scope sweeps)"), isOn: Bindable(store).a11yReduceMotion)

            }

            settingsCard(title: "Internationalization & Foreign Languages") {
                HStack {
                    Text(KroutonL10n.tr("Active Interface Language"))
                        .fontWeight(.semibold)
                    Spacer()
                    Picker("", selection: Bindable(store).appLanguage) {
                        ForEach(KroutonLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 230)
                }
                Divider()
                Text(KroutonL10n.tr("Supported Locales: English (US) • 日本語 (Japanese) • Deutsch (German) • Français (French) • Español (Spanish) • 简体中文 (Simplified Chinese) • 한국어 (Korean). All CD-TEXT & Joliet/UDF descriptors remain hardware-sanitized per regional optical standards."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KroutonL10n.tr(title))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color.kroutonControlSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    func pillToggleButton(title: String, sfSymbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(KroutonL10n.tr(title))
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? store.uiSecondaryAccent.opacity(0.22) : Color.kroutonWindowSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? store.uiSecondaryAccent : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 1.0))
        }
        .buttonStyle(.plain)
    }

    func iconCircleToggle(sfSymbol: String, helpText: String, isOn: Binding<Bool>) -> some View {
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
        .accessibilityLabel(helpText)
        .accessibilityValue(isOn.wrappedValue ? KroutonL10n.tr("Enabled") : KroutonL10n.tr("Disabled"))
    }
}
