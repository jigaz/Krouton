# Pending integration

Public library types that no other production file uses yet. `krouton-verify` Suite 28 reads
this file (`Sources/KroutonVerify/VerifyHarness+IntegrationReachabilitySuite.swift`):

- A public type that is **not** listed here and has no production caller fails the build.
- A type that **is** listed here but has gained a caller fails the build until its entry is deleted.
- An entry for a type that no longer exists fails the build too.

So the list can only shrink. For each entry, either wire the type in and delete the line, or
delete the code and the line. Seeded 2026-11-18 from a codebase audit; checked 2026-11-28.

## How to pick one up

Each entry in the next two sections is a small, self-contained task: the plan says what wiring
it in means. Most need a Mac with Xcode 27.2 to build and run `swift run krouton-verify`, or a
pull request for CI to check. None needs a burner unless the plan says so. Ask the owner before
deleting a type whose plan offers "wire it in" as the first choice.

## Format (Suite 28 parses this)

- Every line that starts with `` - ` `` is an entry. The text between the first pair of
  backticks is the type name.
- In every section except the last, an entry reads:
  `` - `TypeName` — owner · decide-by date · plan (Module/File.swift) ``.
- The section headed exactly `## Part of a used type's API` must stay last. Its entries read
  `` - `TypeName` — `OwnerType` · how ``: the second backticked name is the type it belongs to.
- Other bullets must not start with a backtick, or Suite 28 will read them as entries.

## Burn pool

- `BurnClaimLedger` — project owner · 2027-01-31 · claim tickets from the destination queue's burn pool (the queue doesn't use it yet; a tutorial line used to name it), or delete it with `BurnPoolSnapshot` (OpticalCore/Burning/BurnPoolQueue.swift)
- `BurnPoolSnapshot` — project owner · 2027-01-31 · show `BurnClaimLedger.snapshot` in the burn-set sheet, or delete it with the ledger (OpticalCore/Burning/BurnPoolQueue.swift)
- `DriveBufferSample` — project owner · 2027-01-31 · feed DiscRecording's buffer-fill readings into the scheduler's arbiter (`record`), or delete it (BurnKit/BurnPowerAndBandwidthArbiter.swift)
- `KroutonPoolDriveDescriptor` — project owner · 2027-01-31 · route the card pool through `KroutonDrivePoolState.populateAndAssignInitialSlots`, or delete it with that function (OpticalCore/Burning/BurnPoolQueue.swift)

## Engines behind features the app already offers

These need a device or a listening test before they are wired in.

- `DiscRepacker` — project owner · 2027-01-31 · add "Repack to use fewer discs", for data spans only (OpticalCore/Spanning/DiscPlanner.swift)
- `KroutonConsoleMasteringConfig` — project owner · 2027-01-31 · back the retro-console settings with it, or delete it (OpticalCore/Models/OpticalMasteringDomainModels.swift)
- `KroutonDiscHubGeometry` — project owner · 2027-01-31 · take the label canvas's hub sizes and print template from it (LabelKit/LabelGeometry.swift)
- `KroutonTrackAutoIdentifier` — project owner · 2027-01-31 · suggest track titles when audio files are staged (AudioKit/AudioEngine.swift)
- `KroutonIdentifiedTrackMetadata` — project owner · 2027-01-31 · what `KroutonTrackAutoIdentifier` returns; goes with it (AudioKit/AudioEngine.swift)
- `PeakPyramid` — project owner · 2027-01-31 · replace the synthetic waveform bars with pyramids built at staging time (AudioKit/HonestTrackData.swift)

## Decided 2026-11-25

A record of the networking entries and a few others, settled before the list took its current
form. Nothing in this section is parsed.

- **Networking (34 entries): resolved.** The app talks to Krouton Server (`krouton-server/`,
  Rust) over KRSP. The client-side types are wired in: `SpoolRemoteNodeClient`,
  `SpoolServerConnection`, `SpoolTLS`, `NWSpoolChannel`, pairing, session proof, the upload
  sender, Bonjour hints, endpoint policy and `SpoolTelemetrySanitizer`. The node-side types
  (`DriveLeaseTable`, `SpoolExtentStore`, `SpoolStagingReceiver`, `SpoolTelemetryConflator`)
  were deleted, because the server implements them in Rust. The staging receiver lives on as
  a test double in KroutonVerify. Rolling-burn cutover, path ranking and the HMAC envelope
  were deleted: remote burns always pre-stage, and TLS pinning replaces the shared secret.
- **`BurnPowerAndBandwidthArbiter`: wired** into `BurnSetScheduler`. A drive takes the spin-up
  token before it writes and releases it once it is writing steadily.
- **`KroutonDiscReadbackVerifier`: was already used** by `KroutonDiscImageBurner`. It now has its
  own file, so the ratchet sees the caller.
- **`ScriptedOpticalDrive`: moved** to KroutonVerify, where Suite 30 uses it to test the scheduler.
- **Deleted:** `BurnClaimPolicy` (the scheduler claims discs itself), and the pure-Swift ISO
  writer (`KroutonHybridISO9660Writer`, `HybridISOFileInput`, `HybridSynthesizedISOImage`),
  which duplicated `hdiutil makehybrid`, the builder the app ships.

Moved 2026-11-28: `AudioDiscWarning` was listed as unwired, but the audio workspace already
shows its `breakSplitsContinuousRun` case (`AudioMasteringWorkspaces.swift`, through
`AudioDiscPlan.warnings`). It is now in the API section below.

## Part of a used type's API

Types the app reaches only through another type: a return value, a thrown error, a property.
Swift requires them to be public, so making them internal isn't an option. Suite 28 checks that
the owner type uses each one and that the owner (or its owner) has a production caller, so an
entry fails as soon as its owner stops being used. These are not tasks.

- `AudioAnalysisError` — `AudioAnalysisService` · thrown
- `AudioDiscPlan` — `AudioProject` · returned by `discPlan()`, which the audio workspace and spanning use
- `AudioDiscWarning` — `AudioDiscPlan` · its warnings, shown in the audio workspace
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
- `KroutonAfterBurnStep` — `KroutonBurnCoordinator` · what `stepAfterBurn` returns
- `KroutonAudioRenderError` — `KroutonAudioDiscRenderer` · thrown
- `KroutonAudioTagError` — `KroutonAudioTagWriter` · thrown
- `KroutonBlankDiscInfo` — `KroutonDiscImageBurner` · returned
- `KroutonBuiltDiscImage` — `KroutonHybridImageBuilder` · returned
- `KroutonBurnMediaDecision` — `KroutonBurnMediaPolicy` · returned
- `KroutonCarAudioError` — `KroutonCarAudioDiscPreparer` · thrown
- `KroutonCDTextPack` — `KroutonAudioEngine` · returned
- `KroutonColumnBreakpoint` — `KroutonWindowLayout` · its breakpoints
- `KroutonColumnSize` — `KroutonWindowLayout` · its column sizes
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
