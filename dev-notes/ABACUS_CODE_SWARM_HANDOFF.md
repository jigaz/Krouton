# Abacus.AI Code Swarm — Repository & Recent PR Review Handoff

## 1. Initial Prompt & Follow-Up Answer for Code Swarm

### Step A — Initial Prompt to Start the Session
```text
Review my recent pull requests and help me raise code quality — ask me for the repo and what to prioritize, then dig into bugs, tests, and security.
```

### Step B — Ready-to-Paste Reply When Code Swarm Asks for the Repo & Priorities
Upload `Krouton_CodeSwarm_Handoff.zip` and paste:

```text
Here is the full repository (`Krouton`, a macOS 14+ native optical disc mastering, extraction, bad-sector rescue, and distributed burn-pool suite written in Swift 6 with a 21-target SPM architecture and a 28-suite deterministic verification harness `krouton-verify`).

Please read `ABACUS_CODE_SWARM_HANDOFF.md` and `CLAUDE.md` first.

What to prioritize in your review of our recent PRs and codebase:
1. **Bugs & Resource Lifecycle (`DriveKit`, `BurnKit`, `AudioKit`, `VideoKit`, `Persistence`, `KroutonApp`):**
   - Hunt for silent failure paths (`try?` on disk writes/journals), integer/LBA math edge cases, main-actor blocking I/O, or memory buffers that are not returned to the system immediately when an operation or workspace finishes.
   - Check how we can shrink `PENDING_INTEGRATION.md` (Suite 28) by wiring remaining verified domain types (`BurnClaimLedger`, `BurnPowerAndBandwidthArbiter`, `KroutonEphemeralBurnCache`, `KroutonIdlePowerMonitor`, and the new `NetworkSpool` protocol actors) into the live app call paths and deleting duplicate legacy paths.
2. **Tests & Seam Coverage (`Tests/` and `Sources/KroutonVerify/`):**
   - All 28 suites in `krouton-verify` pass (478 behavior assertions, 5,782 source-rule checks). Identify the highest-value seam tests to add in `Tests/` (e.g., multi-disc `BurnSetScheduler` late-binding with `ScriptedOpticalDrive`, `RunLock` + orphaned staging directory recovery, and `NetworkSpool` end-to-end session tests).
3. **Security (`NetworkSpool`, `BurnKit`, `ImageKit`, `VideoKit`):**
   - Audit our recent PRs in `Sources/NetworkSpool/` (64-byte `KRSP` wire framing, Merkle `SpoolTransferManifest`, `SpoolExtentPipeline`, `SpoolExtentStore` with `F_PREALLOCATE` + `F_BARRIERFSYNC`, `DriveLeaseTable` fencing tokens, `SpoolEndpointPolicy` CIDR/rebinding defense, `SpoolPairing` commit-then-reveal numeric comparison, and `SpoolSecureTransport` TLS-PSK / mTLS 1.3 key pinning).
   - Audit path containment in `BurnSetStager` and subprocess argument safety in `ImageKit` / `VideoKit`.

Every recommendation or code patch must obey the non-negotiable gates in `CLAUDE.md` (100% Pure SwiftUI in `Sources/KroutonApp/Features/`, <= 400 LOC views, <= 500 LOC non-views, <= 200 LOC functions, canonical `// MARK: -` headers, `+Role.swift` naming, and zero shell invocations).
```

---

## 2. Summary of Recent Pull Requests / Commits Under Review

### PR / Milestone 1: Whole-Codebase Audit Fixes & Suite 28 Reachability Ratchet
- **`Sources/DriveKit/KroutonOpticalDriveBank+BurnAndSector.swift`:**
  - Replaced whole-file `Data(contentsOf:)` RAM loads (~1.4 GB RAM spike on `@MainActor`) in `convertBinAndIsoSectorImage` with a bounded 1,024-sector (~2 MB) `FileHandle` streaming loop writing to an atomic temporary file.
  - Fixed the `UInt8((absFrames / 75) / 60)` integer overflow crash on images > 2.35 GB by enforcing the Red Book 99:59:74 (449,999-sector) Mode 1 `.BIN` ceiling and encoding MSF headers in proper **BCD** (`((v / 10) << 4) | (v % 10)`).
- **`Sources/DriveKit/KroutonOpticalDriveBank.swift`:**
  - Guarded the 2-second hardware poll's `@Observable` property assignments (`availableDrives`, `selectedDrive`, `hardwareStatusLog`) with `!=` equality checks so idle CPU drops to 0.0%.
- **`Sources/BurnKit/BurnSetStager.swift`:**
  - Sanitized `StagedInputFile.init` against `../` relative path traversal and added a regression test in Suite 25.
- **`Sources/NetworkSpool/SpoolExtentPipeline.swift` & `SpoolRemoteNodeClient.swift`:**
  - Hardened `SpoolUploadSender.receive` to ignore unsolicited `.extentAck` frames for extents not currently in `inFlight` (tested in Suite 27).
  - Wired `SpoolLANSecurityEngine.isAllowedLANEndpoint` into `SpoolRemoteNodeClient.normalizedBaseURL(from:)`.
- **`Sources/AudioKit/AudioAnalysisService.swift`:**
  - Added a 64-track cache ceiling (`maxCachedAnalyses = 64`) and an explicit `purgeCache()` (`removeAll(keepingCapacity: false)`) resource-reclamation hook.
- **`Sources/KroutonVerify/VerifyHarness+IntegrationReachabilitySuite.swift` & `PENDING_INTEGRATION.md`:**
  - Added **Suite 28 (`Integration Reachability Ratchet: Verified Is Not the Same as Wired`)**, which ensures every `public` library type either has a production caller outside `KroutonVerify` or is tracked in `PENDING_INTEGRATION.md`, and fails when a listed type gains a caller until its entry is deleted.

### PR / Milestone 2: Distributed Spool Networking Stack & Suite 27 (`Sources/NetworkSpool/` & `Sources/KroutonVerify/`)
- Added `SpoolWireFrame.swift` (64-byte big-endian `KRSP` framing for 2048/2336/2352/2448 B sectors, rejecting > 8 MiB headers before allocation).
- Added `SpoolTransferManifest.swift` (RFC 6962 domain-separated Merkle tree, wire-validated `ExtentBitmap`, 44-byte checksummed `ExtentCommitRecord` journal replay).
- Added `SpoolExtentPipeline.swift` (sans-I/O `SpoolStagingReceiver` and `SpoolUploadSender` with durable-commit credit windowing <= 32 MiB).
- Added `SpoolExtentStore.swift` (`F_PREALLOCATE` + in-place `pwrite` + `F_BARRIERFSYNC` journal + `F_FULLFSYNC` on seal).
- Added `DriveLeaseTable.swift` (boot-epoch-seeded 64-bit monotonic fencing tokens, node-clock TTL expiry, idempotent reserve/commit retries, sticky `.burning` ownership at laser-on).
- Added `SpoolCutoverPolicy.swift` ($z = 2.33$ conservative throughput floor + stall-cushion lead formula).
- Added `SpoolEndpointPolicy.swift` (strict numeric IPv4/IPv6 CIDR matcher, octal IPv4 block, `.local` query/fragment smuggling block, NAT64/6to4/Teredo public-translation denial, opt-in Tailscale CGNAT & bounded studio CIDRs).
- Added `SpoolPairing.swift` & `SpoolSecureTransport.swift` (commit-then-reveal numeric comparison 6-digit pairing, per-session TLS exporter signature binding, TLS-PSK, and Keychain P-256 `SecIdentity` mTLS 1.3 X9.63 public-key pinning).
- Added `SpoolPathRanking.swift` & `SpoolTelemetryConflator.swift` (multi-homed path ranking with 25% hysteresis and 75 Hz -> 10 Hz terminal-sticky telemetry conflation).
- Added **Suite 27** (`VerifyHarness+DistributedSpoolSuites.swift`, `VerifyHarness+DistributedSpoolPolicySuites.swift`, `SimulatedFaultyTransport.swift`).

### PR / Milestone 3: Track Montage Waveform Peak Highlighting (`Sources/KroutonApp/Features/AudioCD/Splice/SpliceWaveformCanvas.swift`)
- Implemented per-track adaptive reference peak thresholds (`outRef` and `inRef`), true transient crest preservation (`0.92 * weightedMax + 0.08 * avg`), and wider theme off-shoot hue/luminance contrast (`hueShift: ±0.095`).

---

## 3. Git Commit Log & Working Tree Status

### Recent Commit Log (`git log -n 12 --stat --oneline`)
```text
47fd621 Synthesize Claude + Abacus.AI distributed spool networking stack, harden SpoolLANSecurityEngine, sync CLAUDE.md, and add Suite 27
 AI_HANDOFF.md                                      |  20 ++
 CLAUDE.md                                          | 112 +++++----
 .../KroutonVerify/SimulatedFaultyTransport.swift   |  90 ++++++++
 ...erifyHarness+DistributedSpoolPolicySuites.swift | 226 ++++++++++++++++++
 .../VerifyHarness+DistributedSpoolSuites.swift     | 253 +++++++++++++++++++++
 .../VerifyHarness+PeerAgentSynthesisSuites.swift   |   1 +
 Sources/NetworkSpool/DriveLeaseTable.swift         |  92 ++++++++
 Sources/NetworkSpool/SpoolCutoverPolicy.swift      | 108 +++++++++
 Sources/NetworkSpool/SpoolEndpointPolicy.swift     | 166 ++++++++++++++
 Sources/NetworkSpool/SpoolExtentPipeline.swift     | 173 ++++++++++++++
 Sources/NetworkSpool/SpoolExtentStore.swift        |  78 +++++++
 Sources/NetworkSpool/SpoolPairing.swift            | 112 +++++++++
 Sources/NetworkSpool/SpoolPathRanking.swift        |  58 +++++
 ...poolRemoteNodeClient+SecurityAndTelemetry.swift |  69 +++---
 Sources/NetworkSpool/SpoolSecureTransport.swift    | 168 ++++++++++++++
 Sources/NetworkSpool/SpoolTelemetryConflator.swift |  30 +++
 Sources/NetworkSpool/SpoolTransferManifest.swift   | 151 ++++++++++++
 Sources/NetworkSpool/SpoolWireFrame.swift          | 175 ++++++++++++++
 .../OpticalCore/Models/KroutonDomainIdentity.swift |   4 +
 19 files changed, 2000 insertions(+), 86 deletions(-)
