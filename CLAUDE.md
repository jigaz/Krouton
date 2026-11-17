# CLAUDE.md — Krouton

Krouton is a native macOS 14+ (Swift 6, SwiftUI, AppKit) optical media mastering, multi-disc spanning, archival rescue, and disc-label studio with a built-in headless CLI (`Krouton`), Apple Shortcuts (`AppIntents`), and a 22-suite verification executable (`krouton-verify`).

- **Bundle ID:** `com.krouton.opticalstudio`
- **Team ID:** `D3BJL3F92P` (Jorgen Thompquist)

## Build, Verify & Package Commands
- **Debug build:** `swift build`
- **Release build:** `swift build -c release`
- **Run unit test suites (9 test targets):** `swift test`
- **Run 22-suite architectural verification gate:** `swift run krouton-verify`
- **Compile Asset Catalog (`Assets.car`):**
  `xcrun actool Resources/Assets.xcassets --compile Resources --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist /tmp/assetcatalog_generated_info.plist`
- **Sync release binary & resources into `build/Krouton.app` and sign:**
  `cp .build/arm64-apple-macosx/release/Krouton build/Krouton.app/Contents/MacOS/Krouton`
  `cp Resources/Assets.car Resources/AppIcon*.icns build/Krouton.app/Contents/Resources/`
  `codesign --force --deep --sign - build/Krouton.app`

## 11-Target Swift 6 Package Architecture (`Package.swift`)
1. `OpticalCore` — Domain models, LBA math, Red Book 75-fps math, `KroutonSpanningDiscMedium`.
2. `DriveKit` — Hardware abstraction isolating `IOKit`, `DiscRecording`, `DiskArbitration`, and `hdiutil`.
3. `ImageKit` — Hybrid ISO-9660/UDF/El Torito LBA planner, CUE/BIN extractor, SHA-256 & hex inspector.
4. `AudioKit` — Red Book CUE compiler, 18B CD-TEXT CRC-16 encoder, equal-power crossfade DSP.
5. `VideoKit` — Optical bitrate budgeter, DVD-9 to DVD-5 shrink engine, IFO relinker, AVCHD muxer.
6. `BurnKit` — `DiscSpanningEngine`, frozen `BurnSet` state machine, single-read stager.
7. `RescueKit` — Bad-sector optical rescue engine and archival disc quality grader.
8. `LabelKit` — Polar 300-DPI disc geometry engine and 1:1 vector PDF print sheet generator.
9. `NetworkSpool` — Port `7420` remote optical burn server (`Krumb`) and spool telemetry.
10. `Persistence` — `SessionStore`, `RunLock` crash recovery, and security-scoped bookmark vault.
11. `KroutonApp` — SwiftUI macOS shell (`KroutonAppDelegate.swift`, `KroutonWindowManager`, `KroutonStateStore`), `AppIntents` Shortcuts provider, and `KroutonCLIRunner`.
- *Verification Target:* `KroutonVerify` (`krouton-verify` executable).

## Critical Guardrails
1. **Concurrency & MainActor:** UI and AppKit delegates (`KroutonAppDelegate`, `KroutonStateStore`) are `@MainActor` isolated. Keep hardware/optical I/O off the main thread.
2. **Optical Burn Safety:** Never allow app termination or system sleep while `driveManager.isExecutingQueue == true` (`KroutonPowerAndBurnAssertion` & `applicationShouldTerminate`).
3. **App Icons & Appearance Switching:**
   - When `store.iconWidgetStyle` is `"default"`, `NSApplication.shared.applicationIconImage` MUST be `nil` so macOS natively switches Default/Dark/Tinted/Clear icons via `Assets.car` (`CFBundleIconName = AppIcon`).
   - Use `.sourceAtop` in `tintMonochromeIcon` to preserve alpha transparency around the unplated bread icon.
4. **Color Palette:** Do not alter the locked 10-swatch Display-P3 harmony values documented in `KroutonPaletteKit/README_PALETTE_LOCKED.md`.
5. **Localization & Accessibility:** Route all user-facing strings through `KroutonL10n.tr(...)` and maintain the HIG 9pt typography floor.

## Multi-Agent Sync & Change Tracking (MANDATORY)
- Before making multi-file or architectural changes, write your proposed plan under `## Proposed Changes` in `AI_HANDOFF.md`.
- Always run `swift build` and `swift run krouton-verify` before finalizing changes.
- After completing any code, resource, or build modification, append a timestamped entry under `## Completed Changes` in `AI_HANDOFF.md` listing:
  1. Summary of what changed and why.
  2. Exact files created, modified, or deleted.
  3. Any follow-up items or open issues for the next session.
