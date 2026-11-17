import AudioKit
import ImageKit
import OpticalCore
import SwiftUI
import VideoKit

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
                            Text("PAR2: \(Int(mdiscPar2RedundancyPct))%")
                                .font(.caption.bold())
                                .foregroundStyle(store.activeAccent)
                            Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                                .frame(width: 130)
                            Text(KroutonL10n.tr("• Reed-Solomon .par2 + SHA-256"))
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
                                Text("PAR2: \(Int(mdiscPar2RedundancyPct))%")
                                    .font(.caption.bold())
                                    .foregroundStyle(store.activeAccent)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            HStack(spacing: 8) {
                                Slider(value: $mdiscPar2RedundancyPct, in: 5...30, step: 5)
                                    .frame(maxWidth: 135)
                                    .accessibilityLabel("M-DISC PAR2 Parity Percentage")
                                    .accessibilityValue("\(Int(mdiscPar2RedundancyPct)) percent")
                                Text(KroutonL10n.tr("Reed-Solomon .par2 + SHA-256"))
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
                            TextField("Volume Title", text: $store.discVolumeTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 135)
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        if activeSpec.id == "dvd-ram" {
                            Label("Zoned CLV Defect Management (UDF 1.50 / 2.01 Hardware Verified)", systemImage: "memorychip.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if activeSpec.id == "data-udf-modern" {
                            Label("Pure UDF 2.60 (Files >4 GiB up to 128 GB)", systemImage: "checkmark.seal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else if isAppleOnly {
                            Toggle(KroutonL10n.tr("Preserve macOS Extended Attributes (xattr) & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else if isClassicHFS {
                            Label("Apple Partition Map (APM) + Blessed Classic HFS (System 7 / Mac OS 9)", systemImage: "desktopcomputer")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isPhotoCD {
                            Label("Kodak Beige Book CD-ROM XA (Multi-Resolution .PCD Image Pac)", systemImage: "camera.aperture")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if isRetro83 {
                            Toggle(KroutonL10n.tr("Enforce Strict 8.3 Uppercase Filenames (DOS / Win95 / System 7)"), isOn: $enforce8Dot3RetroCompatibility)
                                .toggleStyle(.checkbox)
                                .font(.caption.bold())
                                .lineLimit(1)
                        } else {
                            Label("4-Way Universal Bridge (macOS HFS+ • Windows Joliet/UDF • Linux Rock Ridge)", systemImage: "globe")
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
                            Toggle(KroutonL10n.tr("Customize Finder Layout"), isOn: $store.enableCustomFinderLayoutTab)
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
                            TextField("Volume Title", text: $store.discVolumeTitle)
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
                                Label("UDF 2.01 Zoned Defect Mgmt", systemImage: "memorychip.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if activeSpec.id == "data-udf-modern" {
                                Label("Pure UDF 2.60 (>4 GiB Files)", systemImage: "checkmark.seal.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .lineLimit(1)
                            } else if isAppleOnly {
                                Toggle(KroutonL10n.tr("Preserve macOS xattr & Resource Forks"), isOn: $preserveMacExtendedAttributes)
                                    .toggleStyle(.checkbox)
                                    .font(.caption.bold())
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
                                Toggle(KroutonL10n.tr("Enforce 8.3 Uppercase Filenames"), isOn: $enforce8Dot3RetroCompatibility)
                                    .toggleStyle(.checkbox)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                            } else {
                                Label("4-Way: HFS+ • UDF • Rock Ridge", systemImage: "globe")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if !isRetro83 {
                                Toggle(KroutonL10n.tr("Finder View"), isOn: $store.enableCustomFinderLayoutTab)
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
