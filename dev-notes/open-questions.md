# Open questions for agents

Questions found while working on Krouton that need an answer: an investigation, a measurement, or a decision by the project owner. Pick one, investigate, and write what you found under its entry (or delete the entry once it's settled and recorded elsewhere).

Each entry says what is known, where to look, how to answer it, and who decides. **Owner decides** means: investigate and propose, but change nothing until the project owner agrees. Gathered 2026-11-26.

Related: `pure-swiftui-shell.md` (the one AppKit file), `removed-formats.md`, `PENDING_INTEGRATION.md` (24 unwired library types, decide by 2027-01-31).

---

## Hardware: what only a real drive can answer

### 1. Does DiscRecording write CD-ROM XA (Mode 2) sectors from our own tracks?
- **Known:** The Dreamcast burn (`DriveKit/KroutonOpticalDriveBank+DiscJugglerBurn.swift`) asks for Mode 2 raw (2,336-byte) and Mode 2 Form 1 blocks through producer tracks. The SDK accepts the settings, but nothing has been burned. Video CD and Photo CD need Mode 2 Form 2 (2,324 bytes), and CD-Extra's data session should be Mode 2 too; today it's Mode 1.
- **Answer by:** Burn a small Mode 2 Form 1 and a Form 2 track to CD-RW, then read the sector headers back, for example with `cdrdao read-cd` or an MMC READ CD.
- **Unblocks:** Video CD, Photo CD (Base resolution) and a Blue Book-correct CD-Extra. **Owner decides** whether to build the CD-ROM XA writer.

### 2. Does a Dreamcast .cdi land at the sector it was mastered for?
- **Known:** `KroutonDiscJugglerImage.audioDataPlan` refuses an image unless its data starts at last audio frame + 6,750 + 4,500 + pregap (11,702 for the usual 302-frame audio track). That assumes the drive writes standard lead-out and lead-in lengths, and that track-at-once writing adds no run-out blocks.
- **Answer by:** Burn one audio/data .cdi, read the TOC back (READ TOC format 2), compare the data track's start with the image's. Then try booting it on a Dreamcast.
- **If it's off:** Pin the write strategy (session-at-once) or adjust the arithmetic in `audioDataPlan`.

### 3. Does CD-Extra's two-session layout burn as one job?
- **Known:** `beginAudioBurn` hands DiscRecording `[audioTracks, [dataTrack]]` with the session-at-once strategy required. Whether DiscRecording accepts both together is untested.
- **Answer by:** Burn to CD-RW. Check that a CD player plays the audio and that macOS mounts the second session's files.

### 4. Classic Mac boot from a Krouton HFS disc
- **Known:** The HFS writer blesses the System Folder and copies the boot blocks. CI checks the image with its own parser and mounts it on Linux. Old Macs also need CD driver partitions in the partition map, which Krouton doesn't write.
- **Answer by:** Boot SheepShaver or a New World Mac (Mac OS 8.5–9.2) from a burned disc or the image. Record which Macs boot and which don't.

### 5. Printable-disc output
- **Known:** The PNG export is the disc diameter plus bleed, at the chosen dpi. It's not yet known how Epson Print CD and Canon IJ Label Print scale an image that's 122 mm, not 120 mm.
- **Answer by:** Print the alignment test and a planet label on a printable disc in each tool. Note the scaling and offsets in the manual's Printing section.

---

## Correctness and honesty

### 6. The archival quality grade can never be shown
- **Known:** `RescueKit/RescueEngine.swift` `evaluateArchivalDiscGrade` grades C1/C2/jitter and prints an "ISO/IEC 10149 & ECMA-267 Compliant" certificate. But every caller (`KroutonAuxModalsAndScopes.swift`, `KroutonMenuCommands.swift`, via a pass-through in LabelKit) passes no measurements, so the result is always "NOT MEASURED". The grading branch is unreachable, and the standards claim was never checked.
- **Answer by:** Find out whether any drive Krouton supports can report C1/C2 errors (vendor commands, as used by QPxTool or Opti Drive Control).
- **Owner decides:** Either implement real scanning for the drives that support it, or remove the grade, its menu item and the certificate text.
- **Also:** Why does LabelKit wrap a RescueKit function? It's the only reason LabelKit depends on RescueKit.

### 7. Do projects saved by earlier versions still open?
- **Known:** Project and session models (`KroutonKrutCoreSpec`, `KroutonEmbeddedLabelSpec`, `KroutonLabelTextElement`, `KroutonPlanetSettings` and others) use Swift's generated `Codable` with default values. Generated decoding ignores defaults: if a later version adds a non-optional field, a project saved before that field existed fails to decode as a whole. `hasDropShadow` on text layers looks like such a later addition.
- **Answer by:** Collect project files saved by older builds (or rebuild them from git history) and decode them in a test. Where it fails, add `init(from:)` with `decodeIfPresent ?? default`, or make new fields optional. Then add a test that keeps an old project file decoding.

### 8. Destination cards that say one thing and do another
*Re-examined 2026-11-26; mostly fixed by PR #5 (`fix/honest-destination-cards`).*
- **Fixed in #5:**
  - Rip cards use a typed `KroutonRipCodec` (FLAC, ALAC, WAV, AIFF), shown and chosen on the card. The "MP3" card that wrote AIFF is gone, and so is the AIFF-into-"Apple Lossless" switch.
  - Rip Audio CD and Extract Video Disc no longer offer a disc-image card: it imaged the burn deck, not the disc, while claiming ".BIN + .CUE" and "Decrypted". A saved one refuses and points to Duplicate Disc. There's no HEVC extract card any more.
  - Label cards save into their own folder (Downloads for new cards); Vector PDF Label writes only the PDF.
  - An unknown kind in a saved project is dropped instead of becoming a disc burner. Cards saved earlier are repaired on restore (`repairingLegacyPresets`).
  - "localhost:7420" is gone; an empty server means the first paired server. *Correction:* the card's picker already showed that server, so card and burn agreed. Only the placeholder text was wrong.
- **Still open:**
  1. Saving an audio CD in the drive as .bin/.cue (raw 2,352-byte reads). Krouton can't yet, so no card offers it.
  2. Letting a queue disc-image card in Copy run the same sector copy as Duplicate Disc (`store.rescue`), instead of refusing.
  3. Choosing the folder on rip and label cards; today it's shown, not editable.
  4. Renaming `KroutonBurnDestinationKind`'s raw values (for example "Video Transcode (H.265 / HEVC)"). They're storage keys, never shown. A rename needs decoding that accepts the old values, and older builds couldn't read new sessions. Do it with #7, or not at all.
  5. `speedOrCodec` is still one free-text field for every kind; typed settings per kind would end this class of bug. That needs tolerant decoding (#7).

### 9. Unused-code report triage (248 findings)
*Re-examined 2026-11-26* from the CI log of main at 0c569bc: 70 unused, 120 assigned but never read, 56 needlessly public, 2 redundant protocols or conformances.
- **The 120 write-only properties** are mostly harmless: fields of hashable cache keys (`LabelGeometry+OpticalPlayground.swift`, 11), file-identity snapshots compared whole (`BurnSetStager`, 6), and result fields. Leave them, or mark them with `// periphery:ignore` once checked. Two are features that compute work nobody uses:
  - **Auto-Label** (`LabelKit/AutoLabelEngine.swift`) harvests artwork, frames it around the hole with Vision, extracts a palette, and builds a tracklist and rim banner. `AutoLabelStoreAdapter` applies only the title and subtitle, yet the summary says "embedded/folder artwork + Vision center-hole framing". Wire the rest in or cut the summary down. **Owner decides.**
  - Head and tail loudness (`AudioAnalysisService`, `headLUFS`/`tailLUFS`) are measured for every track and never read.
- **Of the 70 unused, the ones that matter:**
  - `preserveMenus` in `VideoKit/VideoAuthoringEngine+Shrink.swift`: the shrink always keeps the menus (`preserveMenusAndExtras: true`), so the Settings toggle "otherwise only the main feature is kept" does nothing. Remove the toggle, or make the flag work.
  - Capability bits (`SpoolNodeCapabilities.writesCD/DVD/BD`): the client parses the server's `caps` and never checks or shows them, so a Blu-ray job can go to a CD-only server.
  - The notification service ignores the `progress`, `driveName` and `speedLabel` it is passed.
  - `KroutonDomainIdentity.spoolDefaultPort` is unused while "7420" is written out in three places.
  - Duplicates to fold: two CUE parsers in `DiscImageDepot.swift`, `buildOpticalRescueMap` in RescueKit and a LabelKit wrapper (#6), `BurnPoolSnapshot` and `withdraw(drive:)`.
- **Likely false positives, keep:** `appDelegate` (an adaptor), the App Intents' `description` (read by the system), `burnQueueSubStore` (key paths), `KroutonViewportTier` (see #14).
- **The 56 public ones:** making them internal also shrinks Suite 28's surface. Do it module by module, with `swift build` for iOS in the loop.

### 10. Periphery is archived; choose what CI runs
*Found 2026-11-26.*
- **Known:** The author archived `peripheryapp/periphery` on 2026-08-12 and moved to a closed-source commercial successor, Periphery Pro (prebuilt `periphery-cli`). Homebrew deprecated the formula and disables it on 2027-08-12; until then CI keeps getting the last open-source release, 3.8.0, under the MIT licence. A community fork (`tiny-earth-moon`) has since been renamed **outskirts**. It builds with Xcode 27.1 / Swift 6.4, has fixed false positives, and installs with `brew install tiny-earth-moon/tap/outskirts`. It is run by one account and has no release binaries outside its Apple-silicon bottle.
- **Options:**
  1. Do nothing until 2027-08-12.
  2. Build 3.8.0 from its tag in CI and cache the binary. Stable, but frozen, and it may stop understanding newer index stores.
  3. Switch to outskirts. Same config and CSV format; pin a version and keep the summary script.
  4. Buy Periphery Pro.
  5. Drop the job and rely on Suite 28 plus review.
- **Recommendation:** 3, pinned to a version, falling back to 2 if the fork stalls. The job is a report, not a gate, so a tool change can't break builds. **Owner decides** (licence and trust in a one-account fork).

---

## Architecture and tooling

### 11. A burn coordinator outside the UI store
*Re-examined 2026-11-26.*
- **Known:**
  - **There are already two burn paths.**
    - Multi-disc sets go `KroutonBurnSetController` → `BurnSetScheduler` (an actor in BurnKit) → `DiscRecordingOpticalDrive`. That path freezes the sources, journals each event (`BurnEventJournal`), and claims drives through the arbiter.
    - Everything else goes through about 1,680 lines in seven store extensions (`+BurnInput`, `+BurnSupport`, `+PhysicalBurn`, `+NetworkBurn`, `+DestinationExecution`, `+DestinationQueue`, `+SpannedDestinations`) into `KroutonOpticalDriveBank.beginBurn…` (DriveKit). That path has its own ticket pool (`waitingBurnPool`, `promoteWaitingTicket`, `advancePoolAfterCardBurnCompleted`), while OpticalCore's `BurnClaimLedger` sits mostly unused.
  - The scheduler's `OpticalDrive` protocol only has `write(image:)`, so audio tracks, CD-Extra's two sessions, `.cdi` sector layouts and folder burns can't use it yet.
  - The store code mostly touches `destinationQueue` (70 references), `waitingBurnPool` (24), `discVolumeTitle`, `stagedFiles` and the pool counters. That is a small surface to hand to a coordinator.
  - BurnKit already depends on DriveKit and ImageKit, but not on AudioKit or NetworkSpool.
  - `KroutonOpticalDriveBank+BurnSession.swift` is at 499 of 500 lines. Its "NOTE(status, 2026-11)" says there is no HFS-standard data writer, which is out of date: HFS now arrives as an image.
- **Proposal:** one path, not a third.
  1. Generalize the payload: `enum BurnPayload { image(URL), dataFolder(…), audio(KroutonAudioBurnDisc), sectors(SectorLayout) }`, and `OpticalDrive.write(_ payload:)`. The drive bank's sessions become one `OpticalDrive` implementation; `DiscRecordingOpticalDrive` merges into it.
  2. A `BurnCoordinator` actor in BurnKit owns the queue run and the pool, on top of `BurnClaimLedger`. It publishes progress as an `AsyncStream` that a small `@Observable` adaptor in the app mirrors.
  3. The app keeps only what needs AudioKit, VideoKit or NetworkSpool, behind two protocols: preparing a payload (render audio, master an image), and a remote burner (implemented over `SpoolRemoteNodeClient`).
  4. Tests: drive the coordinator with `ScriptedOpticalDrive` in `swift test` and Suite runs. The journal comes for free.
  5. Order: after the first hardware test burns, so a regression can be told apart from a format problem. Move one destination kind at a time: disc image first, then physical, network, audio and CD-Extra.
- **Owner decides.**

### 12. Can we drop `--build-system native`?
*Re-examined 2026-11-26.*
- **Known:**
  - CI runs `macos-26` with Xcode 26.6 and Swift 6.3.3. There the native build system is still the default, so the warning and the old failure never appear in CI. Losa runs Xcode 27 with Swift 6.4, where SwiftPM's new build system (Swift Build, the same engine as Xcode) is the default and `native` is deprecated.
  - Both Swift 6.4 errors we hit on Losa got past CI: the `@State` macro plugin, and `#ImplicitStrongCapture`.
  - The 2026-11 plist failure on Losa happened while the Command Line Tools were selected, before Xcode was, so the most likely cause has gone.
  - Xcode builds packages through Swift Build and runs `xcstringstool compile` on `.xcstrings` resources. SwiftPM's native build only copies them, which is why `bundle-app.sh` compiles the catalog itself. So the new build system will probably compile the catalog too. Unverified.
  - GitHub's `xcode-27` runner label (macOS 27, Apple Silicon) has been generally available since 2026-10.
- **Answer by:**
  1. Add a CI job on `runs-on: xcode-27` that runs `swift build`, `swift test` and `krouton-verify` with the default build system. This alone would have caught both errors.
  2. In that job, list `Krouton_KroutonApp.bundle` and check for `.lproj` folders. If they're there, make the `xcstringstool` step in `bundle-app.sh` run only when they're missing.
  3. Once that job is green, remove `--build-system native` from `bundle-app.sh`. Keep it only if an older toolchain still needs it.

### 13. Text the String Catalog can't see yet
*Measured 2026-11-26 in `Sources/KroutonApp`* (668 keys; translations into de, es, fr, it, ja, ko, nl, pt-BR and zh-Hans, all marked needs review).
- **Known:** four kinds of text stay English. Each needs a different fix.
  1. **137 interpolated SwiftUI literals in 48 files**, such as `Text("STEP \(n) OF \(count)")`. These *would* translate: SwiftUI looks them up under a format key such as `STEP %lld OF %lld`. `extract-strings.py` skips them, so the keys never reach the catalog. Fix: teach the script to emit format keys (`%lld` for integers, `%@` for strings, `%f`-style for doubles), as Xcode does.
  2. **133 `Text(someString)` calls.** A `String` variable is shown verbatim, never localized. Among them are tutorial step headlines and bodies, chapter titles and preset names. Fix: make those model fields `LocalizedStringResource` (or pass them through `tr`), and mark data that is really data (drive names, file names) with `Text(verbatim:)` so it is clear.
  3. **Enum raw values.** 14 `Text(x.rawValue)` calls, plus 30 `tr(nonLiteral)` calls whose keys the script can't see. `KroutonSettingsCategory` has 1 of its 9 raw values in the catalog; `KroutonPoolDispatchMode` has 0 of 2; 6 of the 7 destination `title`s are missing. Fix: a `title: LocalizedStringResource` on each enum, and stop showing `rawValue`.
  4. **`tr()` with interpolation**, 3 calls (such as `tr("Pair with \(name)")`). They look up the finished sentence, so they can never match. Fix: `String(localized: "Pair with \(name)")`.
  Also, 37 `Text(String(format:))` labels are mostly numbers and units; they need `.formatted()` or `Measurement` so decimals and units follow the locale.
- **Answer by:** 1 and 4 are mechanical, so start there; then 3, then 2. Extend `--check` so a new `Text(variable)` without `verbatim:` fails CI.
- **Owner decides** which languages to commission, and who reviews them.

### 14. The shared workspace parameters
*Re-examined 2026-11-26.*
- **Known:**
  - `KroutonMainWorkspaceView` measures the centre column and keeps five layout flags, with hysteresis (narrow below 510, wide above 535): `isCenterWorkspaceNarrow`, `isCenterWorkspaceUltraCompact`, `isLeftSidebarCompact`, `isLeftSidebarUltraSkinny` and `isRightQueueCompact` (18 uses in 7 files).
  - `isCenterWorkspaceNarrow` is passed by hand into 8 workspace initializers. Three of them never read it: `KroutonCopyAndRipWorkspaceView`, the video authoring and the retro console workspaces.
  - `KroutonViewportTier` (in `KroutonDesignSystem.swift`, four width tiers) was a fuller version of the same idea and is unused.
  - Only 12 views use `ViewThatFits` or `onGeometryChange` themselves.
- **Proposal:** one `KroutonLayoutTier` (compact, regular, wide), computed once with the existing hysteresis and passed down as `@Environment(\.kroutonLayout)`. It replaces the five flags and the abandoned enum, and removes the parameter from every initializer. Views that only swap a label for a shorter one should use `ViewThatFits` instead and need no flag at all. Small, safe, and testable with SwiftUI previews at several widths.

### 15. Checks that need a person: VoiceOver and performance
- **Known:** The VoiceOver descriptions added on 2026-11-26 (label canvas layers, splice waveform, burn graph) have only been checked by CI. The Panorama Planet renders on the main thread whenever a setting changes.
- **Answer by:** Turn VoiceOver on (⌘F5) and go through the label workspace and audio editor, noting anything confusing. Measure planet rendering at the largest canvas zoom on Apple Silicon. If it stutters, render off the main actor and show the last image meanwhile.