db34e49 Use per-track adaptive peak thresholds and stronger theme off-shoot contrast for waveform peaks
 AI_HANDOFF.md                                      |  3 ++
 .../AudioCD/Splice/SpliceWaveformCanvas.swift      | 43 ++++++++++++----------
 2 files changed, 27 insertions(+), 19 deletions(-)
713674c Derive pure-SwiftUI peak off-shoot colors from active theme, add anti-aliased gain-blended peak fading, and enforce standing Pure-SwiftUI Feature Gate in Suite 2
 AI_HANDOFF.md                                      |   8 +
 .../AudioCD/Splice/SpliceControlsBar.swift         |   5 +-
 .../AudioCD/Splice/SpliceWaveformCanvas.swift      | 232 +++++++++++++++------
 .../AudioCD/Splice/SpliceWorkspaceView.swift       |   1 +
 .../Data/FinderDiscStageView+CellsAndMenus.swift   |   7 +-
 .../Features/Data/FinderDiscStageView.swift        |   6 +-
 .../VerifyHarness+ArchitectureSuites.swift         |   8 +
 7 files changed, 201 insertions(+), 66 deletions(-)
7e6ad0a Move smart edit-aware Reset button next to Gap/Gapless/Crossfade, add per-track peak highlight colors, and group Track Montage controls into 4 pods with live rubber-band X-Fade slider
 AI_HANDOFF.md                                      |  6 +++
 .../AudioCD/Splice/SpliceControlsBar.swift         | 47 ++++++++--------------
 .../Features/AudioCD/Splice/SpliceHeaderBar.swift  | 35 ++++++++++++++++
 .../AudioCD/Splice/SpliceWaveformCanvas.swift      | 11 +++--
 .../AudioCD/Splice/SpliceWorkspaceView.swift       | 16 ++++++++
 5 files changed, 81 insertions(+), 34 deletions(-)
