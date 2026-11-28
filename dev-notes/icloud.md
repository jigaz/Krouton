# iCloud in Krouton

Written 2026-11-28. **Status:** the code is done. It turns on in builds signed with a provisioning profile that grants iCloud. The Settings rows say so when a build isn't.

## What uses iCloud

| What | How | Where in code |
| --- | --- | --- |
| Settings on all your Macs (opt-in) | iCloud key-value store: appearance, units, notifications and their sounds, label template, disc label sizes (`labelPresets`), Auto-Label tidying, menu bar choice | `Shell/Services/KroutonCloudSettings.swift`, Settings › General › iCloud |
| Projects in iCloud Drive (opt-in) | Container `iCloud.app.krouton`, shown as **Krouton** in iCloud Drive. Open and Save Project start there (macOS 15+). | `Shell/Services/KroutonCloudDocuments.swift` |

Deliberately left on each Mac:
- the app's language
- drives and burner cards
- the saved session and burn journal
- caches
- paired Krouton Servers, and the Ed25519/TLS keys (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`)

A project in iCloud refers to its source files where they are. On another Mac they show as missing unless they're in iCloud Drive too.

## One-time setup in the developer account (team D3BJL3F92P)

1. **Identifiers › App IDs › app.krouton:** enable **iCloud** (with CloudKit support off; only key-value storage and iCloud Documents are used) and **App Groups**.
2. **Identifiers › iCloud Containers:** add `iCloud.app.krouton` and assign it to app.krouton's iCloud capability.
3. **Identifiers › App Groups:** none are needed. The group is `D3BJL3F92P.app.krouton.shared`, the team-prefixed form macOS accepts. The widget extension's App ID, `app.krouton.widgets`, needs App Groups only.
4. **Profiles:** create a **Developer ID** provisioning profile for app.krouton. Download it, save it as `Packaging/Krouton.provisionprofile` (it isn't secret), and commit it.

## Building signed

- **Release zip** (`Scripts/bundle-app.sh`): with a Developer ID certificate in the keychain and the profile in `Packaging/`, the script embeds the profile and signs with `XcodeHost/Krouton-iCloud.entitlements` (key-value store, iCloud Documents, app group). Without the profile it signs with `Krouton.entitlements`. macOS won't launch an app that claims iCloud without a profile granting it, which is why the two files are separate.
- **Xcode on Losa** (`XcodeHost/project.yml`): the app target uses `Krouton-Xcode.entitlements` with automatic signing. Choose the team once in Signing & Capabilities. The first signed build registers the capabilities and makes a development profile, so iCloud works in Debug runs on Losa.
- **`swift run Krouton` and CI:** no entitlements. Both iCloud rows are disabled and explain why.

## Checking it

1. On Mac A, turn on **Keep these settings in iCloud** and change the accent colour. On Mac B, turn it on, choose **Use the Settings in iCloud**, and check the colour matches. Change the colour on B; A should follow within a minute while Krouton is open.
2. Add a disc label size on A. It should appear on B.
3. Turn on **Open and save projects in Krouton's iCloud Drive folder**, then save a project. It should be in Finder › iCloud Drive › Krouton, and open from B.
4. Run **Reset Settings** with sync on. The copy in iCloud is cleared. B keeps its settings until they're changed there.
5. Sign out of iCloud. Both rows should say iCloud isn't available, and nothing should break.

## Not done (needs a decision)

- Syncing paired servers. The pairing secret is per device by design; syncing would mean sharing a client identity across Macs.
- CloudKit, for iPhone/Watch status: see `live-updates-iphone-watch-mac.md`, route B1.
