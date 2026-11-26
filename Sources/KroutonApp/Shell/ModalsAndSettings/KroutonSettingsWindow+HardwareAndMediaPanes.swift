import DriveKit
import Foundation
import NetworkSpool
import OpticalCore
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

            settingsCard(title: "Checksums, Test-Boot & Feed") {
                Text(KroutonL10n.tr("Every depot download is checked against the SHA-256 depot.krouton.app recorded for it. A file that doesn't match is deleted, never burned."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Divider()
                Toggle(KroutonL10n.tr("Enable Apple Virtualization.framework 'Test-Boot in VM' button for El Torito / UEFI images"), isOn: Bindable(store).enableVMTestBootInDepot)
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
            settingsCard(title: "Red Book Audio CD & Crossfade Defaults") {
                Toggle(KroutonL10n.tr("Analyze BPM & Beat Grid automatically via Apple SoundAnalysis on import"), isOn: Bindable(store).autoBeatmatchSoundAnalysis)
                Divider()
                HStack {
                    Text(String(format: "Default Equal-Power Crossfade Overlap: %.1f seconds", store.defaultCrossfadeSec))
                    Spacer()
                    Slider(value: Bindable(store).defaultCrossfadeSec, in: 0.0...8.0, step: 0.5)
                        .frame(width: 220)
                }
                Divider()
                Toggle(KroutonL10n.tr("Car-Stereo Safe MP3 Mode (Enforce ID3v2.3 & strip hidden macOS ._* files)"), isOn: Bindable(store).carSafeMP3Mode)
            }

            settingsCard(title: "Video Authoring & Menu Defaults") {
                Toggle(KroutonL10n.tr("Single Video Track: Play immediately on disc insert (skip menu)"), isOn: Bindable(store).singleVideoFirstPlay)
                Divider()
                Toggle(KroutonL10n.tr("Use Apple Silicon VideoToolbox 2-Pass Hardware VBR for Blu-ray & DVD encoding"), isOn: Bindable(store).videoToolboxTwoPassVBR)
            }

            settingsCard(title: "Fit-to-Disc Compression Defaults (DVD-9 to 4.7 GB DVD-5 & BD-50 to BD-25)") {
                Toggle(KroutonL10n.tr("Always preserve interactive Menus, Chapter Tables & Bonus Featurettes when shrinking"), isOn: Bindable(store).fitToDiscPreserveMenus)
                Divider()
                Toggle(KroutonL10n.tr("Automatically strip foreign audio dubs (retain Original Language + English) to maximize video bitrate"), isOn: Bindable(store).fitToDiscStripForeignDubs)
            }

            settingsCard(title: "Universal Hardware & Software Decoder Matrix") {
                HStack {
                    Label(KroutonL10n.tr("Apple Silicon VideoToolbox ASIC + Accelerate vDSP + libavformat/libavcodec Active"), systemImage: "cpu.fill")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(KroutonL10n.tr("Zero-Copy GPU & SIMD Pipeline"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider()
                ForEach(KroutonMediaPrepEngine.liveHardwareCodecMatrix) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: row.isHardwareAccelerated ? "bolt.shield.fill" : "cpu")
                                .foregroundStyle(row.isHardwareAccelerated ? .green : store.activeAccent)
                                .font(.system(size: 12))
                            Text(row.category)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(row.hardwareStatus)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.16))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        HStack {
                            Text("Formats: \(row.formatsAndExtensions)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Engine: \(row.primaryEngine)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(store.activeAccent)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
    }

    var rippingTranscodingPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Optical Drive Read Offset & Error Recovery (CD / DVD / BD Ripping)") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(KroutonL10n.tr("Drive Sample Read Offset Correction"))
                        Text(KroutonL10n.tr("Compensates for physical laser lead-in/lead-out offset on Matshita/Pioneer/LG drives"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Offset", value: Bindable(store).driveReadOffsetSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text(KroutonL10n.tr("samples"))
                        .font(.caption)
                }
                Divider()
                HStack {
                    Text(KroutonL10n.tr("Paranoia Scratched Sector Re-Read Retries"))
                    Spacer()
                    Stepper("\(store.paranoiaErrorRetries) passes", value: Bindable(store).paranoiaErrorRetries, in: 1...64)
                }
                Divider()
                Toggle(KroutonL10n.tr("Verify ripped audio tracks against AccurateRip & MusicBrainz database"), isOn: Bindable(store).verifyAccurateRip)
                Divider()
                Toggle(KroutonL10n.tr("Generate archival .cue sheet and extraction .log alongside ALAC / FLAC rips"), isOn: Bindable(store).writeCueSheetLog)
            }

            settingsCard(title: "Video Disc Extraction & Hardware VideoToolbox") {
                Toggle(KroutonL10n.tr("Hardware Motion-Compensated Deinterlacing (480i / 1080i -> Progressive H.265)"), isOn: Bindable(store).hardwareDeinterlaceVideo)
                Divider()
                Toggle(KroutonL10n.tr("Passthrough lossless Dolby Atmos / TrueHD / DTS-HD Master Audio bitstreams"), isOn: Bindable(store).passthroughAtmosTrueHD)
            }

            settingsCard(title: "Smart File & Track Naming Pattern (Zero-Script Token Builder)") {
                Text(KroutonL10n.tr("Click tokens below to append to your active naming pattern, or click any active token pill to remove it:"))
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

                Text("Live Output Preview: \(store.namingPreviewString)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(store.activeAccent)
            }
        }
    }
}