3cf7105 Group Track Montage controls into 4 logical pods, link X-Fade slider to live canvas rubber-banding, fix OUT badge collision, and add collapsible sidebars + Krouton SVG logo
 AI_HANDOFF.md                                      |   5 +
 .../Features/AudioCD/Splice/SpliceCanvasArea.swift |   9 +-
 .../AudioCD/Splice/SpliceControlsBar.swift         | 328 +++++++++++++--------
 .../AudioCD/Splice/SpliceWorkspaceView.swift       |   4 +
 4 files changed, 222 insertions(+), 124 deletions(-)
dd927e2 Add collapsible left/right sidebars, Krouton SVG & vector brand logo, 72% auto-framed crossfade canvas with rubber-band rail dragging, and ±1s/2s/3s/10s responsive audition pills
 AI_HANDOFF.md                                      |  12 +
 Resources/KroutonLogo.svg                          |   7 +
 Sources/AudioKit/SpliceOverlapMath.swift           |  19 +-
 .../Features/AudioCD/Splice/SpliceCanvasArea.swift |  32 +-
 .../AudioCD/Splice/SpliceControlsBar.swift         |  34 ++-
 .../AudioCD/Splice/SpliceDragController.swift      |   7 +
 .../AudioCD/Splice/SpliceWaveformCanvas.swift      |   2 +-
 .../App/KroutonMenuCommands+EditAndView.swift      |   7 +
 .../Shell/DesignSystem/KroutonBrandLogoView.swift  |  63 ++++
 .../KroutonMainWorkspaceView+DropAndSheets.swift   | 147 ++++++++++
 .../Shell/Workspace/KroutonMainWorkspaceView.swift | 324 ++++++++-------------
 11 files changed, 428 insertions(+), 226 deletions(-)
