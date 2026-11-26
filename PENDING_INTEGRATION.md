# Pending Integration

Public library types that no other production file references. `krouton-verify` Suite 28 reads this list:

- A type that is **not** on this list and has no production caller fails the build.
- A type that **is** on this list but has gained a caller fails the build until its entry is deleted.

So the list can only shrink. For each entry, either wire it in (and delete the line) or delete the code. Seeded 2026-11-18 from the codebase audit.

Format: `- `TypeName` — owner · decide-by date · plan`.

## Decided 2026-11-25

- **Networking (34 entries): resolved.** The app now talks to Krouton Server (`krouton-server/`, Rust) over KRSP.
  Client-side types are wired in: `SpoolRemoteNodeClient`, `SpoolServerConnection`, `SpoolTLS`, `NWSpoolChannel`,
  pairing, session proof, the upload sender, Bonjour hints, endpoint policy and `SpoolTelemetrySanitizer`.
  Node-side types (`DriveLeaseTable`, `SpoolExtentStore`, `SpoolStagingReceiver`, `SpoolTelemetryConflator`)
  were deleted, because the server implements them in Rust. The staging receiver lives on as a test double in
  KroutonVerify. Rolling-burn cutover, path ranking and the HMAC envelope were deleted: remote burns always
  pre-stage, and TLS pinning replaces the shared secret.
- **`BurnPowerAndBandwidthArbiter`: wired** into `BurnSetScheduler`. A drive takes the spin-up token before it
  writes and releases it at steady writing.
- **`KroutonDiscReadbackVerifier`: was already used** by `KroutonDiscImageBurner`. It now has its own file, so the
  ratchet sees the caller.
- **`ScriptedOpticalDrive`: moved** to KroutonVerify, where Suite 30 uses it to test the scheduler.
- **Deleted:** `BurnClaimPolicy` (the scheduler claims discs itself), and the pure-Swift
  ISO writer (`KroutonHybridISO9660Writer`, `HybridISOFileInput`, `HybridSynthesizedISOImage`), which duplicated
  `hdiutil makehybrid`, the builder the app ships.

## Burn pool

- `BurnPoolSnapshot` — me · 2027-01-31 · show `BurnClaimLedger.snapshot()` in the burn-set sheet, or delete it with the ledger (OpticalCore/Burning/BurnPoolQueue.swift)
- `DriveBufferSample` — me · 2027-01-31 · feed DiscRecording buffer-fill telemetry into the scheduler's arbiter (`record`), or delete (BurnKit/BurnPowerAndBandwidthArbiter.swift)
- `KroutonPoolDriveDescriptor` — me · 2027-01-31 · route the card pool through `KroutonDrivePoolState.populateAndAssignInitialSlots`, or delete it with that API (OpticalCore/Burning/BurnPoolQueue.swift)

## Direct drive access without DiscRecording (prototype, read-only)

- `KroutonMMCDeviceSession` — me · 2027-02-28 · drive identity in Report a drive and the burn log first; then the burn sequence (RESERVE TRACK, WRITE(10), SYNCHRONIZE CACHE, CLOSE TRACK/SESSION) against a scripted drive, then real drives as a DriveKit fallback backend (DriveKit/KroutonMMCDirectAccess.swift)
- `KroutonMMCDirectAccess` — me · 2027-02-28 · as above (DriveKit/KroutonMMCDirectAccess.swift)

## Engines behind features the UI already offers (need device or listening tests to wire)

