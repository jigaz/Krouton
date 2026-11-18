import AudioKit
import DriveKit
import Foundation
import LabelKit
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - KroutonCentralWorkspaceCapacityBarView

struct KroutonCentralWorkspaceCapacityBarView: View {
    @ObservedObject var store: KroutonStateStore
    let activeDiscCapacityBytes: Int64
    let primarySelectedDrive: KroutonOpticalDriveInfo?

    private var capacityTelemetry: (headerLabel: String, compactLabel: String, usedBytes: Int64, totalBytes: Int64, sectorsText: String) {
        // 1. Rip Audio CD / Extract Video Disc -> Local SSD Extraction Target
        if store.selectedCategory == .copy {
            let ssdFree = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64) ?? 64_000_000_000
            if store.selectedCopyTaskID == .ripAudioCD {
                let cd = KroutonRealCDExtractor.scanMountedAudioCD()
                let pcmBytes = cd?.totalPCMBytes ?? 0
                let trkCount = cd?.tracks.count ?? 0
                return ("EXTRACTION TARGET (LOCAL SSD)", "SSD Target", pcmBytes, max(1, ssdFree), "\(trkCount) PCM Tracks")
            } else if store.selectedCopyTaskID == .extractVideoDisc {
                return ("EXTRACTION TARGET (LOCAL SSD)", "SSD Target", store.totalStagedBytes, max(1, ssdFree), "\(store.stagedFiles.count) Items")
            } else {
                let used = store.totalStagedBytes
                let total: Int64 = 4_700_372_992
                return ("TARGET DISC SPACE (DVD-5 4.7 GB)", "DVD-5", used, total, "\(used / 2048) LBA")
            }
        }

        // 2. Disc Image Depot -> Selected Hero ISO Size vs Recommended Optical Medium
        if store.selectedCategory == .depot {
            let hero = store.depotItems.first(where: { $0.id == store.selectedDepotHeroItemID }) ?? store.depotItems[0]
            let imgBytes = store.parseSizeDisplayToBytes(hero.sizeDisplay)
            let isMiniDVD = hero.sizeDisplay.contains("80mm")
            let isCD = imgBytes <= 734_003_200 && !isMiniDVD
            let targetBytes: Int64 = isCD ? 700_000_000 : (isMiniDVD ? 1_459_978_240 : 4_700_372_992)
            let mediumName = isCD ? "CD-R 700 MB" : (isMiniDVD ? "Mini-DVD 1.46 GB" : "DVD-5 4.7 GB")
            let compactName = isCD ? "CD-R" : (isMiniDVD ? "80mm DVD" : "DVD-5")
            let lba = max(1, imgBytes / 2048)
            return ("DISC SPACE (\(mediumName))", compactName, imgBytes, targetBytes, "\(lba) LBA")
        }

        // 3. Burn Station -> Use physical drive mediaType ONLY when a writable blank disc (freeBytes > 0) is loaded
        let usedB = store.totalStagedBytes
        let totalB = max(1, activeDiscCapacityBytes)
        if let drive = primarySelectedDrive, drive.isMediaPresent, drive.freeBytes > 0 {
            return ("DISC SPACE (\(drive.mediaType))", drive.mediaType, usedB, totalB, "\(store.totalStagedSectorsLBA) LBA")
        }

        let spec = store.activeFormatSpec()
        if KroutonSpanningDiscMedium.supportsTargetDiscSizeSelection(forFormatID: spec.id) {
            let medium = store.resolvedDataDiscMedium(forFormatID: spec.id)
            if spec.workspaceKind == .redBookAudio {
                let plan = store.audioController.project.discPlan()
                let discCount = max(1, plan.discs.count)
                let perDiscCap = max(1, medium.maxRedBookFrames * 2352)
                let totalCap = perDiscCap * Int64(discCount)
                let usedAudioBytes = plan.discs.reduce(Int64(0)) { $0 + ($1.usedFrames * 2352) }
                let suffix = discCount > 1 ? "\(discCount) Discs • \(plan.discs.reduce(0) { $0 + $1.usedFrames }) Frames" : "\(store.totalStagedSectorsLBA) LBA"
                return ("DISC SPACE (\(medium.rawValue))", medium.rawValue, max(usedB, usedAudioBytes), totalCap, suffix)
            } else {
                let plan = store.dataDiscPlan(forFormatID: spec.id)
                let discCount = max(1, plan.discs.count)
                let perDiscCap = max(1, medium.maxPayloadBytes)
                let totalCap = perDiscCap * Int64(discCount)
                let suffix = discCount > 1 ? "\(discCount) Discs • \(store.totalStagedSectorsLBA) LBA" : "\(store.totalStagedSectorsLBA) LBA"
                return ("DISC SPACE (\(medium.rawValue))", medium.rawValue, usedB, totalCap, suffix)
            }
        }
        let gb = spec.capacityGB
        let targetMedium: (full: String, short: String) = {
            if gb <= 0.75 { return ("CD-R (700 MB)", "CD-R") }
            if gb <= 1.50 { return ("Mini-DVD (1.46 GB)", "80mm DVD") }
            if gb <= 4.75 { return ("DVD-5 (4.7 GB)", "DVD-5") }
            if gb <= 8.60 { return ("DVD-9 DL (8.5 GB)", "DVD-9") }
            if gb <= 25.5 { return ("BD-R SL (25 GB)", "BD-25") }
            if gb <= 50.5 { return ("BD-R DL (50 GB)", "BD-50") }
            return ("BDXL UHD (100 GB)", "BDXL")
        }()
        return ("DISC SPACE (\(targetMedium.full))", targetMedium.short, usedB, totalB, "\(store.totalStagedSectorsLBA) LBA")
    }

    var body: some View {
        let info = capacityTelemetry
        let usedB = info.usedBytes
        let totalB = max(1, info.totalBytes)
        let freeB = max(0, totalB - usedB)
        let ratio = min(1.0, Double(usedB) / Double(totalB))
        let isOverburn = usedB > totalB

        return VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                // 1. Wide Workspace Layout
                HStack(spacing: 6) {
                    Label(info.headerLabel, systemImage: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("Used: \(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) (\(info.sectorsText))")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text("Free: \(ByteCountFormatter.string(fromByteCount: freeB, countStyle: .file))")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("•").foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(KroutonDesign.Typography.telemetryMono)
                        .contentTransition(.numericText())
                        .foregroundStyle(isOverburn ? Color.red : store.uiSecondaryAccent)
                        .lineLimit(1)
                }

                // 2. Compact / Narrow Workspace Fallback
                HStack(spacing: 6) {
                    Text("\(info.compactLabel):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(ByteCountFormatter.string(fromByteCount: usedB, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalB, countStyle: .file))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isOverburn ? .red : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%.1f%%", ratio * 100.0))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOverburn ? Color.red : store.uiSecondaryAccent)
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOverburn ? AnyShapeStyle(Color.red) : (store.enableSecondaryAccentUITints ? AnyShapeStyle(LinearGradient(colors: [store.activeAccent, store.activeSecondaryAccent], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(store.activeAccent)))
                        .frame(width: max(4, geo.size.width * ratio))
                    Rectangle()
                        .fill(Color.yellow.opacity(0.65))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * 0.96)
                }
            }
            .frame(height: 7)
        }
        .padding(10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.14) : Color.clear)
        .background(Color.kroutonControlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.32) : Color.clear, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(info.headerLabel)
        .accessibilityValue(String(format: "%.1f percent full", ratio * 100.0))
    }
}
