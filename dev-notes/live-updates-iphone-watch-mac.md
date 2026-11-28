# Live updates: menu bar today, Mac Live Activities next, iPhone and Apple Watch later

Written 2026-11-28. Status: the menu bar item ships (Settings › Notifications › Show progress in the menu bar). Everything else here is a plan, parked until the owner picks it up. Entry 16 in `open-questions.md` points here.

## What a person should see

A burn, copy, rescue, AVCHD build or Depot download in progress, without Krouton's window in front:

| Surface | What it shows | Status |
| --- | --- | --- |
| Dock icon | percentage badge while a burn runs | shipped (`KroutonAppKitBridge.bindBurnTelemetryAndPowerGuard`) |
| Menu bar item | disc + slowest task's percentage; click for each task, progress bar, detail, Open Krouton | shipped (`KroutonLiveStatus`, `KroutonMenuBarStatusView`) |
| Notifications | banner and a synth sound per event (start, done, failed, insert next blank, Depot) | shipped |
| Mac Live Activity | the menu bar oval / Dynamic Island of the touchscreen MacBook Pro, system-drawn | plan A below |
| iPhone Lock Screen + Dynamic Island | the same burn, on the phone | plan B |
| Apple Watch Smart Stack | the iPhone Live Activity, mirrored | plan B (comes with it) |

## Shared model

Every surface reads one value type, so the work happens once:

```swift
struct KroutonBurnActivity: Codable, Hashable, Sendable {   // ActivityKit's ContentState
    var phase: String          // "Writing", "Verifying", "Insert the next blank"
    var fraction: Double?      // nil while unknown
    var expectedEnd: Date?     // lets the UI count down between updates
    var drive: String
    var disc: Int; var discs: Int   // copy or disc-set position
    var outcome: Outcome?      // .done, .failed(String), set once at the end
}
// Attributes (fixed for the activity): volume title, destination kind, started-at.
```

`KroutonLiveStatus.items` already gathers this from `KroutonOpticalDriveBank` (`isExecutingQueue`, `activeJobPhase`, `activeJobProgress`, `activeJobDetail`), `store.rescue`, `store.avchd` and `store.depotDownloadProgress`. It moves to OpticalCore (portable, iOS-buildable) when plan A or B starts.

Send updates on phase changes and every 5 percentage points, not on every progress tick. Between updates the UI uses `expectedEnd` (`ProgressView(timerInterval:)`, `Text(timerInterval:)`) so it keeps moving.

## Plan A: native Mac Live Activities (macOS 27.3)

- **What's new:** macOS 27.3 (developer beta 1 on 2026-11-03; release expected December) lets third-party Mac apps start Live Activities with ActivityKit. They show as an oval at the left of the menu bar icons, and in the Dynamic Island on the touchscreen MacBook Pro. macOS 26 only mirrored an iPhone's activities.
- **What it needs:**
  - A **Widget extension** target holding the `ActivityConfiguration` (lock-screen-style and compact views).
  - `NSSupportsLiveActivities` in the app's Info.plist.
  - The app calls `Activity<KroutonBurnAttributes>.request(...)`, then `update`/`end`. Everything runs on the same Mac, so no push server is needed.
- **The blocker:** SwiftPM can't build an app extension. Krouton's app is an SPM executable bundled by `Scripts/bundle-app.sh`. The way in is an Xcode project for the app host (`XcodeHost/`), using **Xcode 27.2's JSON project format (`.xcproj`)**, which is meant to be merge-friendly and editable by agents. The SPM libraries stay as they are; the project only adds the app target and the widget extension.
- **Gate it:** `if #available(macOS 27.3, *)`. The menu bar item stays for macOS 14–27.2, and as the "Always" option.
- **Check before starting:** the macOS 27.3 SDK ships in an Xcode 27.3 beta, not 27.2. Confirm that `ActivityKit` imports for macOS in it. Also confirm whether a Developer ID (non-App Store) app may use Live Activities; that's expected but unverified.
- **Effort:** about 1–2 days once the SDK is out: the project file, the extension, two views, and wiring `KroutonLiveStatus` to `Activity`.

## Plan B: iPhone and Apple Watch

Since iOS 18 and watchOS 11, an iPhone app's Live Activity appears in the Watch's Smart Stack automatically, even without a Watch app. So one iPhone app with a Live Activity covers both. The Watch shows the Dynamic Island compact views, or custom ones via `.supplementalActivityFamilies([.small])`.

The hard part is getting updates from the Mac to the phone. ActivityKit updates come either from the iPhone app itself or as APNs pushes (`apns-push-type: liveactivity`) from a server that holds the activity's push token.

| Route | How | Good for | Cost |
| --- | --- | --- | --- |
| **B1. iCloud (CloudKit)** | The Mac writes a `BurnStatus` record to the user's private database. A CloudKit subscription wakes the iPhone app, which updates or starts the activity locally. | start, done, failed, "insert a blank"; `expectedEnd` animates in between | No server. Background wake-ups are rationed, so updates aren't per-percent. Needs the iCloud container in both apps. |
| **B2. Relay + APNs** | The Mac posts signed status to a small relay (e.g. a Cloudflare Worker) holding the APNs auth key. The relay pushes `liveactivity` updates to the tokens the phone registered, including push-to-start. | true live progress; the phone app needn't run | A service to run and an APNs key to guard. Pairing a phone to a Mac needs its own small protocol, which could reuse `SpoolPairing`'s idea. |
| **B3. Local network** | The iPhone app talks to the Mac over Bonjour (`Network.framework`, as Krouton Server does). | real time while the phone app is open | Nothing once the phone locks. Useful only as a supplement. |

**Recommended order:** B1 first, with the shared model and countdown views. Add B2 only if people want percent-by-percent updates on the phone.

**What it needs:**
- An iOS app target and its Widget extension, using the same `.xcproj` as plan A. The portable libraries already build for iOS (CI's `ipados-portable-core` job).
- The paid developer account (team D3BJL3F92P).
- TestFlight / App Store for the phone app.
- A privacy note: the status sent holds only the volume title, drive name and progress.

**Effort:**
- B1: about 1 week. That covers the iOS shell app, the activity UI, CloudKit records and subscriptions, and settings to pair and turn it off.
- B2: plus about 1 week for the relay, push tokens and key handling.

## Decisions for the owner

1. Move the app host to an Xcode `.xcproj` (needed for A and B)? It changes `bundle-app.sh` and CI's packaging step.
2. Plan A as soon as the macOS 27.3 SDK is out?
3. For plan B, the iCloud route (B1) or a relay (B2)?

## Sources

- macOS 27.3 Live Activities for third-party Mac apps: MacRumors, 2026-11-04 (`macrumors.com/2026/11/04/macos-27-3-live-activities-in-menu-bar/`); ithinkdiff, "macOS Golden Gate 27.3 Beta Adds Live Activities to Mac Menu Bar".
- Apple DTS on Mac live status before 27.3 (menu bar extras): Developer Forums thread 834361.
- Watch Smart Stack: WWDC24 "Bring your Live Activity to Apple Watch" (10068) and "Design Live Activities for Apple Watch" (10098).
- ActivityKit push: "Starting and updating Live Activities with ActivityKit push notifications" (developer.apple.com/documentation/activitykit).
- `.xcproj`: Xcode 27.2 release notes, Project Format.
