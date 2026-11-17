import Foundation
import OpticalCore
import SwiftUI

/// The multi-disc set window: choose a disc size, start, then follow each disc and each drive.
struct KroutonBurnSetSheetView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var controller: KroutonBurnSetController = .shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("krouton.pref.burnSetMedium") private var mediumRaw: String = KroutonSpanningDiscMedium.dvd5Single.rawValue
    @State private var confirmAbort = false

    private var medium: KroutonSpanningDiscMedium {
        KroutonSpanningDiscMedium(rawValue: mediumRaw) ?? .dvd5Single
    }

    private var totalStagedBytes: Int64 {
        store.stagedFiles.reduce(0) { $0 + $1.byteSize }
    }

    private var estimatedDiscCount: Int {
        let usable = max(1, medium.maxPayloadBytes - max(8 * 1024 * 1024, medium.maxPayloadBytes / 64))
        return max(1, Int((totalStagedBytes + usable - 1) / usable))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let notice = controller.notice {
                Text(notice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(store.activeAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: KroutonDesign.Radius.card))
            }
            switch controller.phase {
            case .idle:
                setupSection
            case .preparing:
                preparingSection
            case .running, .finished:
                progressSection
            }
            Divider()
            footer
        }
        .padding(18)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 380)
        .task { await controller.loadResumableSet() }
        .interactiveDismissDisabled(controller.isBusy)
        .confirmationDialog(
            "Stop every drive now?",
            isPresented: $confirmAbort,
            titleVisibility: .visible
        ) {
            Button(KroutonL10n.tr("Abort and Spoil Discs in Progress"), role: .destructive) { controller.abortNow() }
            Button(KroutonL10n.tr("Keep Burning"), role: .cancel) {}
        } message: {
            Text("A disc that is being written right now cannot be reused if it is write-once media. To stop without losing a disc, use Stop After Current Discs.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(store.activeAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Multi-Disc Set")
                    .font(.title3.bold())
                Text(controller.phase == .idle ? store.discVolumeTitle : controller.setTitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let found = controller.resumable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unfinished set: \(found.set.title)")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("\(found.remaining.count) of \(found.jobs.count) discs still need burning. Finished discs stay finished.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(KroutonL10n.tr("Resume This Set")) { controller.resumeFoundSet() }
                            .keyboardShortcut(.defaultAction)
                        Button(KroutonL10n.tr("Discard Its Staged Images"), role: .destructive) { controller.discardFoundSet() }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: KroutonDesign.Radius.card))
            }

            Picker(KroutonL10n.tr("Disc type"), selection: $mediumRaw) {
                ForEach(KroutonSpanningDiscMedium.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
            .frame(maxWidth: 380)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.stagedFiles.count) staged item\(store.stagedFiles.count == 1 ? "" : "s"), \(KroutonBurnSetController.byteText(totalStagedBytes))")
                    .font(.system(size: 12, weight: .semibold))
                Text("About \(estimatedDiscCount) disc\(estimatedDiscCount == 1 ? "" : "s"). The exact split is worked out when you start.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Each disc is a self-contained ISO-9660 + Joliet + UDF volume with a checksum manifest and an index of the whole set. Every connected burner is used, and every disc is read back and compared before it counts as done.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preparingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                Text("Planning, copying and building disc images...")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Every file is copied and hashed once. Nothing is written to a disc until all images are ready.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var progressSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !controller.drives.isEmpty {
                    sectionTitle("DRIVES")
                    ForEach(controller.drives) { drive in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(drive.name)
                                .font(.system(size: 12, weight: .bold))
                            Text(drive.message)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !controller.discs.isEmpty {
                    sectionTitle("DISCS")
                    ForEach(controller.discs) { disc in
                        discRow(disc)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 160)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(KroutonDesign.Typography.sectionHeader)
            .foregroundStyle(.secondary)
    }

    private func discRow(_ disc: KroutonBurnSetController.DiscRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol(for: disc.status))
                .foregroundStyle(color(for: disc.status))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Disc \(disc.id)  \(disc.volumeLabel)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(detail(for: disc))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            switch controller.phase {
            case .idle:
                Button(KroutonL10n.tr("Close")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(KroutonL10n.tr("Build Images and Burn")) {
                    controller.start(title: store.discVolumeTitle, entries: store.stagedFiles, discCapacityBytes: medium.maxPayloadBytes)
                }
                .keyboardShortcut(controller.resumable == nil ? .defaultAction : nil)
                .disabled(store.stagedFiles.isEmpty)
            case .preparing:
                Spacer()
            case .running:
                Button(KroutonL10n.tr("Abort Now..."), role: .destructive) { confirmAbort = true }
                Spacer()
                if controller.isStopping {
                    Text("Stopping...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button(KroutonL10n.tr("Stop After Current Discs")) { controller.stopAfterCurrentDiscs() }
                    .disabled(controller.isStopping)
            case .finished:
                Button(KroutonL10n.tr("Done")) {
                    controller.dismissFinishedSet()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                if controller.hasUnfinishedDiscs {
                    Button(KroutonL10n.tr("Burn Remaining Discs")) { controller.burnRemainingDiscs() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    // MARK: - Row appearance

    private func symbol(for status: KroutonBurnSetController.DiscStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .active: return "opticaldisc"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for status: KroutonBurnSetController.DiscStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .active: return store.activeAccent
        case .done: return .green
        case .failed: return .red
        }
    }

    private func detail(for disc: KroutonBurnSetController.DiscRow) -> String {
        let size = KroutonBurnSetController.byteText(disc.imageBytes)
        switch disc.status {
        case .pending: return "\(size). Waiting for a drive."
        case .active(let what): return "\(size). \(what)."
        case .done: return "\(size). Burned and verified."
        case .failed(let why): return "\(size). \(why)"
        }
    }
}