2cee6dd Complete Passes 1-3: 4-point Bezier diamond Track Montage Editor (5s span + BPM), live Settings search, Apple HIG menu consolidation, and User Manual + live guided tutorials
 AI_HANDOFF.md                                      |  32 +++
 Sources/AudioKit/AudioAnalysisService.swift        |  53 +++-
 Sources/AudioKit/AudioEngine.swift                 |  26 +-
 Sources/AudioKit/AudioProject.swift                |   1 -
 Sources/AudioKit/CDTextBlockCompiler.swift         |   1 -
 Sources/AudioKit/CrossfadeRenderMailbox.swift      |  28 +-
 Sources/AudioKit/HonestTrackData.swift             |   3 -
 Sources/AudioKit/SpliceOverlapMath.swift           |  83 ++++--
 .../AudioCD/AudioMasteringWorkspaces.swift         |   1 -
 .../Features/AudioCD/Splice/SpliceCanvasArea.swift | 136 ++++++----
 .../AudioCD/Splice/SpliceControlsBar.swift         |  10 +-
 .../AudioCD/Splice/SpliceDragController.swift      |  12 +-
 .../Features/AudioCD/Splice/SpliceHeaderBar.swift  |   6 +-
 .../AudioCD/Splice/SpliceWaveformCanvas.swift      |   1 -
 .../AudioCD/Splice/SpliceWorkspaceView.swift       |  36 ++-
 Sources/KroutonApp/Shell/App/KroutonApp.swift      |   6 +
 .../App/KroutonMenuCommands+EditAndView.swift      |  76 +++++-
 .../KroutonApp/Shell/App/KroutonMenuCommands.swift | 105 +++-----
 .../Shell/App/KroutonWindowManager.swift           |  17 ++
 .../Shell/DesignSystem/KroutonPillControls.swift   |   1 -
 .../KroutonGuidedTutorialController.swift          | 297 +++++++++++++++++++++
 .../KroutonGuidedTutorialOverlayView.swift         | 197 ++++++++++++++
 .../KroutonSettingsWindow+FormatChooserPane.swift  |  17 +-
 .../ModalsAndSettings/KroutonSettingsWindow.swift  | 187 ++++++++++---
 .../KroutonUserManualWindowView.swift              | 275 +++++++++++++++++++
 .../KroutonStateStore+StagingAndCatalog.swift      |   4 +-
 .../Shell/Workspace/KroutonMainWorkspaceView.swift |  46 ++++
 .../VerifyHarness+ArchitectureSuites.swift         |  14 +
 .../VerifyHarness+MasteringDomainSuites.swift      |   4 +-
 .../VerifyHarness+PeerAgentSynthesisSuites.swift   |  18 ++
 Sources/Persistence/SessionStore.swift             |   1 -
 31 files changed, 1444 insertions(+), 250 deletions(-)
