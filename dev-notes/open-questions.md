# Open questions

Investigations, measurements and decisions that are waiting for an answer. Each one is a piece
of work someone can pick up. Gathered 2026-11-26; status checked against `main` on 2026-11-28
(up to PR #18).

## How to pick one up

1. Choose an entry from the table. The **Needs** column says whether you need a burner, a
   particular Mac, or nothing special.
2. Read the entry. **Known** is what has been found so far, **Answer by** is how to settle it.
3. Do the investigation and write what you found under the entry, in a pull request.
4. Look at **Who decides**:
   - **Owner** means the project owner chooses. Investigate and propose, but don't change
     behaviour until the owner agrees in the issue or PR.
   - **Contributor** means a PR that settles it with evidence can go straight to review.
5. When an entry is settled, mark it **Settled** with the PR number. Delete it once the answer is
   recorded somewhere permanent (the code, the manual, `CHANGELOG.md`). Keep the numbers: other
   files refer to entries by number.

Related notes: `pure-swiftui-shell.md` (the one AppKit file), `removed-formats.md`, and
`../PENDING_INTEGRATION.md` (9 unwired library types, decide by 2027-01-31).

## At a glance

| # | Question | Status | Needs | Who decides |
|---|---|---|---|---|
| 1 | Does DiscRecording write CD-ROM XA (Mode 2) sectors? | Open | CD burner, CD-RW | Owner |
| 2 | Does a Dreamcast .cdi land at the right sector? | Open | CD burner; a Dreamcast helps | Contributor |
| 3 | Does CD-Extra burn as one two-session job? | Open | CD burner, CD-RW | Contributor |
| 4 | Does a Krouton HFS disc boot a classic Mac? | Open | SheepShaver, or an old Mac and a burner | Contributor |
| 5 | How do printer tools scale a label image? | Open | Epson or Canon disc printer | Contributor |
| 6 | The archival quality grade can never be shown | Open | Research; drives for the scanning option | Owner |
| 7 | Do projects saved by earlier versions still open? | **Settled** (PR #10) | — | — |
| 8 | Destination cards that say one thing and do another | Mostly settled (PR #5); 4 items left | Mac with Xcode 27.2 | Contributor |
| 9 | Unused-code report triage | Partly settled | Mac with Xcode 27.2 | Owner for Auto-Label; Contributor for the rest |
| 10 | Periphery is archived: what should CI run? | Open | No hardware | Owner |
| 11 | A burn coordinator outside the UI store | Partly settled (PR #8) | Mac with Xcode 27.2; burner for the later steps | Owner |
| 12 | Can we drop `--build-system native`? | Partly settled (PR #16) | Mac with Xcode 27.2 | Contributor |
| 13 | Text the String Catalog can't see yet | Partly settled (PR #6) | No hardware | Contributor; Owner for languages |
| 14 | The shared workspace parameters | **Settled** (PR #7) | — | — |
| 15 | VoiceOver and performance checks | Open | A Mac and a person | Contributor |
| 16 | Live updates: Mac Live Activities, iPhone, Apple Watch | Partly settled (PR #17) | macOS 27.3 SDK; developer account | Owner |
| 17 | Ship Krouton.app from the Xcode project | Open | Developer ID certificate | Owner |

"Mac with Xcode 27.2" means the change is Swift and needs `swift build`, `swift test` and
`swift run krouton-verify` to check it. CI runs them on every pull request, so a contributor
without that Mac can still open a PR and let CI check it.

---

## Hardware: what only a real drive can answer

### 1. Does DiscRecording write CD-ROM XA (Mode 2) sectors from our own tracks?
- **Status:** open.
- **Needs:** a CD burner and CD-RW discs; a way to read raw sector headers (`cdrdao` or an MMC READ CD).
- **Known:** The Dreamcast burn (`DriveKit/KroutonOpticalDriveBank+DiscJugglerBurn.swift`) asks for Mode 2 raw (2,336-byte) and Mode 2 Form 1 blocks through producer tracks. The SDK accepts the settings, but nothing has been burned. Video CD and Photo CD need Mode 2 Form 2 (2,324 bytes), and CD-Extra's data session should be Mode 2 too; today it's Mode 1.
- **Answer by:** Burn a small Mode 2 Form 1 and a Form 2 track to CD-RW, then read the sector headers back, for example with `cdrdao read-cd` or an MMC READ CD.
- **Unblocks:** Video CD, Photo CD (Base resolution) and a Blue Book-correct CD-Extra.
- **Who decides:** Owner, on whether to build the CD-ROM XA writer.

### 2. Does a Dreamcast .cdi land at the sector it was mastered for?
- **Status:** open.
- **Needs:** a CD burner, a CD-R or CD-RW, an audio/data .cdi image; a Dreamcast to test booting.
- **Known:** `KroutonDiscJugglerImage.audioDataPlan` refuses an image unless its data starts at last audio frame + 6,750 + 4,500 + pregap (11,702 for the usual 302-frame audio track). That assumes the drive writes standard lead-out and lead-in lengths, and that track-at-once writing adds no run-out blocks.
- **Answer by:** Burn one audio/data .cdi, read the TOC back (READ TOC format 2), and compare the data track's start with the image's. Then try booting it on a Dreamcast.
- **If it's off:** Pin the write strategy (session-at-once) or adjust the arithmetic in `audioDataPlan`.
- **Who decides:** Contributor. A fix backed by a TOC read-back can go straight to review.

### 3. Does CD-Extra's two-session layout burn as one job?
- **Status:** open.
- **Needs:** a CD burner and a CD-RW.
- **Known:** `beginAudioBurn` hands DiscRecording `[audioTracks, [dataTrack]]` with the session-at-once strategy required. Whether DiscRecording accepts both together is untested.
- **Answer by:** Burn to CD-RW. Check that a CD player plays the audio and that macOS mounts the second session's files.
- **Who decides:** Contributor.

### 4. Does a Krouton HFS disc boot a classic Mac?
- **Status:** open.
- **Needs:** SheepShaver (no burner needed: it can boot the image), or a New World Mac and a burner.
- **Known:** The HFS writer blesses the System Folder and copies the boot blocks. CI checks the image with its own parser and mounts it on Linux. Old Macs also need CD driver partitions in the partition map, which Krouton doesn't write.
- **Answer by:** Boot SheepShaver or a New World Mac (Mac OS 8.5–9.2) from a burned disc or the image. Record which Macs boot and which don't.
- **Who decides:** Contributor.

### 5. How do printer tools scale a printable-disc image?
- **Status:** open.
- **Needs:** an Epson or Canon printer that prints on discs, and printable discs.
- **Known:** The PNG export is the disc diameter plus bleed, at the chosen dpi. It's not yet known how Epson Print CD and Canon IJ Label Print scale an image that's 122 mm, not 120 mm.
- **Answer by:** Print the alignment test and a planet label on a printable disc in each tool. Note the scaling and offsets in the manual's Printing section.
- **Who decides:** Contributor.

---

## Correctness and honesty

### 6. The archival quality grade can never be shown
- **Status:** open (checked 2026-11-28: unchanged).
- **Needs:** research first; drives that report C1/C2 errors if the answer is to implement scanning.
- **Known:** `RescueKit/RescueEngine.swift` `evaluateArchivalDiscGrade` grades C1/C2/jitter and prints an "ISO/IEC 10149 & ECMA-267 Compliant" certificate. But every caller (`KroutonAuxModalsAndScopes.swift`, `KroutonMenuCommands.swift`, through a pass-through in `LabelKit/LabelGeometry.swift`) passes no measurements, so the result is always "NOT MEASURED". The grading branch is unreachable, and the standards claim was never checked.
- **Answer by:** Find out whether any drive Krouton supports can report C1/C2 errors (vendor commands, as used by QPxTool or Opti Drive Control).
- **Also:** LabelKit wraps two RescueKit functions (`evaluateArchivalDiscGrade`, `buildOpticalRescueMap`). That is the only reason LabelKit depends on RescueKit.
- **Who decides:** Owner: implement real scanning for the drives that support it, or remove the grade, its menu item and the certificate text.

### 7. Do projects saved by earlier versions still open?
- **Status:** **settled** by PR #10 (commit 2be1bb7, "Open projects and sessions saved by another version").
- **What was done:** A project or session that `JSONDecoder` refuses is read a second time with repairs (`OpticalCore/Codable/PersistedDecoder.swift`): a missing field takes the value a new project starts with (`KroutonPersistedDefault`), an unknown choice falls back to the plainest one, and an unreadable list element is left out. Repairs are counted in the banner and listed in the log. Tests: `Tests/OpticalCoreTests/PersistedJSONTests.swift`, `AudioProjectPersistenceTests.swift`.
- **Left:** nothing tracked here. Delete this entry once a release ships with it.

### 8. Destination cards that say one thing and do another
- **Status:** mostly settled by PR #5 (`fix/honest-destination-cards`); item 4 below settled since.
- **Needs:** a Mac with Xcode 27.2 for items 1–3 and 5; a CD drive to test item 1.
- **Fixed in PR #5:**
  - Rip cards use a typed `KroutonRipCodec` (FLAC, ALAC, WAV, AIFF), shown and chosen on the card. The "MP3" card that wrote AIFF is gone, and so is the AIFF-into-"Apple Lossless" switch.
  - Rip Audio CD and Extract Video Disc no longer offer a disc-image card: it imaged the burn deck, not the disc, while claiming ".BIN + .CUE" and "Decrypted". A saved one refuses and points to Duplicate Disc. There's no HEVC extract card any more.
  - Label cards save into their own folder (Downloads for new cards); Vector PDF Label writes only the PDF.
  - An unknown kind in a saved project is dropped instead of becoming a disc burner. Cards saved earlier are repaired on restore (`repairingLegacyPresets`).
  - "localhost:7420" is gone; an empty server means the first paired server. The card's picker already showed that server, so card and burn agreed; only the placeholder text was wrong.
- **Settled since:** item 4, renaming `KroutonBurnDestinationKind`'s raw values. Commit 33ce27f stores short identifiers ("video-extract", "label-print-sheet") and still reads the old values through `init(storedValue:)`. Suite 21 checks the old values stay readable. Builds from before that change can't read the new values.
- **Still open:**
  1. Saving an audio CD in the drive as .bin/.cue (raw 2,352-byte reads). Krouton can't yet, so no card offers it.
  2. Letting a queue disc-image card in Copy run the same sector copy as Duplicate Disc (`store.rescue`), instead of refusing.
  3. Choosing the folder on rip and label cards; today it's shown, not editable.
  5. `speedOrCodec` is still one free-text field for every kind; typed settings per kind would end this class of bug. The tolerant decoding from #7 now makes that change safe for saved projects.
- **Who decides:** Contributor for each item; ask the owner first if an item changes what a card offers.

### 9. Unused-code report triage
- **Status:** partly settled. Counts are from the CI log of `main` at 0c569bc (2026-11-26): 248 findings, of which 70 unused, 120 assigned but never read, 56 needlessly public, 2 redundant protocols or conformances. Re-run the `unused-code` job for current numbers.
- **Needs:** a Mac with Xcode 27.2 (or let CI check the PR); `brew install periphery && periphery scan` to see the report locally.
- **Settled since:**
  - `preserveMenus`: the Settings toggle now works. A DVD copy without menus plays every title in order (PR #11, commit d13cd22).
  - Capability bits: the client now checks what a server's drive writes, the disc in the tray and its free space before uploading (PR #9, commit de28227, `SpoolControlMessages+DriveFit.swift`).
  - The notification service now uses `driveName` to give each drive its own sound (PR #14). It still ignores `progress` and `speedLabel`.
  - `KroutonViewportTier` was replaced by `KroutonWindowLayout` (PR #7, see #14).
- **Still open:**
  - **Auto-Label** (`LabelKit/AutoLabelEngine.swift`) harvests artwork, frames it around the hole with Vision, extracts a palette, and builds a tracklist and rim banner. `AutoLabelStoreAdapter` applies only the title and subtitle, yet the summary says "embedded/folder artwork + Vision center-hole framing". PR #17 added title tidying with the on-device model, but the rest is still unused. Wire the rest in or cut the summary down. **Owner decides.**
  - Head and tail loudness (`AudioAnalysisService`, `headLUFS`/`tailLUFS`) are measured for every track and never read.
  - `KroutonDomainIdentity.spoolDefaultPort` exists, while 7420 is still written out in `SpoolRemoteNodeClient+Pairing.swift`, `SpoolServerDirectory.swift` and `KroutonSettingsWindow+BurnServersCard.swift`.
  - Duplicates to fold: two `parseCueSheet` functions in `ImageKit/DiscImageDepot.swift`, the LabelKit wrappers around RescueKit (#6), and `BurnPoolSnapshot` (see `PENDING_INTEGRATION.md`).
  - The 120 write-only properties are mostly harmless: fields of hashable cache keys (`LabelGeometry+OpticalPlayground.swift`, 11), file-identity snapshots compared whole (`BurnSetStager`, 6), and result fields. Leave them, or mark them with `// periphery:ignore` once checked.
  - The 56 needlessly public declarations: making them internal also shrinks Suite 28's surface. Do it module by module, with the iOS build of the portable libraries in the loop.
- **Likely false positives, keep:** `appDelegate` (an adaptor), the App Intents' `description` (read by the system), `burnQueueSubStore` (key paths).
- **Who decides:** Owner for Auto-Label. Contributor for the rest.

### 10. Periphery is archived: what should CI run?
- **Status:** open. CI still runs `brew install periphery` (the last open-source release, 3.8.0).
- **Needs:** no hardware; a CI change.
- **Known:** The author archived `peripheryapp/periphery` on 2026-08-12 and moved to a closed-source commercial successor, Periphery Pro (prebuilt `periphery-cli`). Homebrew deprecated the formula and disables it on 2027-08-12; until then CI keeps getting 3.8.0 under the MIT licence. A community fork (`tiny-earth-moon`) has since been renamed **outskirts**. It builds with Xcode 27.1 / Swift 6.4, has fixed false positives, and installs with `brew install tiny-earth-moon/tap/outskirts`. It is run by one account and has no release binaries outside its Apple-silicon bottle.
- **Options:**
  1. Do nothing until 2027-08-12.
  2. Build 3.8.0 from its tag in CI and cache the binary. Stable, but frozen, and it may stop understanding newer index stores.
  3. Switch to outskirts. Same config and CSV format; pin a version and keep the summary script.
  4. Buy Periphery Pro.
  5. Drop the job and rely on Suite 28 plus review.
- **Recommendation:** 3, pinned to a version, falling back to 2 if the fork stalls. The job is a report, not a gate, so a tool change can't break builds.
- **Who decides:** Owner (licence, and trust in a one-account fork).

---

## Architecture and tooling

### 11. A burn coordinator outside the UI store
- **Status:** partly settled by PR #8 (commit 2f9580b, "One burn coordinator for the queue and multi-disc sets").
- **Needs:** a Mac with Xcode 27.2; a burner to test each step after the first.
- **What was done:** `KroutonBurnCoordinator` (`BurnKit/BurnCoordinator.swift`) now starts every burn on this Mac. Queue burns and multi-disc sets can no longer take the drives from each other. What follows a burn is one decision (`stepAfterBurn`). The queue's burn pool moved out of `KroutonStateStore` into `KroutonBurnQueuePool`, with unit tests. Suite 40 keeps every burn going through the coordinator. The hardware calls are unchanged.
- **Still open:** the coordinator chooses between two burn paths; it doesn't merge them.
  - Multi-disc sets go `BurnSetScheduler` → `DiscRecordingOpticalDrive`. The scheduler's `OpticalDrive` protocol only has `write(image:)`, so audio tracks, CD-Extra's two sessions, `.cdi` sector layouts and folder burns can't use it yet.
  - Queue burns go through the drive bank (`KroutonOpticalDriveBank.beginBurn…`, DriveKit). OpticalCore's `BurnClaimLedger` is still mostly unused.
  - `KroutonOpticalDriveBank+BurnSession.swift` is at 499 of the 500-line limit.
- **Proposal for the rest:**
  1. Generalize the payload: `enum BurnPayload { image(URL), dataFolder(…), audio(KroutonAudioBurnDisc), sectors(SectorLayout) }`, and `OpticalDrive.write(_ payload:)`. The drive bank's sessions become one `OpticalDrive` implementation; `DiscRecordingOpticalDrive` merges into it.
  2. Run the queue and the pool on top of `BurnClaimLedger`, and publish progress as an `AsyncStream` that a small `@Observable` adaptor in the app mirrors.
  3. The app keeps only what needs AudioKit, VideoKit or NetworkSpool, behind two protocols: preparing a payload (render audio, master an image), and a remote burner (implemented over `SpoolRemoteNodeClient`).
  4. Order: after the first hardware test burns (#1–#3), so a regression can be told apart from a format problem. Move one destination kind at a time: disc image first, then physical, network, audio and CD-Extra.
- **Who decides:** Owner.

### 12. Can we drop `--build-system native`?
- **Status:** partly settled by PR #16 (commit 0d030a8). The main CI jobs now run on the `xcode-27` runner with Xcode 27.2, Swift 6.4 and the default build system (Swift Build).
- **Needs:** a Mac with Xcode 27.2, or CI.
- **Still uses `native`:**
  - `Scripts/bundle-app.sh`, which builds the release app. Its comment blames an "Unknown error parsing property list" from the new build system. That failure was seen while the Command Line Tools were selected instead of Xcode, so it may no longer happen.
  - CI's `string-catalog-format-keys` job: Swift Build doesn't yet write `-emit-localized-strings-path` output.
  - CI's `unused-code` job: Swift Build writes no index store that Periphery finds.
- **Answer by:**
  1. Build the release app with the default build system and list `Krouton_KroutonApp.bundle`. Check for `.lproj` folders. Xcode's build engine compiles `.xcstrings` itself, so it probably does; SwiftPM's native build only copies them, which is why `bundle-app.sh` runs `xcstringstool` itself. If they're there, run that step only when they're missing.
  2. If the release build works, remove `--build-system native` from `bundle-app.sh`.
  3. Check the two CI jobs with each new Swift release.
- **Who decides:** Contributor.

### 13. Text the String Catalog can't see yet
- **Status:** partly settled. Part 1 below was done by PR #6 (commit b290b06). Measured 2026-11-26 in `Sources/KroutonApp` (668 keys then; translations into de, es, fr, it, ja, ko, nl, pt-BR and zh-Hans, all marked needs review).
- **Needs:** no hardware. `python3 Scripts/extract-strings.py --check` runs anywhere; the Swift changes need a Mac with Xcode 27.2 or CI.
- **Known:** four kinds of text stayed English.
  1. **Settled.** Interpolated SwiftUI literals such as `Text("STEP \(n) OF \(count)")`. `extract-strings.py` now writes the format key SwiftUI looks up (`STEP %lld OF %lld`), and CI's `string-catalog-format-keys` job compares it with what the compiler looks up.
  2. **133 `Text(someString)` calls.** A `String` variable is shown verbatim, never localized. Among them are tutorial step headlines and bodies, chapter titles and preset names. Fix: make those model fields `LocalizedStringResource` (or pass them through `tr`), and mark data that is really data (drive names, file names) with `Text(verbatim:)` so it is clear.
  3. **Enum raw values.** 14 `Text(x.rawValue)` calls (still 14 on 2026-11-28), plus 30 `tr(nonLiteral)` calls whose keys the script can't see. On 2026-11-26, `KroutonSettingsCategory` had 1 of its 9 raw values in the catalog, `KroutonPoolDispatchMode` 0 of 2, and 6 of the 7 destination `title`s were missing. Fix: a `title: LocalizedStringResource` on each enum, and stop showing `rawValue`.
  4. **`tr()` with interpolation**, 3 calls (still 3 on 2026-11-28), such as `tr("Pair with \(name)")`. They look up the finished sentence, so they can never match. Fix: `String(localized: "Pair with \(name)")`.
  Also, 37 `Text(String(format:))` labels are mostly numbers and units; they need `.formatted()` or `Measurement` so decimals and units follow the locale.
- **Answer by:** 4 is mechanical, so start there; then 3, then 2. Extend `--check` so a new `Text(variable)` without `verbatim:` fails CI.
- **Who decides:** Contributor for the code. Owner for which languages to commission, and who reviews them.

### 14. The shared workspace parameters
- **Status:** **settled** by PR #7 (commit d3d9668, "One window layout from the SwiftUI environment").
- **What was done:** the five layout flags, the `isCenterWorkspaceNarrow` parameter passed through eight initializers, and the unused `KroutonViewportTier` became one `KroutonWindowLayout` (OpticalCore), published as `\.kroutonLayout`. Breakpoints and hysteresis carried over exactly; Suite 39 replays the old logic and fails if a view takes a layout flag through its initializer again. Tests: `Tests/OpticalCoreTests/WindowLayoutTests.swift`.
- **Left:** nothing. Delete this entry once a release ships with it.

### 15. Checks that need a person: VoiceOver and performance
- **Status:** open.
- **Needs:** a Mac running Krouton and a person; Apple silicon for the performance part.
- **Known:** The VoiceOver descriptions added on 2026-11-26 (label canvas layers, splice waveform, burn graph) have only been checked by CI. The Panorama Planet renders on the main thread whenever a setting changes.
- **Answer by:** Turn VoiceOver on (⌘F5) and go through the label workspace and audio editor, noting anything confusing. Measure planet rendering at the largest canvas zoom on Apple silicon. If it stutters, render off the main actor and show the last image meanwhile.
- **Who decides:** Contributor.

### 16. Live updates beyond the menu bar: Mac Live Activities, iPhone and Apple Watch
- **Status:** partly settled. The menu bar item, the Dock badge and the notification sounds ship. PR #17 added the Xcode project (`XcodeHost/`, generated with XcodeGen) with a widget extension, so the extension is no longer blocked by SwiftPM. A first Live Activity (`XcodeHost/Widgets/KroutonBurnLiveActivity.swift`) is written but compiled only with `KROUTON_LIVE_ACTIVITIES`, once the macOS 27.3 SDK ships.
- **Needs:** the macOS 27.3 SDK (in an Xcode 27.3 beta) for plan A; the paid developer account and an iPhone for plan B.
- **Plan and costs:** `live-updates-iphone-watch-mac.md` (shared model, plan A for the Mac, routes B1–B3 for iPhone and Watch).
- **Who decides:** Owner: start plan A when the macOS 27.3 SDK ships; iCloud (B1) or a relay (B2) for the phone.

### 17. Ship Krouton.app from the Xcode project
- **Status:** open.
- **Needs:** a Developer ID certificate and the developer account, to sign and notarize.
- **Known:** `XcodeHost/project.yml` (XcodeGen) builds Krouton.app with the desktop widget extension and App Intents (Get Krouton's Status, Eject the Disc, Show Krouton) for Shortcuts, Siri and Spotlight; CI's `xcode-app` job builds it. Release zips still come from `Scripts/bundle-app.sh` (SwiftPM), which has neither, so the manual doesn't describe them yet.
- **To do:** sign and notarize the Xcode build in `bundle-app.sh` (`xcodebuild archive`, then `-exportArchive` with Developer ID), confirm the app-group container works for a Developer ID build on macOS 26/27, then document the widget and Shortcuts in the manual.
- **Also:** Swift 6.4's default build system still doesn't write `-emit-localized-strings-path` output or an index store Periphery finds, so those CI jobs use `--build-system native` (see #12).
- **Who decides:** Owner: convert the generated project to Xcode 27.2's JSON format (`.xcproj`) in Xcode and commit it, retiring XcodeGen, or keep generating it.
