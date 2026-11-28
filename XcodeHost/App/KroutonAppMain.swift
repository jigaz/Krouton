import AppIntents
import KroutonApp

// MARK: - The App Target's Entry Point

/// The Xcode project's app target: the same app `swift run Krouton` starts, plus what only an
/// Xcode build provides (the widget extension, App Intents metadata, signing with the app group).
@main
enum KroutonAppMain {
    @MainActor
    static func main() {
        KroutonEntryPoint.main()
    }
}

/// Registers the KroutonApp library's intents with this app.
struct KroutonAppTargetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [KroutonAppIntentsPackage.self] }
}

/// What Siri, Spotlight and the Shortcuts app offer without setup.
struct KroutonAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: KroutonStatusIntent(),
                    phrases: ["How's \(.applicationName) doing", "\(.applicationName) status", "What is \(.applicationName) burning"],
                    shortTitle: "Burn Status", systemImageName: "opticaldisc")
        AppShortcut(intent: KroutonEjectIntent(),
                    phrases: ["Eject the disc with \(.applicationName)", "\(.applicationName) eject"],
                    shortTitle: "Eject Disc", systemImageName: "eject")
        AppShortcut(intent: KroutonOpenIntent(),
                    phrases: ["Show \(.applicationName)"],
                    shortTitle: "Show Krouton", systemImageName: "macwindow")
    }
}