- `AVCHDClipDescriptor` — me · 2027-01-31 · AVCHD workspace: build BDMV/CLIPINF/PLAYLIST for staged .m2ts clips; test on a Blu-ray player (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AVCHDDiscStructureOutput` — me · 2027-01-31 · as above (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AVCHDOnDVDAuthoringEngine` — me · 2027-01-31 · as above (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AudioDiscPlan` — me · 2027-01-31 · replace `AudioProject.spannedDiscs()` (needs `probedFrameCount` and `anchoredDiscMetadata` on the model) (AudioKit/AudioDiscPlan.swift)
- `AudioDiscWarning` — me · 2027-01-31 · show `breakSplitsContinuousRun` in the audio workspace when the above lands (AudioKit/AudioDiscPlan.swift)
- `DiscRepacker` — me · 2027-01-31 · "Repack to use fewer discs" for data spans only (OpticalCore/Spanning/DiscPlanner.swift)
- `KroutonConsoleMasteringConfig` — me · 2027-01-31 · back the retro-console settings with it, or delete it (OpticalCore/Models/OpticalMasteringDomainModels.swift)
- `KroutonDiscHubGeometry` — me · 2027-01-31 · drive the label canvas's hub sizes and print template from it (LabelKit/LabelGeometry.swift)
- `KroutonTrackAutoIdentifier` — me · 2027-01-31 · suggest track titles when audio files are staged (AudioKit/AudioEngine.swift)
- `PeakPyramid` — me · 2027-01-31 · replace the synthetic waveform bars with pyramids built at staging time (AudioKit/HonestTrackData.swift)

## Supporting types reached only through return values or `throws` (lower priority)

- `AudioAnalysisError` — me · 2027-01-31 · make internal or keep (AudioKit/AudioAnalysisService.swift)
- `AudioMasteredDiscResult` — me · 2027-01-31 · make internal or keep (AudioKit/AudioSampleDecoder.swift)
- `AutoLabelComposition` — me · 2027-01-31 · make internal or keep (LabelKit/AutoLabelEngine.swift)
- `BurnJournaling` — me · 2027-01-31 · make internal or keep (BurnKit/BurnSetScheduler.swift)
- `BurnTransitionError` — me · 2027-01-31 · make internal or keep (OpticalCore/Burning/BurnSet.swift)
- `CDTextError` — me · 2027-01-31 · make internal or keep (AudioKit/CDTextBlockCompiler.swift)
- `DVDVideoRelinkedCellRange` — me · 2027-01-31 · make internal or keep (VideoKit/DVDVideoIFORelinker.swift)
- `DiscImageParsedCueSheet` — me · 2027-01-31 · make internal or keep (ImageKit/DiscImageDepot.swift)
- `DiscImageParsedTrack` — me · 2027-01-31 · make internal or keep (ImageKit/DiscImageDepot.swift)
- `DiscJobState` — me · 2027-01-31 · make internal or keep (OpticalCore/Burning/BurnSet.swift)
- `KroutonBlankDiscInfo` — me · 2027-01-31 · make internal or keep (DriveKit/KroutonDiscImageBurner.swift)
- `KroutonBuiltDiscImage` — me · 2027-01-31 · make internal or keep (ImageKit/HybridImageBuilder.swift)
- `KroutonBurnMediaDecision` — me · 2027-01-31 · make internal or keep (DriveKit/KroutonBurnPreflight.swift)
- `KroutonCDTextPack` — me · 2027-01-31 · make internal or keep (AudioKit/AudioEngine.swift)
- `KroutonConnectedDrive` — me · 2027-01-31 · make internal or keep (DriveKit/KroutonDiscImageBurner.swift)
- `KroutonDVD9MenuShrinkBlueprint` — me · 2027-01-31 · make internal or keep (VideoKit/VideoAuthoringEngine.swift)
- `KroutonFinderBackgroundKind` — me · 2027-01-31 · make internal or keep (ImageKit/FinderLayoutBlueprint.swift)
- `KroutonHeatTier` — me · 2027-01-31 · make internal or keep (OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift)
- `KroutonHybridExtent` — me · 2027-01-31 · make internal or keep (ImageKit/HybridImagePlanner.swift)
- `KroutonHybridImageError` — me · 2027-01-31 · make internal or keep (ImageKit/HybridImageBuilder.swift)
- `KroutonIdentifiedTrackMetadata` — me · 2027-01-31 · make internal or keep (AudioKit/AudioEngine.swift)
- `KroutonImageBuildCancellation` — me · 2027-01-31 · make internal or keep (ImageKit/HybridImageBuilder.swift)
- `KroutonMasteringWorkspaceKind` — me · 2027-01-31 · make internal or keep (OpticalCore/Models/OpticalWorkflowCatalog.swift)
- `KroutonPolarArcGlyphPlacement` — me · 2027-01-31 · make internal or keep (LabelKit/LabelGeometry.swift)
- `KroutonRawSectorMode` — me · 2027-01-31 · make internal or keep (ImageKit/DiscImageDepot.swift)
- `KroutonRescueSectorStatus` — me · 2027-01-31 · make internal or keep (RescueKit/RescueEngine.swift)
- `KroutonRippedTrackResult` — me · 2027-01-31 · make internal or keep (AudioKit/AudioSampleDecoder.swift)
- `KroutonSectorRescueAction` — me · 2027-01-31 · make internal or keep (RescueKit/RescueEngine.swift)
- `KroutonShrunkDVD5CellEntry` — me · 2027-01-31 · make internal or keep (VideoKit/VideoAuthoringEngine.swift)
- `KroutonSoftPatchSummary` — me · 2027-01-31 · make internal or keep (ImageKit/DiscImageDepot.swift)
- `KroutonStreamProbeResult` — me · 2027-01-31 · make internal or keep (OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift)
- `KroutonVideoChapterMarker` — me · 2027-01-31 · make internal or keep (VideoKit/VideoAuthoringEngine+SubtitlesAndMuxing.swift)
- `KroutonWorkflowCodecRow` — me · 2027-01-31 · make internal or keep (OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift)
- `LaunchVerdict` — me · 2027-01-31 · make internal or keep (Persistence/SessionStore.swift)
- `RestoreDecision` — me · 2027-01-31 · make internal or keep (Persistence/SessionStore.swift)
- `Sourced` — me · 2027-01-31 · make internal or keep (AudioKit/HonestTrackData.swift)
- `SpanInputFile` — me · 2027-01-31 · make internal or keep (BurnKit/BurnSetPlanner.swift)
- `SpliceSubIndexDescriptor` — me · 2027-01-31 · make internal or keep (AudioKit/SpliceOverlapMath.swift)
- `TrackMetadata` — me · 2027-01-31 · make internal or keep (AudioKit/HonestTrackData.swift)
- `SpoolAddressClass` — me · 2027-01-31 · make internal or keep (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolCIDR` — me · 2027-01-31 · keep for a "trusted VPN range" setting, or make internal (NetworkSpool/SpoolEndpointPolicy.swift)
