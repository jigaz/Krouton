import Foundation
import OpticalCore
import RescueKit
import SwiftUI

// MARK: - CopyAndRipWorkspaces — RescueUX

extension KroutonCopyAndRipWorkspaceView {
    /// Copies a damaged data disc to an image, the way GNU ddrescue does, and shows the disc's map.
    var rescueWorkspaceDeck: some View {
        let rescue = store.rescue
        return KroutonMasteringDeckCard(store: store) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lifepreserver.fill").foregroundStyle(store.activeAccent)
                    Text("RESCUE A DAMAGED DISC")
                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                }
                Text("Krouton copies everything that reads easily first, then goes back to the damaged areas one sector at a time. Sectors that never read are saved as zeros and listed in a map file beside the image (GNU ddrescue's format), so you can try again later, in another drive, or with ddrescue itself.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text("Save as").font(.system(size: 11, weight: .semibold))
                    TextField("Rescued Disc", text: Bindable(rescue).imageName)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                    Text(".iso in \(rescue.outputFolder.lastPathComponent)")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    Button("Choose Folder…") {
                        KroutonStageImporterBridge.shared.presentImporter(allowedTypes: [.folder], allowsMultiple: false) { urls in
                            if let folder = urls.first { rescue.outputFolder = folder }
                        }
                    }
                    .controlSize(.small)
                    .disabled(rescue.isRunning)
                }
                Stepper("Retry each bad sector \(rescue.retryPasses) more time\(rescue.retryPasses == 1 ? "" : "s")",
                        value: Bindable(rescue).retryPasses, in: 0...8)
                    .font(.system(size: 11))
                    .disabled(rescue.isRunning)

                rescueMapBar(rescue.map)

                HStack(spacing: 8) {
                    if rescue.isRunning {
                        ProgressView().controlSize(.small)
                        Button(role: .destructive) { rescue.stop() } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                        }
                    } else {
                        Button {
                            rescue.start(driveID: primarySelectedDrive?.id, driveManager: KroutonWindowManager.shared.driveManager)
                        } label: {
                            Label(rescue.canResume ? "Resume Rescue" : "Start Rescue", systemImage: "play.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(primarySelectedDrive == nil)
                    }
                    Text(rescue.status)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Data discs only: CD-ROM, DVD and Blu-ray. For a scratched audio CD, rip it in Rip Audio CD.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }

    /// The disc from centre to edge, as 160 slices coloured by the worst state inside each.
    @ViewBuilder
    func rescueMapBar(_ map: KroutonRescueMap?) -> some View {
        let slices = Self.rescueSlices(map, count: 160)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(slices.enumerated()), id: \.offset) { _, status in
                    Rectangle().fill(Self.rescueColor(status))
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rescue map")
            .accessibilityValue(map.map { "\($0.bytes(.finished) * 100 / max(1, $0.totalBytes)) percent copied" } ?? "Not started")
            HStack(spacing: 12) {
                Label("Copied", systemImage: "square.fill").foregroundStyle(Self.rescueColor(.finished))
                Label("Not tried yet", systemImage: "square.fill").foregroundStyle(Self.rescueColor(.nonTried))
                Label("Damaged, still trying", systemImage: "square.fill").foregroundStyle(Self.rescueColor(.nonScraped))
                Label("Unreadable", systemImage: "square.fill").foregroundStyle(Self.rescueColor(.badSector))
            }
            .font(.system(size: 9.5))
        }
    }

    static func rescueSlices(_ map: KroutonRescueMap?, count: Int) -> [KroutonRescueMap.Status] {
        guard let map, map.totalBytes > 0 else { return Array(repeating: .nonTried, count: count) }
        let severity: [KroutonRescueMap.Status: Int] = [.finished: 0, .nonTried: 1, .nonTrimmed: 2, .nonScraped: 2, .badSector: 3]
        var slices = Array(repeating: KroutonRescueMap.Status.finished, count: count)
        var touched = Array(repeating: false, count: count)
        let width = Double(map.totalBytes) / Double(count)
        for block in map.blocks {
            let first = min(count - 1, Int(Double(block.position) / width))
            let last = min(count - 1, Int(Double(block.end - 1) / width))
            for index in first...last where !touched[index] || severity[block.status, default: 0] > severity[slices[index], default: 0] {
                slices[index] = block.status
                touched[index] = true
            }
        }
        return slices
    }

    static func rescueColor(_ status: KroutonRescueMap.Status) -> Color {
        switch status {
        case .finished: return .green
        case .nonTried: return .gray.opacity(0.35)
        case .nonTrimmed, .nonScraped: return .orange
        case .badSector: return .red
        }
    }
}
