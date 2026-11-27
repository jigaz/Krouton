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

## Engines behind features the UI already offers (need device or listening tests to wire)

- `AudioDiscWarning` — me · 2027-01-31 · show `breakSplitsContinuousRun` in the audio workspace (AudioKit/AudioDiscPlan.swift)
- `DiscRepacker` — me · 2027-01-31 · "Repack to use fewer discs" for data spans only (OpticalCore/Spanning/DiscPlanner.swift)
- `KroutonConsoleMasteringConfig` — me · 2027-01-31 · back the retro-console settings with it, or delete it (OpticalCore/Models/OpticalMasteringDomainModels.swift)
- `KroutonDiscHubGeometry` — me · 2027-01-31 · drive the label canvas's hub sizes and print template from it (LabelKit/LabelGeometry.swift)
- `KroutonTrackAutoIdentifier` — me · 2027-01-31 · suggest track titles when audio files are staged (AudioKit/AudioEngine.swift)
- `KroutonIdentifiedTrackMetadata` — me · 2027-01-31 · returned by `KroutonTrackAutoIdentifier`; goes with it (AudioKit/AudioEngine.swift)
- `PeakPyramid` — me · 2027-01-31 · replace the synthetic waveform bars with pyramids built at staging time (AudioKit/HonestTrackData.swift)

## Part of a used type's API

Types the app reaches only through another type: a return value, a thrown error, a property. Swift requires
them to be public, so "make internal" isn't an option. Suite 28 checks that the owner uses each one and that
the owner (or its owner) has a production caller, so an entry fails as soon as its owner stops being used.

Format: `- `TypeName` — `Owner` · how`.

- `AudioAnalysisError` — `AudioAnalysisService` · thrown
- `AudioDiscPlan` — `AudioProject` · returned by `discPlan()`, which the audio workspace and spanning use
- `AudioMasteredDiscResult` — `KroutonAudioEngine` · returned
- `AutoLabelComposition` — `AutoLabelComposer` · returned
- `BurnJournaling` — `BurnSetScheduler` · the journal it writes to
- `BurnTransitionError` — `DiscJob` · thrown
- `CDTextError` — `CDTextBlockCompiler` · thrown
- `DiscImageParsedCueSheet` — `KroutonDiscImageDepot` · returned
- `DiscImageParsedTrack` — `DiscImageParsedCueSheet` · its tracks
- `DiscJobState` — `DiscJob` · its state
- `DVDVideoRelinkedCellRange` — `DVDVideoIFORelinker` · returned
- `KroutonAccurateRipReport` — `KroutonAccurateRipVerifier` · returned
- `KroutonAccurateRipTrackResult` — `KroutonAccurateRipReport` · its tracks
- `KroutonAudioRenderError` — `KroutonAudioDiscRenderer` · thrown
- `KroutonAudioTagError` — `KroutonAudioTagWriter` · thrown
- `KroutonBlankDiscInfo` — `KroutonDiscImageBurner` · returned
- `KroutonBuiltDiscImage` — `KroutonHybridImageBuilder` · returned
- `KroutonBurnMediaDecision` — `KroutonBurnMediaPolicy` · returned
- `KroutonCarAudioError` — `KroutonCarAudioDiscPreparer` · thrown
- `KroutonCDTextPack` — `KroutonAudioEngine` · returned
- `KroutonConnectedDrive` — `KroutonDiscImageBurner` · returned
- `KroutonDVD9MenuShrinkBlueprint` — `KroutonVideoAuthoringEngine` · returned
- `KroutonFinderBackgroundKind` — `KroutonFinderLayoutBlueprint` · a property
- `KroutonHeatTier` — `KroutonStreamProbeResult` · a property
- `KroutonHybridExtent` — `KroutonHybridLayoutPlan` · its extents
- `KroutonHybridImageError` — `KroutonHybridImageBuilder` · thrown
- `KroutonImageBuildCancellation` — `KroutonHybridImageBuilder` · its cancellation token
- `KroutonMasteringWorkspaceKind` — `KroutonOpticalWorkflowSpec` · a property
- `KroutonParityError` — `KroutonParityWriter` · thrown
- `KroutonPolarArcGlyphPlacement` — `KroutonLabelGeometryEngine` · returned
- `KroutonRawSectorMode` — `KroutonDiscImageCueTrack` · a property
- `KroutonRescueSectorStatus` — `KroutonRescueEngine` · returned
- `KroutonRippedTrackResult` — `KroutonRealCDExtractor` · returned
- `KroutonSectorRescueAction` — `KroutonSectorRescueDecision` · a property
- `KroutonShrunkDVD5CellEntry` — `KroutonDVD9MenuShrinkBlueprint` · its cells
- `KroutonStreamProbeResult` — `KroutonMediaPrepEngine` · returned
- `LaunchVerdict` — `RunLock` · returned
- `RestoreDecision` — `restoreDecision` · returned by the function
- `Sourced` — `TrackMetadata` · its fields
- `SpanInputFile` — `BurnSetPlanner` · its input
- `SpliceSubIndexDescriptor` — `SpliceCanvasGeometry` · returned
- `SpoolAddressClass` — `SpoolAddressVerdict` · its cases
- `SpoolCIDR` — `SpoolEndpointPolicy` · its ranges; could back a trusted-VPN setting
- `TrackMetadata` — `FilenameTitleGuess` · returned
