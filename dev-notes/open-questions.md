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

### 8. Persisted names that overstate what Krouton does
- **Known:** `KroutonBurnDestinationKind` saves raw values such as "Video Transcode (H.265 / HEVC)" (it remuxes, no H.265) and "Disc Printer (Epson ET-8550)" (it writes a PDF). Saved queues depend on them, so they were left in place with a warning not to show them.
- **Answer by:** Plan a migration: new honest raw values, plus decoding that accepts the old ones. Then check nothing displays `rawValue`.

### 9. Unused-code report triage (248 findings)
- **Known:** CI's `unused-code` job (Periphery) lists 70 unused declarations, 120 properties that are written but never read, and 56 needlessly public ones. The first pass removed the clear cases. The rest share names with used code, or are fields of hashable cache keys and result types, which are usually fine.
- **Answer by:** Go module by module and check each finding by hand; remove only what is truly unused. Making the 56 declarations internal also shrinks Suite 28's surface.
- **Also:** Periphery's upstream repository has been archived, and Homebrew disables the formula on 2027-08-12. Find a maintained alternative, or pin a release binary in CI.

---

## Architecture and tooling

### 10. A burn coordinator outside the UI store
- **Known:** About 1,500 lines of burn orchestration live in `KroutonStateStore+BurnInput`, `+BurnSupport`, `+PhysicalBurn`, `+NetworkBurn`, `+DestinationExecution`, `+DestinationQueue` and `+SpannedDestinations`. Periphery found almost no dead code there, so it is real work in the wrong place.
  `KroutonOpticalDriveBank+BurnSession.swift` is at 499 of 500 lines, and its "NOTE(status, 2026-11)" comment predates the HFS and CD-Extra paths.
- **Answer by:** Propose a design: where the coordinator lives (BurnKit?), how the UI observes progress, how it's tested with `ScriptedOpticalDrive`. Do the move after the first hardware test burns, so a regression can be told apart from a format problem.
- **Owner decides.**

### 11. Can we drop `--build-system native`?
- **Known:** `Scripts/bundle-app.sh` forces SwiftPM's native build system wherever it's offered. Swift 6.4's default build system failed with "Unknown error parsing property list", but that happened before Xcode was selected on the Mac, so the cause may have been the Command Line Tools. SwiftPM now warns that the option is deprecated.
  Also, `swift build` copies `Localizable.xcstrings` instead of compiling it, so `bundle-app.sh` compiles it with `xcstringstool`. The default build system might compile it itself.
- **Answer by:** With Xcode 27 selected, run `swift build` without the option and with it, and compare the results, including whether `.lproj` folders appear in the resource bundle.

### 12. Text the String Catalog can't see yet
- **Known:** `Scripts/extract-strings.py` collects SwiftUI literals and `KroutonL10n.tr("…")`. Text built with interpolation (`Text("\(n) tracks")`) and text shown from enum `rawValue`s isn't extracted, so it stays English. The 17 existing translations are marked "needs review".
- **Answer by:** List the interpolated user-facing strings and convert them to `String(localized:)` format strings. Give enums a localized `title`.
- **Owner decides** which languages to commission, and who reviews them.

### 13. The shared workspace parameters
- **Known:** Every workspace view receives the same parameters, including `isCenterWorkspaceNarrow`, which three of them never read.
- **Answer by:** Consider an environment value (`@Environment(\.kroutonIsNarrow)`) instead of passing it through every workspace's initializer.

### 14. Checks that need a person: VoiceOver and performance
- **Known:** The VoiceOver descriptions added on 2026-11-26 (label canvas layers, splice waveform, burn graph) have only been checked by CI. The Panorama Planet renders on the main thread whenever a setting changes.
- **Answer by:** Turn VoiceOver on (⌘F5) and go through the label workspace and audio editor, noting anything confusing. Measure planet rendering at the largest canvas zoom on Apple Silicon. If it stutters, render off the main actor and show the last image meanwhile.