de26722 Synthesize multi-agent upgrades (Suites 23-26) and wire real-time AVAudioSourceNode crossfade auditioner via CrossfadeParameterMailbox
 AI_HANDOFF.md                                      |   8 +
 .../AudioCD/AudioMasteringWorkspaces.swift         |   3 +-
 .../Features/AudioCD/AudioProjectController.swift  |  28 ++-
 .../Features/AudioCD/Splice/SpliceAuditioner.swift | 229 +++++++++++++++------
 .../AudioCD/Splice/SpliceWorkspaceView.swift       |   3 +-
 .../KroutonObservableFeatureStores.swift           |   4 +-
 .../Shell/StateAndModels/KroutonStateStore.swift   |   2 +-
 7 files changed, 208 insertions(+), 69 deletions(-)
632b60b Synthesize multi-agent upgrades: BurnClaimLedger, ReferenceWritableKeyPath, APFS fclonefileat, BusArbitrationState, and CrossfadeParameterMailbox (Suites 23-26)
 AI_HANDOFF.md                                      |  15 ++
 Sources/AudioKit/AudioEngine.swift                 |  10 +-
 Sources/AudioKit/CrossfadeRenderMailbox.swift      | 151 ++++++++++++++++
 Sources/BurnKit/BurnPowerAndBandwidthArbiter.swift | 164 ++++++++++++++++++
 Sources/BurnKit/BurnSetScheduler.swift             |   6 +-
 Sources/BurnKit/BurnSetStager.swift                |  77 ++++++++-
 Sources/BurnKit/DiscRecordingOpticalDrive.swift    |   9 +-
 .../KroutonStateStore+DestinationExecution.swift   |   1 +
 .../KroutonStateStore+SpannedDestinations.swift    |   6 +-
 .../KroutonStateStore+SubStoreForwarding.swift     |   8 +-
 .../Shell/StateAndModels/KroutonStateStore.swift   |   9 +-
 .../VerifyHarness+HardwareAndBurnSuites.swift      |   1 +
 .../VerifyHarness+PeerAgentSynthesisSuites.swift   | 192 +++++++++++++++++++++
 Sources/OpticalCore/Burning/BurnPoolQueue.swift    | 125 ++++++++++++++
 14 files changed, 753 insertions(+), 21 deletions(-)
682da4b Add multi-burner work-stealing pool and two-zone waiting burn queue in right rack
 AI_HANDOFF.md                                      |  13 +
 Sources/BurnKit/BurnSetScheduler.swift             |  17 +-
 .../KroutonDestinationCardView.swift               |  11 +-
 .../KroutonDestinationSubViews+WaitingPool.swift   | 384 +++++++++++++++++++++
 .../KroutonDestinationSubViews.swift               |  14 +-
 .../StateAndModels/KroutonStateDomainModels.swift  |   4 +
 .../KroutonStateStore+DestinationExecution.swift   |  24 +-
 .../KroutonStateStore+SpannedDestinations.swift    | 284 ++++++++++++---
 .../Shell/StateAndModels/KroutonStateStore.swift   |   5 +
 .../VerifyHarness+HardwareAndBurnSuites.swift      |  77 +++++
 Sources/OpticalCore/Burning/BurnPoolQueue.swift    | 280 +++++++++++++++
 Sources/OpticalCore/Burning/BurnSet.swift          |  26 ++
 12 files changed, 1082 insertions(+), 57 deletions(-)
