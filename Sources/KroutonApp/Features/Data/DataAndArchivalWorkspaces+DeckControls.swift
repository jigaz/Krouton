import OpticalCore
import SwiftUI

// MARK: - Data & Archival Deck Header & Bottom Options

extension KroutonDataAndArchivalWorkspaceView {
    @ViewBuilder
    var dataDeckTopControlsSection: some View {
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        let isClassicHFS = (activeSpec.id == "macos9-hfs")
        let isPhotoCD = (activeSpec.id == "photo-cd")
        VStack(alignment: .leading, spacing: 8) {
                if activeSpec.isMDiscParityFormat {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("M-DISC ROCK-LAYER VAULT + PAR2 PARITY:"))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(store.mdiscParityPercent == 0 ? "PAR2: Off" : "PAR2: \(Int(store.mdiscParityPercent))%")
                                .font(.caption.bold())
                                .foregroundStyle(store.activeAccent)
                            Slider(value: Bindable(store).mdiscParityPercent, in: 0...30, step: 5)
                                .frame(width: 130)
                            Text(KroutonL10n.tr("• par2 recovery files on the disc"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(store.activeAccent)
                                    .accessibilityHidden(true)
                                Text(KroutonL10n.tr("M-DISC ROCK-LAYER VAULT"))
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(store.mdiscParityPercent == 0 ? "PAR2: Off" : "PAR2: \(Int(store.mdiscParityPercent))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(store.activeAccent)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            HStack(spacing: 8) {
                                Slider(value: Bindable(store).mdiscParityPercent, in: 0...30, step: 5)
                                    .frame(maxWidth: 135)
                                    .accessibilityLabel("M-DISC PAR2 Parity Percentage")
                                    .accessibilityValue("\(Int(store.mdiscParityPercent)) percent")
                                Text(KroutonL10n.tr("par2 recovery files on the disc"))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Divider()
                }

                ViewThatFits(in: .horizontal) {
                    // 1. Wide Horizontal Bar
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("Volume Title", text: Bindable(store).discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 135)
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        if activeSpec.id == "dvd-ram" {
                            Label("Rewritable Data Disc (ISO 9660 + Joliet + UDF 1.02)", systemImage: "memorychip.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if activeSpec.id == "data-udf-modern" {
                            Label("UDF 2.50: Files of Any Size (No ISO 9660 for Old Systems)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if isAppleOnly {
                            Label("HFS+ for Macs, beside ISO 9660 + Joliet + UDF", systemImage: "apple.logo")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isClassicHFS {
                            Label("Classic HFS in a Partition Map: Resource Forks, Types & Creators Kept", systemImage: "desktopcomputer")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isPhotoCD {
                            Label("Kodak Beige Book CD-ROM XA (Multi-Resolution .PCD Image Pac)", systemImage: "camera.aperture")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isRetro83 {
                            Label("ISO 9660 Level 1: 8.3 Uppercase Names for DOS / Win 3.1", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else {
                            Label("Every OS: HFS+ • ISO 9660 + Joliet • UDF", systemImage: "globe")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Button {
                            showHybridLBAMapPopover.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip.fill")
                                Text(KroutonL10n.tr("LBA Sector Map"))
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.activeAccent.opacity(0.16))
                            .foregroundStyle(store.activeAccent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHybridLBAMapPopover, arrowEdge: .bottom) {
                            KroutonHybridLBAMapPopoverView(store: store, activeSpec: activeSpec)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .kroutonMenuInspectHybridLBA)) { _ in showHybridLBAMapPopover = true }

                        if !isRetro83 {
                            Toggle(KroutonL10n.tr("Customize Finder Layout"), isOn: Bindable(store).enableCustomFinderLayoutTab)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .onChange(of: store.enableCustomFinderLayoutTab) { _, enabled in
                                    activeDataWorkspaceTab = enabled ? 1 : 0
                                }
                        }
                    }

                    // 2. Narrow Stacked Fallback (Zero Vertical Word-Towers & Zero Clipping!)
                }
        }
    }
    @ViewBuilder
    var dataDeckBottomOptionsSection: some View {
        let isAppleOnly = (activeSpec.id == "data-apple-apfs")
        let isRetro83 = (activeSpec.id == "data-retro-iso")
        let isClassicHFS = (activeSpec.id == "macos9-hfs")
        let isPhotoCD = (activeSpec.id == "photo-cd")
        VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "opticaldisc")
                                .foregroundStyle(store.activeAccent)
                                .accessibilityHidden(true)
                            Text(KroutonL10n.tr("Disc Title:"))
                                .font(.caption.bold())
                                .lineLimit(1)
                            TextField("Volume Title", text: Bindable(store).discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel(KroutonL10n.tr("Disc Volume Title"))
                            Button {
                                showHybridLBAMapPopover.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "memorychip.fill")
                                    Text("LBA Map")
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(store.activeAccent.opacity(0.16))
                                .foregroundStyle(store.activeAccent)
                                .clipShape(Capsule())
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Inspect LBA Sector Allocation Map")
                        }

                        HStack(spacing: 8) {
                            if activeSpec.id == "dvd-ram" {
                                Label("Rewritable: ISO + UDF 1.02", systemImage: "memorychip.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if activeSpec.id == "data-udf-modern" {
                                Label("UDF 2.50 (Any File Size)", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if isAppleOnly {
                                Label("HFS+ beside ISO + UDF", systemImage: "apple.logo")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if isClassicHFS {
                                Label("APM + Blessed Classic HFS", systemImage: "desktopcomputer")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if isPhotoCD {
                                Label("Beige Book CD-ROM XA (.PCD)", systemImage: "camera.aperture")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if isRetro83 {
                                Label("ISO Level 1: 8.3 Names", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else {
                                Label("HFS+ • ISO + Joliet • UDF", systemImage: "globe")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if !isRetro83 {
                                Toggle(KroutonL10n.tr("Finder View"), isOn: Bindable(store).enableCustomFinderLayoutTab)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .onChange(of: store.enableCustomFinderLayoutTab) { _, enabled in
                                        activeDataWorkspaceTab = enabled ? 1 : 0
                                    }
                            }
                        }
                    }
                }
}
