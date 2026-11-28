import NetworkSpool
import SwiftUI

// MARK: - Settings › Storage & Reset

/// Clears what Krouton keeps between launches, one kind at a time, each behind a confirmation
/// that says what goes and what stays.
struct KroutonStorageAndResetPaneView: View {
    var store: KroutonStateStore
    @State private var usage = KroutonStorageAndReset.Usage()
    @State private var pending: Action?
    @State private var lastDone: String?
    @State private var isWorking = false

    enum Action: String, Identifiable {
        case emptyCaches, forgetSession, clearBurnHistory, resetSettings, resetQueues, forgetServers, resetIdentity, everything
        var id: String { rawValue }

        var title: String {
            switch self {
            case .emptyCaches: return KroutonL10n.tr("Empty Caches")
            case .forgetSession: return KroutonL10n.tr("Forget Saved Session")
            case .clearBurnHistory: return KroutonL10n.tr("Clear Burn History")
            case .resetSettings: return KroutonL10n.tr("Reset Settings to Defaults")
            case .resetQueues: return KroutonL10n.tr("Reset Destination Queues")
            case .forgetServers: return KroutonL10n.tr("Forget All Servers")
            case .resetIdentity: return KroutonL10n.tr("Reset This Mac's Server Identity")
            case .everything: return KroutonL10n.tr("Reset Krouton")
            }
        }

        /// What the confirmation says goes, and what stays.
        var consequence: String {
            switch self {
            case .emptyCaches:
                return KroutonL10n.tr("Downloaded Depot images, the Depot list and leftover work folders are deleted. Projects, rips and images you saved stay. Depot images download again when you need them.")
            case .forgetSession:
                return KroutonL10n.tr("The session Krouton restores at launch is deleted. What's open now stays open.")
            case .clearBurnHistory:
                return KroutonL10n.tr("The record of past burns is deleted, so a burn a crash interrupted before now won't be reported.")
            case .resetSettings:
                return KroutonL10n.tr("Appearance, language, units, notifications, the label template, the format list and the copy and pool choices go back to their defaults. The language follows the system from the next launch. Projects and servers stay.")
            case .resetQueues:
                return KroutonL10n.tr("The destination queue goes back to one disc burner card, and the queues saved for each workspace are cleared.")
            case .forgetServers:
                return KroutonL10n.tr("Every paired Krouton Server is forgotten on this Mac. Pair again to use one; each server keeps its record of this Mac until you unpair it there.")
            case .resetIdentity:
                return KroutonL10n.tr("This Mac's server keys are deleted from the keychain and every server is forgotten. Each server has to be paired again.")
            case .everything:
                return KroutonL10n.tr("Caches, the saved session, burn history, settings, destination queues and server pairings are all cleared. Projects, rips and images you saved stay, and so does what's open now.")
            }
        }

        /// Settings and identities can't be brought back; caches download again.
        var isDestructive: Bool { self != .emptyCaches }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            card(KroutonL10n.tr("Storage")) {
                row(.emptyCaches, detail: KroutonL10n.tr("Downloaded Depot images, the Depot list, the staging cache, and work folders a crash left behind."),
                    size: usage.caches + usage.leftovers)
                Divider()
                row(.forgetSession, detail: KroutonL10n.tr("What Krouton restores when it opens (General › Remember)."), size: usage.session)
                Divider()
                row(.clearBurnHistory, detail: KroutonL10n.tr("Lets Krouton tell you about a burn a crash interrupted."), size: usage.burnHistory)
            }
            card(KroutonL10n.tr("Settings")) {
                row(.resetSettings, detail: KroutonL10n.tr("Every choice in these Settings, back to a first launch."))
                Divider()
                row(.resetQueues, detail: KroutonL10n.tr("The destination cards for each workspace."))
            }
            card(KroutonL10n.tr("Krouton Servers")) {
                row(.forgetServers, detail: String(format: KroutonL10n.tr("Paired servers on this Mac: %lld."),
                                                   SpoolRemoteNodeClient.shared.pairedServers.count))
                Divider()
                row(.resetIdentity, detail: KroutonL10n.tr("New keys for this Mac, for when it changes hands."))
            }
            HStack {
                if let lastDone {
                    Label(lastDone, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(Action.everything.title, role: .destructive) { pending = .everything }
                    .disabled(isWorking || KroutonStorageAndReset.isBusy(store))
            }
            if KroutonStorageAndReset.isBusy(store) {
                Text(KroutonL10n.tr("Some of these wait until the burn, copy or download in progress has finished."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { usage = await KroutonStorageAndReset.measure() }
        .confirmationDialog(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { action in
            Button(action.title, role: action.isDestructive ? .destructive : nil) { run(action) }
            Button(KroutonL10n.tr("Cancel"), role: .cancel) {}
        } message: { action in
            Text(action.consequence)
        }
    }

    // MARK: - Rows

    private func row(_ action: Action, detail: String, size: Int64? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let size {
                Text(verbatim: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Button(KroutonL10n.tr(action.isDestructive ? "Reset…" : "Empty…")) { pending = action }
                .lineLimit(1)
                .fixedSize()
                .disabled(isWorking || (size == 0) || (action.touchesFiles && KroutonStorageAndReset.isBusy(store)))
        }
        .contextMenu {
            Button(action.title) { pending = action }
        }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(14)
                .background(Color.kroutonControlSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Running

    private func run(_ action: Action) {
        isWorking = true
        Task {
            switch action {
            case .emptyCaches: await KroutonStorageAndReset.emptyCaches()
            case .forgetSession: await KroutonStorageAndReset.forgetSavedSession()
            case .clearBurnHistory: await KroutonStorageAndReset.clearBurnHistory()
            case .resetSettings: KroutonStorageAndReset.resetSettings(store)
            case .resetQueues: KroutonStorageAndReset.resetDestinationQueues(store)
            case .forgetServers: await KroutonStorageAndReset.forgetAllServers()
            case .resetIdentity: await KroutonStorageAndReset.resetServerIdentity()
            case .everything: await KroutonStorageAndReset.resetEverything(store)
            }
            usage = await KroutonStorageAndReset.measure()
            lastDone = String(format: KroutonL10n.tr("Done: %@"), action.title)
            isWorking = false
        }
    }
}

extension KroutonStorageAndResetPaneView.Action {
    /// Actions that delete files something running may be writing.
    var touchesFiles: Bool { [.emptyCaches, .clearBurnHistory, .everything].contains(self) }
}
