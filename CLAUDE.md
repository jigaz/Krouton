# CLAUDE.md — Krouton

Krouton is a native macOS optical disc burning, ripping, and disc-image utility built with Swift, SwiftUI, AppKit, and DriveKit.

## Build & Package Commands
- Debug build: `swift build`
- Release build: `swift build -c release`
- Compile Assets.car: `xcrun actool Resources/Assets.xcassets --compile Resources --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist /tmp/assetcatalog_generated_info.plist`
- Update app bundle & sign:
  `cp .build/arm64-apple-macosx/release/KroutonApp build/Krouton.app/Contents/MacOS/Krouton 2>/dev/null || cp .build/arm64-apple-macosx/release/Krouton build/Krouton.app/Contents/MacOS/Krouton`
  `cp Resources/Assets.car Resources/AppIcon*.icns build/Krouton.app/Contents/Resources/`
  `codesign --force --deep --sign - build/Krouton.app`

## Architecture & Guardrails
- Main target: `Sources/KroutonApp/` (`KroutonAppDelegate.swift`, `KroutonWindowManager`, `KroutonStateStore`, `KroutonOpticalDriveBank`).
- Optical engine: `DriveKit` (`isExecutingQueue`, `activeJobPhase`, `activeJobProgress`).
- Burn safety: Never allow app termination or system sleep while `driveManager.isExecutingQueue == true` (`KroutonPowerAndBurnAssertion`).
- App icons: When `store.iconWidgetStyle` is `"default"`, `NSApplication.shared.applicationIconImage` must be `nil` so macOS natively switches Default/Dark/Tinted/Clear icons via `Assets.car` (`CFBundleIconName = AppIcon`). Use `.sourceAtop` in `tintMonochromeIcon` to preserve transparency.
- Localization: Route user-facing strings through `KroutonL10n.tr(...)`.

## Multi-Agent Sync & Change Tracking (MANDATORY)
- Before making multi-file or architectural changes, write your proposed plan under `## Proposed Changes` in `AI_HANDOFF.md`.
- After completing any code, resource, or build modification, append a timestamped entry under `## Completed Changes` in `AI_HANDOFF.md` listing:
  1. Summary of what changed and why.
  2. Exact files created, modified, or deleted.
  3. Any follow-up items or open issues for the next session.
