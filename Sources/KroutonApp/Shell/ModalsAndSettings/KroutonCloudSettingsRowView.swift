import SwiftUI

// MARK: - Settings › General: Keep Settings in iCloud

/// Offers to keep these settings in iCloud. When iCloud already holds another Mac's settings,
/// asks which to keep before anything is replaced.
struct KroutonCloudSettingsRowView: View {
    var store: KroutonStateStore
    @State private var isOn = KroutonCloudSettings.isOn
    @State private var isChoosing = false
    @State private var cloudDate: Date?
    var documents = KroutonCloudDocuments.shared

    var body: some View {
        let availability = KroutonCloudSettings.availability
        VStack(alignment: .leading, spacing: 6) {
            Toggle(KroutonL10n.tr("Keep these settings in iCloud, so your other Macs use them too"), isOn: Binding(
                get: { isOn },
                set: { wantsOn in wantsOn ? turnOn() : turnOff() }
            ))
            .disabled(availability != .available && !isOn)
            Text(explanation(availability))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Toggle(KroutonL10n.tr("Open and save projects in Krouton's iCloud Drive folder"), isOn: Bindable(documents).isOn)
                .disabled(documents.projectsFolder == nil && !documents.isOn)
            Text(documentsExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(KroutonL10n.tr("iCloud already has Krouton settings"), isPresented: $isChoosing, titleVisibility: .visible) {
            Button(KroutonL10n.tr("Use the Settings in iCloud")) { finish(useCloud: true) }
            Button(KroutonL10n.tr("Use This Mac's Settings")) { finish(useCloud: false) }
            Button(KroutonL10n.tr("Cancel"), role: .cancel) {}
        } message: {
            if let cloudDate {
                Text(String(format: KroutonL10n.tr("Another Mac saved them %@. The ones you don't choose are replaced."),
                            cloudDate.formatted(.relative(presentation: .named))))
            }
        }
        .contextMenu {
            Button(KroutonL10n.tr("Keep Settings in iCloud")) { turnOn() }
                .disabled(isOn || availability != .available)
        }
    }

    private func explanation(_ availability: KroutonCloudSettings.Availability) -> String {
        switch availability {
        case .available:
            return KroutonL10n.tr("Appearance, units, notifications and their sounds, the label template, disc label sizes and the menu bar choice. Language, drives, servers and keys stay on each Mac.")
        case .notSigned:
            return KroutonL10n.tr("This copy of Krouton isn't signed for iCloud, so settings stay on this Mac. Release builds are.")
        case .noAccount:
            return KroutonL10n.tr("Sign in to iCloud in System Settings to keep settings there.")
        }
    }

    private var documentsExplanation: String {
        if documents.projectsFolder != nil {
            return KroutonL10n.tr("Open Project and Save Project start in the Krouton folder in iCloud Drive, so your other Macs see the same projects. The files a project burns stay where they are.")
        }
        if !documents.hasLookedUp { return KroutonL10n.tr("Looking for iCloud Drive…") }
        return KroutonL10n.tr("iCloud Drive isn't available to this copy of Krouton: it needs a release build signed for iCloud, and iCloud Drive turned on in System Settings.")
    }

    private func turnOn() {
        cloudDate = KroutonCloudSettings.cloudSavedAt
        if cloudDate != nil {
            isChoosing = true
        } else {
            finish(useCloud: false)
        }
    }

    private func finish(useCloud: Bool) {
        KroutonCloudSettings.turnOn(useCloud: useCloud, store: store)
        isOn = true
    }

    private func turnOff() {
        KroutonCloudSettings.turnOff()
        isOn = false
    }
}