883dc54 Migrate state stores, sub-stores, and SwiftUI views to @Observable with per-property tracking
 AI_HANDOFF.md                                      | 67 ++++++++++++++++++
 Sources/DriveKit/KroutonOpticalDriveBank.swift     | 54 +++++++-------
 .../AudioCD/AudioMasteringBatchAndDiscViews.swift  |  4 +-
 .../AudioCD/AudioMasteringWorkspaces.swift         |  6 +-
 .../Features/AudioCD/CarSafeAudioWorkspace.swift   |  4 +-
 .../Features/AudioCD/Splice/SpliceAuditioner.swift | 12 ++--
 .../Features/AudioCD/Splice/SpliceCanvasArea.swift |  2 +-
 .../AudioCD/Splice/SpliceControlsBar.swift         |  2 +-
 .../AudioCD/Splice/SpliceDragController.swift      | 14 ++--
 .../Features/AudioCD/Splice/SpliceHeaderBar.swift  |  2 +-
 .../AudioCD/Splice/SpliceWorkspaceView.swift       |  8 +--
 .../DataAndArchivalWorkspaces+DeckControls.swift   |  8 +--
 .../Features/Data/DataAndArchivalWorkspaces.swift  |  4 +-
 .../Features/Data/DataDiscSpanningHeaderView.swift |  2 +-
 .../Data/DiscImageInspectorWorkspace.swift         |  2 +-
 .../Features/Data/FinderDiscStageView.swift        |  2 +-
 .../Features/Data/FinderViewOptionsPopover.swift   |  2 +-
 .../Features/Data/MasteringTelemetryPopovers.swift |  6 +-
 .../Features/Depot/KroutonDepotCatalogViews.swift  |  2 +-
 .../Depot/KroutonDepotHeroBannerView.swift         |  2 +-
 .../Features/Depot/KroutonDepotWorkspaceView.swift |  2 +-
 .../Label/DiscLabelWorkspace+AdjustInspector.swift | 10 +--
 .../DiscLabelWorkspace+BackgroundInspector.swift   | 18 ++---
 .../Label/DiscLabelWorkspace+BarsAndRails.swift    |  6 +-
 .../Label/DiscLabelWorkspace+ShapesInspector.swift |  3 +-
 .../Features/Label/DiscLabelWorkspace.swift        |  2 +-
 .../Features/Retro/RetroConsoleWorkspaces.swift    |  2 +-
 .../Rip/CopyAndRipWorkspaces+AudioUX.swift         |  8 +--
 .../Features/Rip/CopyAndRipWorkspaces.swift        |  6 +-
 .../Features/Video/VideoAuthoringWorkspaces.swift  |  6 +-
 Sources/KroutonApp/Shell/App/KroutonApp.swift      |  2 +-
 .../KroutonApp/Shell/App/KroutonAppDelegate.swift  | 55 +++++++++------
 .../KroutonApp/Shell/App/KroutonMenuCommands.swift |  2 +-
 .../Shell/App/KroutonStageImporter.swift           | 18 ++---
 .../Shell/App/KroutonWindowManager.swift           |  4 +-
 .../KroutonSharedWorkspaceComponents.swift         |  4 +-
 .../KroutonFloatingPhaseScopeWindow.swift          |  4 +-
 .../KroutonSettingsWindow+AuxPanes.swift           | 24 +++----
 .../KroutonSettingsWindow+BurnersNetworkPane.swift | 18 ++---
 .../KroutonSettingsWindow+GeneralPane.swift        | 14 ++--
 ...outonSettingsWindow+HardwareAndMediaPanes.swift | 34 ++++-----
 .../ModalsAndSettings/KroutonSettingsWindow.swift  |  6 +-
 .../KroutonBurnSetSheetView.swift                  |  4 +-
 .../KroutonBurnStationWorkspaceView.swift          |  2 +-
 .../KroutonCentralWorkspaceCapacityBarView.swift   |  2 +-
 .../KroutonDestinationCardView.swift               |  6 +-
 .../KroutonDestinationSubViews.swift               | 12 ++--
 .../KroutonNavigationAndTelemetryBars.swift        |  4 +-
 .../Shell/Services/KroutonBurnSetController.swift  | 18 ++---
 .../Shell/Services/KroutonEphemeralBurnCache.swift |  8 ++-
 .../KroutonNotificationAndCompanionService.swift   |  8 ++-
 .../StateAndModels/AppearancePreferences.swift     | 11 ++-
 .../Shell/StateAndModels/DepotCatalogue.swift      |  5 +-
 .../KroutonObservableFeatureStores.swift           |  3 -
 .../KroutonProjectAndSessionVault.swift            | 12 ++--
 .../StateAndModels/KroutonSessionPersistence.swift | 22 +++---
 .../KroutonStateStore+DestinationExecution.swift   |  1 -
 .../KroutonStateStore+StagingAndCatalog.swift      |  1 -
 .../KroutonStateStore+SubStoreForwarding.swift     | 47 +++++--------
 .../Shell/StateAndModels/KroutonStateStore.swift   | 82 +++++++++++-----------
 .../Shell/StateAndModels/LabelDocument.swift       |  5 +-
 .../Shell/StateAndModels/RipSettings.swift         |  5 +-
 .../KroutonMainWorkspaceView+DropAndSheets.swift   | 10 +--
 .../Shell/Workspace/KroutonMainWorkspaceView.swift |  8 +--
 .../VerifyHarness+ArchitectureSuites.swift         | 13 ++++
 Sources/NetworkSpool/SpoolRemoteNodeClient.swift   | 28 ++++----
 66 files changed, 438 insertions(+), 332 deletions(-)
