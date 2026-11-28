# Investigation: can `Shell/` go 100% SwiftUI?

**Status:** open. Decided 2026-11-26: keep the one AppKit file for now, and check again with each new macOS SDK.
**For:** any AI agent or person working on Krouton. Read this before adding to, or removing from, `Shell/App/KroutonAppKitBridge.swift`.

## Where things stand

The goal is SwiftUI only in `Sources/KroutonApp/Features/` and `Sources/KroutonApp/Shell/`. Suite 2 of `krouton-verify` enforces it. It bans `import AppKit`, `NSApplication.shared`, `NSWorkspace`, `NSPasteboard` and other AppKit names, and it also bans looking AppKit up at runtime (`NSClassFromString`).

There is one exception: `Shell/App/KroutonAppKitBridge.swift`. It holds the app delegate and a few helpers, the things SwiftUI on macOS had no API for when the rule was written. Everything else calls them through `KroutonOSDesktopBridge`.

We kept the exception rather than drop the features, because some of them protect the user's discs. The aim is still to empty that file. This note lists what's in it, what SwiftUI offers today, and what to check.

## What's in the bridge, and what SwiftUI offers

| Feature in the bridge | AppKit used | SwiftUI today (checked against the macOS 27 SDK) | To investigate |
|---|---|---|---|
| **Block Quit while a disc is burning.** Quitting mid-burn ruins the disc. | `NSApplicationDelegate.applicationShouldTerminate` returns `.terminateCancel` while a burn runs. | No app-level equivalent. SwiftUI's `dialogPreventsAppTermination(_:)` (and its sheet counterpart) stops Quit only while a dialog or sheet is shown. Burns run inline in the window, not in a sheet. | Would a burn-progress sheet that blocks termination be acceptable UX? Does each new SDK add an app-level termination hook? |
| **Dock badge** showing burn % or "BURN". | `NSApplication.shared.dockTile.badgeLabel` | None in SwiftUI. The notifications framework's `UNUserNotificationCenter.setBadgeCount` isn't AppKit, but it shows numbers only and needs notification permission. | Is a number-only badge acceptable? Check whether it works for a Mac app without notifications enabled. |
| **Tinted / dark / clear Dock icon styles** | `NSApplication.shared.applicationIconImage`, `NSImage`, `NSColor` | None. Default-style icons already come from the asset catalog with no code. | Could the custom styles be dropped in favour of macOS's own icon appearance settings? |
| **Copy buttons** (14 call sites) | `NSPasteboard.general` | `copyable(_:)` and `onCopyCommand(perform:)` respond to the Copy command (⌘C) on a selection, not to a button tap. | Could each copy button become a selectable value with ⌘C or a context-menu Copy? That's a UX change, and it needs agreement first. |
| **Select files in Finder** (Reveal in Finder) | `NSWorkspace.activateFileViewerSelecting` | `openURL` opens a folder but can't select a file in it. | Is opening the containing folder good enough? |
| **Bring the app forward** after opening a window | `NSApplication.shared.activate(ignoringOtherApps:)` | None found. | Check whether `openWindow` brings the app forward on its own in current macOS. If it does, these calls can go. |
| **Regular activation policy** when run with `swift run` (no app bundle) | `NSApplication.shared.setActivationPolicy(.regular)` | None. A bundled .app doesn't need this. | Could it be limited to debug builds, or dropped if no one uses `swift run` for testing? |
| **Open files Finder hands to the app** (images, cue sheets) | `application(_:open:)` | `onOpenURL` and `handlesExternalEvents` exist for scenes. | **Likely movable now.** Test that `onOpenURL` on the main `Window` receives file URLs opened from Finder, then delete the delegate method. |
| **Reopen the main window from the Dock** | `applicationShouldHandleReopen` | `Window` scenes may handle reopen themselves. | **Likely movable.** Test clicking the Dock icon with no window open, without the delegate method. |
| **Dock icon follows light/dark appearance changes** | key-value observing `NSApp.effectiveAppearance`, plus a distributed notification | `@Environment(\.colorScheme)` in a view. | Goes away with the custom icon styles, or could be driven from a view's environment. |

## Sources checked (2026-11-26)

- WWDC26 "What's new in SwiftUI" (session 269) and Apple's WWDC26 SwiftUI guide. Nothing about the Dock, termination, Finder or activation.
- WWDC26 "Modernize your AppKit app" (session 289). Its "Graceful app termination" chapter adds `NSWindow.preventsApplicationTerminationWhenModal`, which is AppKit, and advises apps to block Quit only when they genuinely need to. A disc mid-burn qualifies.
- SwiftUI documentation for `copyable(_:)` and `onCopyCommand(perform:)`: both respond to the Copy command.

## How to work on this

1. **Check one feature at a time.** For each new macOS SDK, check the SwiftUI release notes and that year's "What's new in SwiftUI" for each row above.
2. **Move what SwiftUI can do.** When SwiftUI covers a row without losing behaviour, move it out of `KroutonAppKitBridge.swift`, delete the AppKit code, and update the table here. The quit protection must never be lost silently.
3. **Ask before changing behaviour.** If going SwiftUI-only means changing behaviour (copy buttons becoming ⌘C, number-only badges, opening the folder instead of selecting the file), propose it to the project owner first.
4. **Bridge emptied:** delete the file and remove its exception from Suite 2 (`VerifyHarness+ArchitectureSuites.swift`) and from `CLAUDE.md`.
5. **Don't grow the bridge** unless SwiftUI genuinely can't do the job, and never get around the gate with runtime lookups.
