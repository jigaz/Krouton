import Foundation
import Observation

// MARK: - Projects in iCloud Drive

/// Krouton's folder in iCloud Drive (`iCloud.app.krouton`, shown as "Krouton" in Finder), where
/// Open Project and Save Project start when you turn it on in Settings › General. Projects keep
/// pointing at their source files where they are; only the .krut file is in iCloud, so a project
/// opened on another Mac shows files that aren't there as missing, as it would from a USB stick.
///
/// Needs the iCloud Documents entitlement and a provisioning profile that grants the container
/// (see dev-notes/icloud.md). Without them the folder is nil and the dialogs start where macOS
/// last left them.
@MainActor
@Observable
final class KroutonCloudDocuments {
    static let shared = KroutonCloudDocuments()
    static let containerID = "iCloud.app.krouton"

    /// `Documents` inside the container, once it has been looked up and exists.
    private(set) var projectsFolder: URL?
    private(set) var hasLookedUp = false

    var isOn: Bool {
        get { access(keyPath: \.isOn); return KroutonPreferences.bool(for: .projectsInICloudDrive) }
        set { withMutation(keyPath: \.isOn) { KroutonPreferences.set(newValue, for: .projectsInICloudDrive) } }
    }

    /// Where the project dialogs should start, or nil to leave them alone.
    var dialogFolder: URL? { isOn ? projectsFolder : nil }

    private init() {}

    /// The container lookup can block on the network the first time, so it runs off the main actor.
    func lookUp() {
        guard !hasLookedUp else { return }
        let id = Self.containerID
        Task {
            let folder = await Task.detached(priority: .utility) { () -> URL? in
                guard let container = FileManager.default.url(forUbiquityContainerIdentifier: id) else { return nil }
                let documents = container.appendingPathComponent("Documents", isDirectory: true)
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                return documents
            }.value
            projectsFolder = folder
            hasLookedUp = true
        }
    }
}
