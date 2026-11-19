# Pending Integration

Public library types that no other production file references. `krouton-verify` Suite 28 reads this list:

- A type that is **not** on this list and has no production caller fails the build.
- A type that **is** on this list but has gained a caller fails the build until its entry is deleted.

So the list can only shrink. For each entry, either wire it in (and delete the line) or delete the code. Seeded 2026-11-18 from the codebase audit.

Format: `- `TypeName` — owner · decide-by date · plan`.

## Remote spool protocol (Q1–Q9 of the networking consult) — not called by SpoolRemoteNodeClient

- `DriveLease` — me · 2026-12-15 · wire or delete (NetworkSpool/DriveLeaseTable.swift)
- `DriveLeaseRejection` — me · 2026-12-15 · wire or delete (NetworkSpool/DriveLeaseTable.swift)
- `DriveLeaseTable` — me · 2026-12-15 · wire or delete (NetworkSpool/DriveLeaseTable.swift)
- `LinkThroughputStats` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolCutoverPolicy.swift)
- `NWSpoolChannel` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolAddressClass` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolAddressVerdict` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolBonjour` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolCIDR` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolCutoverDecision` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolCutoverPolicy.swift)
- `SpoolCutoverPolicy` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolCutoverPolicy.swift)
- `SpoolEndpointDenial` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolExtentStore` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolExtentStore.swift)
- `SpoolFrameKind` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolWireFrame.swift)
- `SpoolHostVerdict` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolEndpointPolicy.swift)
- `SpoolLinkKind` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPathRanking.swift)
- `SpoolMediaClass` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolCutoverPolicy.swift)
- `SpoolNodeCapabilities` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolNodeID` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolPairing` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolPairingError` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolPairingHello` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolPairingResult` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolPathCandidate` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPathRanking.swift)
- `SpoolPathRanking` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPathRanking.swift)
- `SpoolSessionProof` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolPairing.swift)
- `SpoolStagingReceiver` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolExtentPipeline.swift)
- `SpoolStoreAndForwardReason` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolCutoverPolicy.swift)
- `SpoolTLS` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolTelemetryConflator` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolTelemetryConflator.swift)
- `SpoolTransportChannel` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolTransportError` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolSecureTransport.swift)
- `SpoolUploadSender` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolExtentPipeline.swift)

## Burn pool and bus arbitration — BurnSetScheduler still uses its own early-claim loop

- `BurnClaimPolicy` — me · 2026-12-15 · wire or delete (OpticalCore/Burning/BurnPoolQueue.swift)
- `BurnPoolSnapshot` — me · 2026-12-15 · wire or delete (OpticalCore/Burning/BurnPoolQueue.swift)
- `BurnPowerAndBandwidthArbiter` — me · 2026-12-15 · wire or delete (BurnKit/BurnPowerAndBandwidthArbiter.swift)
- `DriveBufferSample` — me · 2026-12-15 · wire or delete (BurnKit/BurnPowerAndBandwidthArbiter.swift)
- `KroutonPoolDriveDescriptor` — me · 2026-12-15 · wire or delete (OpticalCore/Burning/BurnPoolQueue.swift)

## Security and telemetry helpers with no production caller

- `SpoolSignedEnvelope` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolRemoteNodeClient+SecurityAndTelemetry.swift)
- `SpoolTelemetrySanitizer` — me · 2026-12-15 · wire or delete (NetworkSpool/SpoolRemoteNodeClient+SecurityAndTelemetry.swift)

## Engines with no production caller (UI may advertise them)

- `AVCHDClipDescriptor` — me · 2026-12-15 · wire or delete (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AVCHDDiscStructureOutput` — me · 2026-12-15 · wire or delete (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AVCHDOnDVDAuthoringEngine` — me · 2026-12-15 · wire or delete (VideoKit/AVCHDOnDVDAuthoringEngine.swift)
- `AudioDiscPlan` — me · 2026-12-15 · wire or delete (AudioKit/AudioDiscPlan.swift)
- `AudioDiscWarning` — me · 2026-12-15 · wire or delete (AudioKit/AudioDiscPlan.swift)
- `DiscRepacker` — me · 2026-12-15 · wire or delete (OpticalCore/Spanning/DiscPlanner.swift)
- `HybridISOFileInput` — me · 2026-12-15 · wire or delete (ImageKit/HybridISO9660Writer.swift)
- `HybridSynthesizedISOImage` — me · 2026-12-15 · wire or delete (ImageKit/HybridISO9660Writer.swift)
- `KroutonConsoleMasteringConfig` — me · 2026-12-15 · wire or delete (OpticalCore/Models/OpticalMasteringDomainModels.swift)
- `KroutonDiscHubGeometry` — me · 2026-12-15 · wire or delete (LabelKit/LabelGeometry.swift)
- `KroutonDiscReadbackVerifier` — me · 2026-12-15 · wire or delete (DriveKit/KroutonDiscImageBurner.swift)
- `KroutonHybridISO9660Writer` — me · 2026-12-15 · wire or delete (ImageKit/HybridISO9660Writer.swift)
- `KroutonTrackAutoIdentifier` — me · 2026-12-15 · wire or delete (AudioKit/AudioEngine.swift)
- `PeakPyramid` — me · 2026-12-15 · wire or delete (AudioKit/HonestTrackData.swift)

## Test doubles shipped in production libraries (move to a test-support target)

- `ScriptedOpticalDrive` — me · 2026-12-15 · wire or delete (BurnKit/BurnSetScheduler.swift)

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
- `SpoolBurnMode` — me · 2027-01-31 · make internal or keep (NetworkSpool/NetworkSpoolWireModels.swift)
- `SpoolDiscMedia` — me · 2027-01-31 · make internal or keep (NetworkSpool/NetworkSpoolWireModels.swift)
- `TrackMetadata` — me · 2027-01-31 · make internal or keep (AudioKit/HonestTrackData.swift)
