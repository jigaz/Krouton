# Changelog

All notable changes to Krouton and Krouton Server. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Krouton will use [Semantic Versioning](https://semver.org/) from its first published release. Dates are when the work landed on the development branch. Each line starts with the area it touches.

## [Unreleased]

### Added
- App: **Settings › Storage & Reset** shows what Krouton keeps between launches and clears each kind behind a confirmation: caches, the saved session, burn history, settings, destination queues, paired servers, this Mac's server identity, or all of them. Projects, rips and saved images stay. (#13)
- App: notification sounds come from the Krouton synth, with a voice per event, a popover to shape each sound (pitch, reverse, lo-fi, metallic), and an option to give each drive its own pitch. (#14)
- App: live progress in the menu bar while a burn, rescue, AVCHD build or Depot download runs. Settings › Notifications chooses While Krouton is working, Always or Never. (#15)
- App: **Keep these settings in iCloud** (Settings › General, off by default) syncs appearance, units, notifications, the label template and the menu bar choice between Macs. It needs a build signed for iCloud. (#15)
- App: open and save projects in Krouton's iCloud Drive folder, in builds signed for iCloud. (#18)
- App: Auto-Label tidies raw volume and file names into a title and subtitle with Apple's on-device model on macOS 26 and later. Nothing leaves the Mac; Settings › Labels & Printers turns it off. (#17)
- Xcode project: `XcodeHost/project.yml` (XcodeGen) builds Krouton.app with a desktop widget and App Intents for Shortcuts, Siri and Spotlight (*Get Krouton's Status*, *Eject the Disc*, *Show Krouton*). Release builds from `bundle-app.sh` don't include them yet. (#17)
- Discs: **Leave Disc Open for More Sessions** (Disc menu), for multisession live CDs.
- Discs: **Rescue a Damaged Disc**: ddrescue-style copy, trim, scrape and retry over direct drive reads, with a GNU ddrescue mapfile so a rescue can resume or be finished by ddrescue.
- Video: **Video Disc Extractor** saves DVD titles as MKV (ffmpeg remux, all audio and subtitles) or joined MPEG files.
- Consoles: Krouton identifies Wii, GameCube, PlayStation, Dreamcast, Saturn and Xbox images and says what each console needs to play a burned disc.
- Formats: published JSON Schemas for the set index, `.krut` and the Depot feed at krouton.app/schema (Suite 33).
- App: burn on a Krouton Server. Pair from **Settings › Burners & Network** and add a **Network Server Burner** destination.
- App: direct drive access prototype: an MMC command layer (INQUIRY, GET CONFIGURATION, READ DISC INFORMATION) in OpticalCore and an IOKit SCSITaskLib transport in DriveKit, read-only for now, as a path to burning without DiscRecording.
- App: the portable modules (OpticalCore, AudioKit, LabelKit, RescueKit, Persistence, NetworkSpool) build for iPadOS, checked in CI, in preparation for an iPad app.
- Krouton Server (new): a Rust server that burns discs for Krouton on another computer: Raspberry Pi (ARMv6 to ARM64), x86 and x86-64 Linux, Proxmox, NAS boxes, Windows 10 and 11 (x64, x86, ARM64) and macOS 12 or later. It burns with `xorriso` on Linux, `hdiutil` on macOS and IMAPI2 on Windows, or simulates.
- Krouton Server: KRSP v1, 64-byte framed messages over pinned mutual TLS 1.3, with Ed25519 session proofs, commit-then-reveal pairing confirmed with a six-digit code, and resumable uploads checked against a Merkle manifest.
- Krouton Server: folder jobs. The app can send a folder as a bundle and the server builds the disc itself.
- Krouton Server: its own disc writer, with no outside tool: ISO 9660 + Joliet + UDF 2.01 for data, ISO 9660 + UDF 1.02 with the video files in player order for a `VIDEO_TS` folder, and UDF 2.50 with a mirrored metadata partition for a `BDMV` folder. Linux uses it for every folder (Linux itself can't write UDF 2.50, and xorriso writes no UDF); macOS and Windows use it for DVD-Video and Blu-ray folders and their own tools otherwise. CI mounts its images with the Linux, macOS and Windows drivers and compares every file.
- Krouton Server: installers and services for Linux (systemd), macOS (LaunchAgent) and Windows (a startup task running as SYSTEM); `krouton-server check` diagnoses drives, tools, space and keys.
- Websites: krouton.app (the project site, Krouton Server guide, drive reports, privacy page, security.txt and the manual) and archive.krouton.app (an open catalogue of optical-disc standards, drivers, tools and longevity research, with mirrored copies of what may be redistributed).
- Verification: Suite 27 (client wire format and folder bundles), Suite 29 (KRSP golden vectors shared with Rust), Suite 30 (burn-set scheduler with scripted drives), Suite 31 (portable core), Suite 32 (MMC command layer against a scripted drive).
- Verification: `Scripts/build-manual.py --check` in CI keeps the website's manual in step with the app's and fails if a menu shortcut is missing from the shortcuts chapter.

### Changed
- CI: the macOS jobs build and check with Xcode 27.2 and Swift 6.4 on the `xcode-27` runner image (`Scripts/ci-select-xcode.sh`), with warnings as errors. (#16)
- Package: `KroutonApp` is now a library. `swift run Krouton` starts it through the new `KroutonMain` target, and the Xcode project's app target through `XcodeHost/App`. (#17)
- Packaging: `bundle-app.sh` embeds `Packaging/Krouton.provisionprofile` and signs with the iCloud entitlements only when that file exists; other builds keep the old entitlements, and the app says it isn't signed for iCloud. (#15)
- Depot: lists real, downloadable discs from the feed at depot.krouton.app (checked monthly, SHA-256 verified, unpacked from .zip/.7z on download).
- Video: **DVD-9 shrink** writes real DVD navigation packs (ffmpeg's dvd muxer); still needs checking on players.
- Video: **AVCHD / Blu-ray on DVD**: video files are converted with ffmpeg to Blu-ray H.264 + AC-3, each stream is analyzed for its real times and key frames, and Krouton writes `index.bdmv`, `MovieObject.bdmv`, the playlist (chapters at each clip and every five minutes) and clip files with EP maps, then a UDF 2.50 image (Swift port of Krouton Server's writer, byte-identical via `Vectors/udf-bd-v1.sha256`). CI opens the result with libbluray and seeks through it.
- Manual: rewritten from scratch: eleven chapters covering data discs, audio CDs, burners, Krouton Server, labels, the command line, keyboard shortcuts and troubleshooting, with a clear list of what works today. The app reads it from Markdown in its bundle, and the same files are published at krouton.app/manual.
- App: the Help menu links to the online manual, **Report a Drive** and **Report a Problem**.
- App: the bundle identifier is now `app.krouton`, matching the app's folders, log subsystems and file types. Projects are declared as `app.krouton.project` with the `.krut` extension the app actually saves.
- Packaging: `Scripts/bundle-app.sh` builds, signs and zips Krouton.app per architecture and includes the resource bundle (manual, localization, assets), which earlier scripts left out.
- Packaging: one Homebrew cask (`Packaging/Homebrew/Casks/krouton.rb`), per architecture, pointing at this repository; the formula and man page are corrected.

### Fixed
- App: every notification played the failure buzzer, so a finished burn sounded like a failed one, and notification choices were lost at every launch. (#14)
- Labels: disc label sizes were lost at every quit. They now persist and sync with settings in iCloud; Reset Settings restores the built-in four. (#18)
- Discs: **Burn Disc Image** burned the image as a file on a data disc. A single .iso, .cdr, .dmg, .cue or .toc on the deck is now burned sector for sector; .cdi, .gdi, .wbfs, .rvz and .chd are refused with a reason.
- App: the Shortcuts action **Open Krouton Mastering Format** defaults to a format that exists (`data-hybrid`).

### Removed
- Depot: the made-up catalogue and placeholder images.
- Consoles: the console toggles that did nothing.
- Video: the old AVCHD code, which guessed durations from file sizes and wrote no EP map.
- App: the Help link to a certificate-verification page that never existed.
- Packaging: the old `krouton-spoold` helper and the duplicate `Packaging/build-release-app.sh`.

The versions below were internal version numbers. Neither was published as a release.

## [1.0.1] - 2026-11-17
- Updated macOS app icon suite (`Color`, `Light`, `Dark`, `Transparent`/`Tinted`/`Clear`) in `Resources/Assets.xcassets` and compiled `Assets.car`.
- Refactored `KroutonAppDelegate.applyDynamicDockIcon` to delegate `"default"` icon appearance directly to macOS `Assets.car` (`NSApplication.shared.applicationIconImage = nil`) for native System Settings switching.
- Fixed monochrome icon tinting (`tintMonochromeIcon`) to use `.sourceAtop` compositing so alpha transparency is preserved on unplated icons.
- Added `CLAUDE.md` with build commands and the verify rules for contributors and coding agents.

## [1.0.0] - 2026-11-16
- Added unified Disc Size header selector (650 MB CD-R to 128 GB BDXL) with live multi-disc spanning.
- Added adaptive macOS Dock icon suite (Default, Dark, Clear Glass, Tinted) with monochrome reliefs.
- Added IOKit sleep/App-Nap prevention during active burns, live Dock progress badge, and quit guard.
- Added Apple Shortcuts (AppIntents) and dual-mode headless CLI (krouton).
- Completed HIG 9pt typography floor, VoiceOver accessibility labels, and 10-language localization.
