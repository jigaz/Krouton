import Foundation
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Window: Labels, Notifications, Accessibility & Shared Controls

extension KroutonSettingsWindowView {

    var labelsPrintersPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Auto-Label") {
                Toggle(KroutonL10n.tr("Turn volume and file names into a readable title with Apple Intelligence"),
                       isOn: Bindable(store).labelSuggestionsEnabled)
                Text(KroutonLabelSuggester.isAvailable
                     ? KroutonL10n.tr("Runs on this Mac; nothing is sent anywhere. Only titles that look like file or volume names, such as SUMMER_2026_FINAL, are changed.")
                     : KroutonL10n.tr("Needs macOS 26 or later on Apple silicon with Apple Intelligence turned on. Until then, Auto-Label uses titles as they are."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        }
    }

    var notificationsPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Notifications") {
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
                                    sfSymbol: "speaker.wave.2.fill",
                                    helpText: "Play a Sound",
                                    isOn: Bindable(store).notificationMatrix[idx].soundEnabled
                                )
                                KroutonNotificationSoundControlView(
                                    sound: Bindable(store).notificationMatrix[idx].sound,
                                    isEnabled: row.soundEnabled,
                                    accent: store.activeAccent
                                )
                                .frame(minWidth: 150, alignment: .trailing)
                            }
                        }
                        if idx < store.notificationMatrix.count - 1 {
                            Divider()
                        }
                    }
                }
                Divider()
                Toggle(KroutonL10n.tr("Give each drive its own pitch, so you can tell by ear which burner finished or wants a disc"),
                       isOn: Bindable(store).distinctDriveVoices)
                Picker(KroutonL10n.tr("Show progress in the menu bar"), selection: Bindable(store).menuBarStatusMode) {
                    ForEach(KroutonLiveStatus.MenuBarMode.allCases) { mode in
                        Text(KroutonL10n.tr(mode.rawValue)).tag(mode)
                    }
                }
                .fixedSize()
                Divider()
                HStack {
                    Text(KroutonNotificationAndCompanionService.shared.lastDispatchedBannerText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    pillToggleButton(title: "Send Test Notification", sfSymbol: "bell.badge.fill", isSelected: false) {
                        KroutonNotificationAndCompanionService.shared.dispatchEvent(
                            id: "done", title: "Krouton Test Notification",
                            subtitle: "Notifications are working.", store: store
                        )
                    }
                }
            }
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
                Text(KroutonL10n.tr("Reduce Motion in System Settings › Accessibility › Display turns off Krouton's animations."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                Text(KroutonL10n.tr("Takes effect the next time Krouton opens. Krouton is in English; translations are being added, and until then other languages change only a few labels. You can also choose the language in System Settings › General › Language & Region › Applications."))
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