b6b4739 Architectural Pass: Typed KroutonFormatID routing, KroutonPreferences layer, and ImageKit ISO synthesis decoupling
 AI_HANDOFF.md                                      |  20 +++
 Sources/ImageKit/DiscImageDepotOperations.swift    |  48 +++++++
 .../Features/Rip/CopyAndRipWorkspaces.swift        |   6 +-
 .../KroutonApp/Shell/App/KroutonAppDelegate.swift  |   3 +-
 .../KroutonApp/Shell/App/KroutonMenuCommands.swift |  80 ++++++-----
 .../Shell/DesignSystem/KroutonThemeEngine.swift    |   2 +-
 .../KroutonCentralWorkspaceCapacityBarView.swift   |   4 +-
 .../StateAndModels/AppearancePreferences.swift     |  66 +++++++--
 .../StateAndModels/KroutonSessionPersistence.swift |   6 +-
 .../KroutonStateStore+DepotCache.swift             |  47 +------
 .../KroutonStateStore+DestinationExecution.swift   |   2 +-
 .../KroutonStateStore+DestinationQueue.swift       |  69 +++++-----
 .../KroutonStateStore+SpannedDestinations.swift    |   2 +-
 .../KroutonStateStore+SubStoreForwarding.swift     |  20 +--
 .../Shell/StateAndModels/KroutonStateStore.swift   |  17 +--
 .../VerifyHarness+ArchitectureSuites.swift         |  24 ++++
 .../VerifyHarness+ImageAndSectorSuites.swift       |  16 +++
 Sources/OpticalCore/Models/MultiDiscSpanner.swift  |  30 ++---
 .../Models/OpticalWorkflowCatalog.swift            | 148 +++++++++++++--------
 19 files changed, 370 insertions(+), 240 deletions(-)
```

### Working Tree Status (`git status -s`)
```text
M .github/workflows/ci.yml
 M .gitignore
 M ARCHITECTURE.md
 M CLAUDE.md
 M README.md
 M SECURITY.md
 M Sources/AudioKit/AudioAnalysisService.swift
 M Sources/BurnKit/BurnSetStager.swift
 M Sources/DriveKit/KroutonOpticalDriveBank+BurnAndSector.swift
 M Sources/DriveKit/KroutonOpticalDriveBank.swift
 M Sources/KroutonVerify/VerifyHarness+DistributedSpoolSuites.swift
 M Sources/KroutonVerify/main.swift
 M Sources/NetworkSpool/SpoolExtentPipeline.swift
 M Sources/NetworkSpool/SpoolRemoteNodeClient.swift
?? .swiftpm/
?? CONTRIBUTING.md
?? Casks/
?? PENDING_INTEGRATION.md
?? Scripts/
?? Sources/KroutonVerify/VerifyHarness+IntegrationReachabilitySuite.swift
?? build/
```
