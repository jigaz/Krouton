import AppIntents
import Foundation

// MARK: - Shortcuts, Siri and Spotlight

/// The app's actions for Shortcuts, Siri and Spotlight. They're registered by the Xcode project's
/// app target (`XcodeHost/App`), whose build extracts their metadata; a `swift run` build compiles
/// them but macOS doesn't list them. They only read status or eject, never start a burn: a burn
/// spends a blank, so it's started in Krouton, where the queue and its checks are on screen.
public struct KroutonAppIntentsPackage: AppIntentsPackage {}

/// "What is Krouton doing?" Answers with each running task and its progress.
public struct KroutonStatusIntent: AppIntent {
    public static let title = LocalizedStringResource("Get Krouton's Status")
    public static let description = IntentDescription("Says what Krouton is burning, copying, rescuing or downloading, and how far along it is.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let manager = KroutonWindowManager.shared
        let items = KroutonLiveStatus.items(store: manager.store, driveManager: manager.driveManager)
        let text: String
        if items.isEmpty {
            text = KroutonL10n.tr("Krouton isn't burning, copying or downloading anything.")
        } else {
            text = items.map { item in
                item.fraction.map { "\(item.title): \(Int(($0 * 100).rounded()))%" } ?? item.title
            }.joined(separator: "; ")
        }
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

/// Ejects the disc from the selected drive, or the first one. Refused mid-burn and mid-rescue.
public struct KroutonEjectIntent: AppIntent {
    public static let title = LocalizedStringResource("Eject the Disc")
    public static let description = IntentDescription("Ejects the disc from the drive Krouton has selected. It won't eject while a burn or a disc rescue is running.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let drives = KroutonWindowManager.shared.driveManager
        guard !drives.isExecutingQueue else {
            return .result(dialog: IntentDialog(stringLiteral: KroutonL10n.tr("A burn is running, so the disc stays in. Abort it in Krouton first.")))
        }
        guard !KroutonWindowManager.shared.store.rescue.isRunning else {
            return .result(dialog: IntentDialog(stringLiteral: KroutonL10n.tr("A disc rescue is running, so the disc stays in. Stop it in Krouton first.")))
        }
        guard let drive = drives.selectedDrive ?? drives.availableDrives.first else {
            return .result(dialog: IntentDialog(stringLiteral: KroutonL10n.tr("No optical drive is connected.")))
        }
        drives.ejectDrive(id: drive.id)
        return .result(dialog: IntentDialog(stringLiteral: String(format: KroutonL10n.tr("Ejecting the disc in %@."), drive.displayName)))
    }
}

/// Brings Krouton forward with its window open, for "show the burn".
public struct KroutonOpenIntent: AppIntent {
    public static let title = LocalizedStringResource("Show Krouton")
    public static let description = IntentDescription("Opens Krouton's window.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        KroutonOSDesktopBridge.bringKroutonForward()
        return .result()
    }
}
