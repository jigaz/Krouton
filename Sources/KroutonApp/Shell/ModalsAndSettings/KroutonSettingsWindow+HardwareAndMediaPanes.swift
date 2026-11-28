import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings Window: Depot, Audio/Video, Ripping & Burners/Network Panes

extension KroutonSettingsWindowView {

    var discImageDepotPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Disc Image Depot — Sections from depot.krouton.app") {
                if store.depotChannels.isEmpty {
                    Text(store.depotFeedStatus ?? "The depot list hasn't loaded yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(store.depotChannels.enumerated()), id: \.element.id) { idx, channel in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: channel.sfSymbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(store.activeAccent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(channel.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("• \(channel.itemCount) Images")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(store.activeAccent)
                                }
                                Text(channel.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Bindable(store).depotChannels[idx].isEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        if idx < store.depotChannels.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            settingsCard(title: "Checksums & Feed") {
                Text(KroutonL10n.tr("Every depot download is checked against the SHA-256 depot.krouton.app recorded for it. A file that doesn't match is deleted, never burned."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Depot feed address"))
                    Spacer()
                    TextField("https://...", text: Bindable(store).customDepotFeedURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                    Button(KroutonL10n.tr("Refresh")) {
                        Task { await store.refreshDepotFeed() }
                    }
                }
                Text(store.depotFeedGenerated.map { "List last checked by the depot on \($0)." } ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var audioVideoPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "DVD-9 to DVD-5 Shrink (Copy › Duplicate Disc)") {
                Toggle(KroutonL10n.tr("Keep the DVD menus when copying or shrinking (off: no menus, and the disc plays every title in order)"), isOn: Bindable(store).preserveMenusAndExtras)
                Text(KroutonL10n.tr("Pauses, crossfades and the MP3 CD options are set in their own workspaces."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Checking Rips") {
                Toggle(KroutonL10n.tr("Check each ripped track against the AccurateRip database"), isOn: Bindable(store).verifyAccurateRip)
                Text(KroutonL10n.tr("Sends only the disc's AccurateRip ID. A match means other people's rips of the same CD came out identical."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            settingsCard(title: "Ripped File Names") {
                Text(KroutonL10n.tr("Ripped tracks are named with this pattern. Click a token to add it; click a token in the pattern to remove it. A / makes a folder."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(["[Track 01]", "[Artist]", "[Album]", "[Title]", "[Year]", " - ", "/"], id: \.self) { token in
                        pillToggleButton(title: token, sfSymbol: "plus.circle", isSelected: false) {
                            store.namingTokens.append(token)
                        }
                    }
                    Spacer()
                    Button(KroutonL10n.tr("Reset Default")) {
                        store.namingTokens = ["[Track 01]", " - ", "[Artist]", " - ", "[Title]"]
                    }
                }

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text(KroutonL10n.tr("Active Pattern:"))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(Array(store.namingTokens.enumerated()), id: \.offset) { idx, tok in
                            Button {
                                store.namingTokens.remove(at: idx)
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tok)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Example: \(store.namingPreviewString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }
}
