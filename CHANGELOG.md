# Changelog

All notable changes to Krouton and Krouton Server. Dates are when the work landed on the development branch.

## [Unreleased]

### Krouton Server (new)
- A Rust server that burns discs for Krouton on another computer: Raspberry Pi (ARMv6 to ARM64), x86 and x86-64 Linux, Proxmox, NAS boxes, Windows 10 and 11 (x64, x86, ARM64) and macOS 12 or later. It burns with `xorriso` on Linux, `hdiutil` on macOS and IMAPI2 on Windows, or simulates.
- KRSP v1: 64-byte framed messages over pinned mutual TLS 1.3, with Ed25519 session proofs, commit-then-reveal pairing confirmed with a six-digit code, and resumable uploads checked against a Merkle manifest.
- Folder jobs: the app can send a folder as a bundle and the server builds the disc itself (ISO 9660 with Joliet and Rock Ridge on Linux; UDF hybrids on macOS and Windows).
- Installers and services for Linux (systemd), macOS (LaunchAgent) and Windows (a startup task running as SYSTEM); `krouton-server check` diagnoses drives, tools, space and keys.

### App
- Burn on a Krouton Server: pair from **Settings › Burners & Network** and add a **Network Server Burner** destination.
- The user manual is rewritten from scratch: eleven chapters covering data discs, audio CDs, burners, Krouton Server, labels, the command line, keyboard shortcuts and troubleshooting, with a clear list of what works today. The app reads it from Markdown in its bundle, and the same files are published at krouton.app/manual.
- The Help menu links to the online manual, **Report a Drive** and **Report a Problem**. The link to a certificate-verification page that never existed is gone.
- The bundle identifier is now `app.krouton`, matching the app's folders, log subsystems and file types. Projects are declared as `app.krouton.project` with the `.krut` extension the app actually saves.
- The Shortcuts action **Open Krouton Mastering Format** defaults to a format that exists (`data-hybrid`).
- Direct drive access prototype: an MMC command layer (INQUIRY, GET CONFIGURATION, READ DISC INFORMATION) in OpticalCore and an IOKit SCSITaskLib transport in DriveKit, read-only for now, as a path to burning without DiscRecording.
- The portable modules (OpticalCore, AudioKit, LabelKit, RescueKit, Persistence, NetworkSpool) build for iPadOS, checked in CI, in preparation for an iPad app.

### Packaging
- `Scripts/bundle-app.sh` builds, signs and zips Krouton.app per architecture and includes the resource bundle (manual, localization, assets), which earlier scripts left out. The old `krouton-spoold` helper is gone, and so is the duplicate `Packaging/build-release-app.sh`.
- One Homebrew cask (`Packaging/Homebrew/Casks/krouton.rb`), per-architecture, pointing at this repository; the formula and man page are corrected.

### Websites
- krouton.app: the project site, Krouton Server guide, drive reports, privacy page, security.txt and the manual.
- archive.krouton.app: an open catalogue of optical-disc standards, drivers, tools and longevity research, with mirrored copies of what may be redistributed.

### Verification
- Suite 27: client wire format and folder bundles. Suite 29: KRSP golden vectors shared with Rust. Suite 30: burn-set scheduler with scripted drives. Suite 31: portable core. Suite 32: MMC command layer against a scripted drive.
- `Scripts/build-manual.py --check` in CI keeps the website's manual in step with the app's and fails if a menu shortcut is missing from the shortcuts chapter.

## [1.0.1] - 2026-11-17
- Updated macOS app icon suite (`Color`, `Light`, `Dark`, `Transparent`/`Tinted`/`Clear`) in `Resources/Assets.xcassets` and compiled `Assets.car`.
- Refactored `KroutonAppDelegate.applyDynamicDockIcon` to delegate `"default"` icon appearance directly to macOS `Assets.car` (`NSApplication.shared.applicationIconImage = nil`) for native System Settings switching.
- Fixed monochrome icon tinting (`tintMonochromeIcon`) to use `.sourceAtop` compositing so alpha transparency is preserved on unplated icons.
- Added multi-agent handoff tracking (`CLAUDE.md`, `AI_HANDOFF.md`, `ai-sync.sh`, and `.git/hooks/post-commit`).

## [1.0.0] - 2026-11-16
- Added unified Disc Size header selector (650 MB CD-R to 128 GB BDXL) with live multi-disc spanning.
- Added adaptive macOS Dock icon suite (Default, Dark, Clear Glass, Tinted) with monochrome reliefs.
- Added IOKit sleep/App-Nap prevention during active burns, live Dock progress badge, and quit guard.
- Added Apple Shortcuts (AppIntents) and dual-mode headless CLI (krouton).
- Completed HIG 9pt typography floor, VoiceOver accessibility labels, and 10-language localization.
