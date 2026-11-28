# Naming and structure

Written 2026-11-28. A plan, not yet applied: several PRs are open, and renaming under them would
make every one of them conflict. When they've merged, `Scripts/apply-renames.py` applies the
renames below from `Scripts/renames.tsv`, one module per PR (see [Sequencing](#sequencing)).

## The rules

1. **Name a thing for what it is or does, in the words the app and the manual use.** No themes:
   a destination card is `DestinationCard`, not `KroutonBakeBatchItem`. Suite 1 already bans food
   words in type names (`Toast`, `Recipe`, `Crust`…); the themed names that got past it
   (`Bake`, `Kitchen`, `Roast`, `Garnish`, `Crouton`, `Foosh`) go too.
2. **One name per concept.** The crossfade editor is *Splice* in code (`SpliceWorkspaceView`,
   `SpliceOverlapMath`), so `TrackMontageWindowState` becomes `SpliceWindowState`. The manual's
   "Track Montage Editor" is the window title; the glossary should say they're the same thing.
3. **The module is the namespace: no `Krouton` prefix on types.** Half the code already does
   without it (`AudioProject`, `SpliceWorkspaceView`, `BurnSetScheduler`), and most file names
   already drop it (`UDFImageWriter.swift` holds `KroutonUDFImageWriter`). Keep `Krouton` only
   where it names the product or the system stores it:
   - `KroutonApp`, `KroutonDomainIdentity`, `KroutonEntryPoint` (public, called by `KroutonMain`
     and the Xcode target);
   - every App Intents type (`KroutonStatusIntent`, `KroutonShortcutsProvider`…) and the Live
     Activity's `KroutonBurnAttributes`: the system keeps their names in people's shortcuts;
   - `KroutonL10n`, which `Scripts/extract-strings.py` finds by name.
   Where the bare word is too generic or would shadow an SDK type, pick a descriptive name instead:
   `KroutonPreferenceKey` → `DefaultsKey` (not `PreferenceKey`, which is SwiftUI's),
   `KroutonDiskArbitration` → `DiscUnmounter` (not the framework's name), `KroutonSector` → `DataSector`.
   Domain prefixes that say what something is stay: `Spool…` in NetworkSpool, `MMC…`, `UDF…`, `HFS…`.
4. **Suffixes say the role:**
   - `View`, `Sheet`, `Popover`, `Bar`, `Canvas`, `Modifier`, `Style`: SwiftUI pieces.
   - `Controller`: an `@Observable @MainActor` class that owns one area's live state and actions
     (`AudioProjectController`, `RescueController`, and `DriveController` for the drives).
   - `Store`: owns state and keeps it (`SessionStore`, `StateStore`, `LabelWorkspaceStore`).
   - `Writer`/`Reader`/`Parser`/`Scanner`/`Analyzer`/`Verifier`/`Renderer`/`Builder`: does that to
     bytes or files. `Planner`: pure calculation that returns a plan (`DiscPlanner`, `VideoDiscPlanner`).
   - `Policy`: decides (`BurnMediaPolicy`, `RescuePolicy`). `Bridge`: wraps a platform API
     (`AppKitBridge`, `OSDesktopBridge`).
   - Not `Engine`, `Manager`, `Service`, `Helper`, `Bank`, `Station`, `Vault`: they say nothing.
     A caseless enum of static functions is named for its subject (`LabelGeometry`, `RedBookAudio`,
     `ColorMath`), not `…Engine`.
5. **Files are named for their main type**, and `Type+Role.swift` holds an extension of `Type`
   (Suite 2 checks the pairing). A file that holds several unrelated types is split, each into
   `TypeName.swift`. A file holds one subject: `MediaProbe.swift` doesn't also hold colour maths.
6. **Identifiers are spelt in US English**, like Apple's APIs (`Color`, `center`, `analyze`,
   `catalog`). Prose, comments and interface text keep the house style.
7. **Functions follow the Swift API Design Guidelines**: no `get`; `make…` for factories;
   imperative verbs for side effects (`burn`, `eject`, `writeLabelFiles`); nouns for pure results
   (`bitrateBudget(…)` rather than `computeBitrateBudget`, `timecode(frames:)` rather than
   `formatFramesToMMSSFF`). These member renames aren't in the table yet: they touch public API
   names one at a time and belong in each module's own clean-up.
8. **Never rename what is saved.** Raw values, Codable property names, `CodingKeys`, UserDefaults
   keys (`krouton.pref.*`), window ids (`"track-montage"`), notification voice ids
   (`"toaster-ding"`) and the `.krut` schema stay as they are. Renaming the *type* that holds them
   is safe; renaming a case or stored property isn't, and the script refuses one unless the row
   says why it's safe.

## The 15 renames that help a newcomer most

| Old | New | Why |
|---|---|---|
| `KroutonBakeBatchItem` | `DestinationCard` | the queue's cards; used 50 times |
| `KroutonOpticalDriveBank` (+ `driveManager`) | `DriveController` (+ `driveController`) | the owner of every drive; "Bank" says nothing; 371 variable uses |
| `KroutonStateStore` | `StateStore` | the app's root store; prefix only |
| `KroutonBurnDestinationKind` | `DestinationKind` | pairs with `DestinationCard` |
| `KroutonMasteringStation` | `SidebarGroup` | the sidebar's top-level groups |
| `KroutonKitchenEventRow` | `NotificationEventSetting` | a row of Settings › Notifications |
| `KroutonRoastAppearanceMode` | `AppearanceMode` | Light/Dark/Auto |
| `KroutonGarnishStyleMode` | `IconStyle` | the icon style setting |
| `KroutonCroutonLabelStyle` | `LabelTemplate` | label template; also misspelt |
| `KroutonStage1Tool` | `LabelTool` | the label designer's tools |
| `KroutonLabelGeometryEngine` | `LabelGeometry` | matches its eight `LabelGeometry+…` files |
| `KroutonDiscImageDepot` / `DiscImageDepotOperations` | `DiscImageClassifier` / `DiscImageInspector` | ImageKit's cue parser and image inspection, unrelated to the Depot downloads |
| `TrackMontageWindowState` (in `SpliceDragController.swift`) | `SpliceWindowState` (in `SpliceWindowState.swift`) | one name for the editor, file named for its type |
| `KroutonAcousticCue` / `KroutonAcousticEngine` | `SoundCue` / `SoundCuePlayer` | UI sounds and what plays them |
| `KroutonTestHarness` | `VerifyHarness` | matches its 29 `VerifyHarness+…` files and CLAUDE.md |

## Every rename

`Scripts/renames.tsv` is the machine-readable version of these tables, and the source of truth.
Tiers: **1** names that hide what a thing is; **2** files named for something else, and suffixes;
**3** spelling; **4** the mechanical prefix drop. Within a module, rows are ranked by tier.

The *Hazards* column is what `apply-renames.py --report` found for each row, checked by hand:

- **string-matched by krouton-verify**: a suite searches the source for the name (for example
  `combinedSrc.contains("KroutonMasteringDeckCard")`). The script rewrites the search string with
  the code, so the suite keeps passing; a hand rename that missed it would fail CI.
- **path string**: a suite opens or matches a file by path; the script renames the file and the
  path together.
- **persisted**: the type's raw values or Codable keys are saved. The type's own name isn't saved,
  so the rename is safe; its cases and stored properties must not change.
- **name in verify messages**: only a check's message names the type; rewritten.
### Curated renames (tiers 1–3), by module

#### KroutonApp

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `KroutonBakeBatchItem` → `DestinationCard` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | A destination card in the queue; nothing is baked. Pairs with DestinationCardView | **persisted**: Codable in sessions and queues: property names are keys, unchanged |
| 2 | 1 | `KroutonKitchenEventRow` → `NotificationEventSetting` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | One row of Settings › Notifications: an event and its banner/sound | **persisted**: its Saved JSON (notificationEvents) keys unchanged |
| 3 | 1 | `KroutonRoastAppearanceMode` → `AppearanceMode` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | Light/Dark/Auto appearance | **persisted**: raw values saved (krouton.pref.appearanceMode): keep cases |
| 4 | 1 | `KroutonGarnishStyleMode` → `IconStyle` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | The icon style setting (Default/Dark/Clear/Tinted), stored as iconWidgetStyle | **persisted**: raw values saved (iconWidgetStyle): keep cases |
| 5 | 1 | `KroutonCroutonLabelStyle` → `LabelTemplate` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | Label template (pref key labelTemplate); "Crouton" was also a misspelling of Krouton | **persisted**: raw values saved (labelTemplate, project labelTemplateRaw): keep cases |
| 6 | 1 | `KroutonStage1Tool` → `LabelTool` | type | KroutonApp/Features/Label/DiscLabelWorkspace.swift | A tool in the label designer's tool rail; "Stage 1" is a leftover build phase | — |
| 7 | 1 | `KroutonMasteringStation` → `SidebarGroup` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | The sidebar's top-level groups (Burn, Depot, Copy, Label) | **persisted**: raw values saved (selectedCategoryRaw in sessions and projects): keep cases |
| 8 | 1 | `TrackMontageWindowState` → `SpliceWindowState` | type | KroutonApp/Features/AudioCD/Splice/SpliceDragController.swift | The Splice editor's window state; code calls the editor Splice everywhere else | **persisted**: window id "track-montage" (state restoration) stays |
| 9 | 1 | `KroutonFloatingTrackMontageWindowView` → `SpliceFloatingWindowView` | type | KroutonApp/Features/AudioCD/Splice/SpliceWorkspaceView.swift | The popped-out Splice editor window | **persisted**: window id "track-montage" stays |
| 10 | 1 | `KroutonGPUFooshTransitionModifier` → `SplicePopOutTransition` | type | KroutonApp/Features/AudioCD/Splice/SpliceDragController.swift | The pop-out/dock animation of the Splice editor | — |
| 11 | 1 | `fooshPhase` → `popOutPhase` | member | KroutonApp/Features/AudioCD/Splice/SpliceDragController.swift | Progress of the pop-out animation | — |
| 12 | 1 | `triggerFooshTransition` → `animatePopOut` | member | KroutonApp/Features/AudioCD/Splice/SpliceDragController.swift | Runs the pop-out animation | — |
| 13 | 1 | `KroutonAcousticCue` → `SoundCue` | type | KroutonApp/Shell/Services/KroutonAcousticCue.swift | A UI sound: a synth preset or system sound plus effects | — |
| 14 | 1 | `KroutonAcousticEngine` → `SoundCuePlayer` | type | KroutonApp/Shell/Services/KroutonAcousticEngine.swift | Plays SoundCues | — |
| 15 | 1 | `KroutonAcousticSoundboardCardView` → `SoundCueBoardView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonAcousticSoundboardCardView.swift | Settings card that previews every sound cue | — |
| 16 | 1 | `toasterDing` → `successChord` | case | KroutonApp/Shell/Services/KroutonAcousticCue.swift | Synth preset played when a burn or rip finishes | **persisted check**: implicit raw values, but rawValue is never read or saved |
| 17 | 1 | `burntToastGuard` → `refusalBuzz` | case | KroutonApp/Shell/Services/KroutonAcousticCue.swift | Synth preset played when a drop or burn is refused | **persisted check**: implicit raw values, but rawValue is never read or saved |
| 18 | 1 | `KroutonNotificationAndCompanionService` → `NotificationPoster` | type | KroutonApp/Shell/Services/KroutonNotificationAndCompanionService.swift | Posts banners, sounds and VoiceOver announcements; there is no companion app | path string in krouton-verify (rewritten with the file) |
| 19 | 1 | `KroutonWindowManager` → `WindowRouter` | type | KroutonApp/Shell/App/KroutonWindowManager.swift | Opens and closes the app's windows | — |
| 20 | 1 | `KroutonDepotAppStoreCardView` → `DepotItemCardView` | type | KroutonApp/Features/Depot/KroutonDepotCatalogViews.swift | A Depot item's card; "AppStore" reads as Apple's App Store | — |
| 21 | 1 | `KroutonPreferenceKey` → `DefaultsKey` | type | KroutonApp/Shell/StateAndModels/AppearancePreferences.swift | A UserDefaults key; the bare name PreferenceKey would shadow SwiftUI's | **persisted**: raw values are the UserDefaults keys krouton.pref.*: unchanged |
| 22 | 1 | `KroutonPreferences` → `Defaults` | type | KroutonApp/Shell/StateAndModels/AppearancePreferences.swift | Typed UserDefaults access | name in verify messages or strings (rewritten) |
| 23 | 1 | `NetworkSpoolDriveCardSectionView` → `ServerDriveSectionView` | type | KroutonApp/Shell/NavigationAndRack/KroutonDestinationSubViews.swift | The Krouton Server part of a destination card | — |
| 24 | 1 | `SpoolPlainTextFileDocument` → `PlainTextFileDocument` | type | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsControlsAndDocuments.swift | An app FileDocument, not part of NetworkSpool | — |
| 25 | 1 | `KroutonBurnStationWorkspaceView` → `BurnWorkspaceView` | type | KroutonApp/Shell/NavigationAndRack/KroutonBurnStationWorkspaceView.swift | The Burn group's workspace | — |
| 26 | 1 | `KroutonCentralWorkspaceCapacityBarView` → `CapacityBarView` | type | KroutonApp/Shell/NavigationAndRack/KroutonCentralWorkspaceCapacityBarView.swift | The disc capacity bar | — |
| 27 | 1 | `KroutonLeftFormatChooserColumnView` → `FormatChooserColumnView` | type | KroutonApp/Shell/NavigationAndRack/KroutonNavigationAndTelemetryBars.swift | The format chooser column | — |
| 28 | 1 | `AutoLabelEngine` → `AutoLabelStoreAdapter` | type | KroutonApp/Features/Label/AutoLabelStoreAdapter.swift | Matches its file; LabelKit's AutoLabelComposer does the work | — |
| 29 | 1 | `KroutonBurnDestinationKind` → `DestinationKind` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | What a DestinationCard does; pairs with DestinationCard | name in verify messages or strings (rewritten); **persisted**: raw values saved, plus pre-2026-11-27 aliases: keep cases |
| 30 | 2 | `SpliceDragController.swift` → `SpliceWindowState.swift` | file | KroutonApp/Features/AudioCD/Splice/SpliceDragController.swift | Holds the window state (split SpliceDragModifier into its own file by hand) | — |
| 31 | 2 | `SpliceAuditioner.swift` → `SpliceAudioAuditioner.swift` | file | KroutonApp/Features/AudioCD/Splice/SpliceAuditioner.swift | Matches its type | — |
| 32 | 2 | `DataDiscSpanningHeaderView.swift` → `DataDiscHeaderBannerView.swift` | file | KroutonApp/Features/Data/DataDiscSpanningHeaderView.swift | Matches its type | — |
| 33 | 2 | `KroutonDepotCatalogViews.swift` → `DepotItemCardView.swift` | file | KroutonApp/Features/Depot/KroutonDepotCatalogViews.swift | Matches its type | — |
| 34 | 2 | `KroutonDepotHeroStudio.swift` → `WorkflowBlueprintView.swift` | file | KroutonApp/Features/Depot/KroutonDepotHeroStudio.swift | Matches its type | — |
| 35 | 2 | `KroutonFloatingPhaseScopeWindow.swift` → `FloatingPhaseScopeView.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonFloatingPhaseScopeWindow.swift | Matches its type | — |
| 36 | 2 | `KroutonNavigationAndTelemetryBars.swift` → `FormatChooserColumnView.swift` | file | KroutonApp/Shell/NavigationAndRack/KroutonNavigationAndTelemetryBars.swift | Holds only the format chooser column | — |
| 37 | 2 | `KroutonDestinationSubViews.swift` → `DestinationRackColumnView.swift` | file | KroutonApp/Shell/NavigationAndRack/KroutonDestinationSubViews.swift | Named for its main type | — |
| 38 | 2 | `KroutonDestinationSubViews+WaitingPool.swift` → `DestinationRackColumnView+WaitingPool.swift` | file | KroutonApp/Shell/NavigationAndRack/KroutonDestinationSubViews+WaitingPool.swift | Pairs with DestinationRackColumnView.swift | — |
| 39 | 2 | `KroutonProjectAndSessionVault.swift` → `ProjectFile.swift` | file | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | The .krut project file: manifest, records, document | — |
| 40 | 2 | `KroutonProjectAndSessionVault+OpenProject.swift` → `ProjectFile+OpenProject.swift` | file | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault+OpenProject.swift | Pairs with ProjectFile.swift | — |
| 41 | 2 | `KroutonSessionPersistence.swift` → `SessionSnapshot.swift` | file | KroutonApp/Shell/StateAndModels/KroutonSessionPersistence.swift | The saved session and crash recovery (move its banner view to ModalsAndSettings by hand) | — |
| 42 | 2 | `KroutonObservableFeatureStores.swift` → `FeatureStores.swift` | file | KroutonApp/Shell/StateAndModels/KroutonObservableFeatureStores.swift | The sub-stores | — |
| 43 | 2 | `KroutonAuxModalsAndScopes.swift` → `MasteringReportSheet.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonAuxModalsAndScopes.swift | Holds the report sheet, disc artwork and media popover; no scopes | — |
| 44 | 2 | `KroutonSettingsControlsAndDocuments.swift` → `SettingsControls.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsControlsAndDocuments.swift | Settings' small controls | — |
| 45 | 2 | `KroutonThemeEngine.swift` → `ColorHarmony.swift` | file | KroutonApp/Shell/DesignSystem/KroutonThemeEngine.swift | Colour harmony table and Color helpers; no engine | — |
| 46 | 2 | `KroutonLabelWorkspaceSubStore` → `LabelWorkspaceStore` | type | KroutonApp/Shell/StateAndModels/KroutonObservableFeatureStores.swift | Store suffix like the others; "Sub" is implied by being a child | — |
| 47 | 2 | `KroutonBurnQueueSubStore` → `BurnQueueStore` | type | KroutonApp/Shell/StateAndModels/KroutonObservableFeatureStores.swift | As above | — |
| 48 | 2 | `KroutonGuidedTutorialController` → `TutorialController` | type | KroutonApp/Shell/ModalsAndSettings/KroutonGuidedTutorialController.swift | Shorter, same meaning | — |
| 49 | 2 | `KroutonGuidedTutorialOverlayView` → `TutorialOverlayView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonGuidedTutorialOverlayView.swift | Pairs with TutorialController | — |
| 50 | 2 | `KroutonDualHarmonySwitch` → `HarmonyToggle` | type | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsControlsAndDocuments.swift | A Toggle look; Switch is AppKit's word | — |
| 51 | 2 | `KroutonDesign` → `DesignTokens` | type | KroutonApp/Shell/DesignSystem/KroutonDesignSystem.swift | Radii and type sizes; Design alone is too generic | — |
| 52 | 2 | `KroutonLanguage` → `AppLanguage` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | The interface language setting (pref key appLanguage) | **persisted**: raw values saved (appLanguage) |
| 53 | 3 | `DepotCatalogue` → `DepotCatalog` | type | KroutonApp/Shell/StateAndModels/DepotCatalogue.swift | US spelling, as in DepotCatalogItem | **string-matched by krouton-verify** (search string rewritten) |

#### OpticalCore

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `KroutonMediaPrepEngine` → `MediaProbe` | type | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | probeFile: what a media file is and how it will decode | — |
| 2 | 1 | `KroutonStreamProbeResult` → `MediaProbeResult` | type | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | What MediaProbe found | — |
| 3 | 1 | `KroutonHeatTier` → `DecoderPath` | type | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | Which decoder path a file takes (VideoToolbox, vDSP, passthrough) | — |
| 4 | 1 | `KroutonElToritoBootInspector` → `SectorInspector` | type | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | Hex dumps and SHA-256 of sectors, not just El Torito | — |
| 5 | 1 | `KroutonPureColorMath` → `ColorMath` | type | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | sRGB/HSB/P3 colour maths | — |
| 6 | 1 | `KroutonKrutSecurityEngine` → `KrutSecurity` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | .krut project path safety and payload sealing | — |
| 7 | 1 | `DiscSpanningEngine` → `ManualDiscBreaks` | type | OpticalCore/Spanning/DiscSpanningEngine.swift | Toggles manual disc breaks; DiscPlanner does the spanning | name in verify messages or strings (rewritten) |
| 8 | 1 | `BurnPoolQueue.swift` → `BurnPoolTickets.swift` | file | OpticalCore/Burning/BurnPoolQueue.swift | Tickets, dispatch mode, drive state and the claim ledger | — |
| 9 | 2 | `MultiDiscSpanner.swift` → `SpanningDiscMedium.swift` | file | OpticalCore/Models/MultiDiscSpanner.swift | There is no spanner in it: the disc medium and volume metadata | — |
| 10 | 2 | `KroutonMediaPrepAndColorEngine.swift` → `MediaProbe.swift` | file | OpticalCore/InspectorsAndPrep/KroutonMediaPrepAndColorEngine.swift | Named for its main type (split SectorInspector and ColorMath out by hand) | — |
| 11 | 2 | `KroutonBytes` → `ByteOrder` | type | OpticalCore/Bytes/ByteOrder.swift | Matches its file; reads ByteOrder.u32be | — |
| 12 | 2 | `KroutonPrimitive` → `PersistedPrimitive` | type | OpticalCore/Codable/PersistedDecoder.swift | Pairs with PersistedDecoder; Primitive alone is too generic | — |
| 13 | 2 | `KroutonSector` → `DataSector` | type | OpticalCore/DriveCommands/SectorSource.swift | DataSector.size = 2048; Sector alone is too generic | — |
| 14 | 2 | `KroutonDiagnostics` → `DiagnosticLog` | type | OpticalCore/Models/OpticalDriveControlling.swift | Holds the os.Logger | — |

#### DriveKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `KroutonOpticalDriveBank` → `DriveController` | type | DriveKit/KroutonOpticalDriveBank.swift | The @Observable owner of this Mac's drives and their burns; "Bank" says nothing | — |
| 2 | 1 | `driveManager` → `driveController` | member | KroutonApp/Shell/Workspace/KroutonMainWorkspaceView.swift | The variable that holds the DriveController (371 uses) | — |
| 3 | 1 | `neroSamples` → `speedSamples` | member | DriveKit/KroutonOpticalDriveBank.swift | Write-speed samples; named after a competitor's product | — |
| 4 | 1 | `KroutonBurnStager` → `BurnFolderStager` | type | DriveKit/KroutonBurnPreflight.swift | Copies files into the burn folder; BurnKit has another stager (BurnSetStager) | — |
| 5 | 2 | `KroutonDiskArbitration` → `DiscUnmounter` | type | DriveKit/KroutonDiskArbitration.swift | Lets go of a mounted disc; DiskArbitration is the framework it imports | — |

#### BurnKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `BurnQueuePool.swift` → `BurnPool.swift` | file | BurnKit/BurnQueuePool.swift | BurnQueuePool.swift (BurnKit) and BurnPoolQueue.swift (OpticalCore) were mirror names | — |
| 2 | 1 | `KroutonBurnQueuePool` → `BurnPool` | type | BurnKit/BurnQueuePool.swift | The destination queue's pool of burner cards and tickets | — |
| 3 | 1 | `KroutonPoolSlotCard` → `BurnPoolCard` | type | BurnKit/BurnQueuePool.swift | A burner card as the pool sees it | — |

#### ImageKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `DiscImageDepot.swift` → `DiscImageClassifier.swift` | file | ImageKit/DiscImageDepot.swift | Holds the cue parser and image classifier, not the Depot | — |
| 2 | 1 | `KroutonDiscImageDepot` → `DiscImageClassifier` | type | ImageKit/DiscImageDepot.swift | Parses cue sheets and classifies images; unrelated to the Disc Image Depot downloads | — |
| 3 | 1 | `DiscImageDepotOperations` → `DiscImageInspector` | type | ImageKit/DiscImageDepotOperations.swift | inspectImageFile and archive operations on a local image | name in verify messages or strings (rewritten); NSError domain string changes |
| 4 | 2 | `KroutonBDMVFolder` → `BDMVFolderCheck` | type | ImageKit/BDMVFolderCheck.swift | Matches its file; it checks a folder | — |
| 5 | 2 | `KroutonParityWriter` → `ParityRecoveryWriter` | type | ImageKit/ParityRecoveryWriter.swift | Matches its file | — |

#### AudioKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `AudioEngine.swift` → `RedBookAudio.swift` | file | AudioKit/AudioEngine.swift | The file holds Red Book maths, CD-Text packs and the cue compiler | — |
| 2 | 1 | `KroutonAudioEngine` → `RedBookAudio` | type | AudioKit/AudioEngine.swift | Timecode, crossfade gains, CD-Text packs, cue sheet: Red Book helpers, not an engine | — |
| 3 | 1 | `KroutonRealCDExtractor` → `MountedAudioCDReader` | type | AudioKit/AudioSampleDecoder.swift | Reads tracks from the audio CD macOS has mounted; "Real" says nothing | name in verify messages or strings (rewritten); NSError domain string changes |
| 4 | 2 | `HonestTrackData.swift` → `TrackMetadata.swift` | file | AudioKit/HonestTrackData.swift | Named for its main type | — |
| 5 | 3 | `analyse` → `analyze` | member | AudioKit/AudioAnalysisService.swift | US spelling, as in M2TSAnalyzer. The new name is used elsewhere by an unrelated member; no clash in the same scope | — |
| 6 | 3 | `notAnalysed` → `notAnalyzed` | case | AudioKit/AudioProject.swift | US spelling | — |

#### VideoKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `VideoAuthoringEngine.swift` → `VideoDiscPlanner.swift` | file | VideoKit/VideoAuthoringEngine.swift | Bitrate budgets and the DVD-9 shrink plan | — |
| 2 | 1 | `VideoAuthoringEngine+Shrink.swift` → `VideoDiscPlanner+Shrink.swift` | file | VideoKit/VideoAuthoringEngine+Shrink.swift | Pairs with VideoDiscPlanner.swift | — |
| 3 | 1 | `KroutonVideoAuthoringEngine` → `VideoDiscPlanner` | type | VideoKit/VideoAuthoringEngine.swift | Plans bitrates and the DVD-9 -> DVD-5 shrink; writes nothing | — |
| 4 | 1 | `AVCHDOnDVDAuthoringEngine.swift` → `AVCHDAuthoring.swift` | file | VideoKit/AVCHDOnDVDAuthoringEngine.swift | Follows the type | — |
| 5 | 1 | `AVCHDOnDVDAuthoringEngine` → `AVCHDAuthoring` | type | VideoKit/AVCHDOnDVDAuthoringEngine.swift | Builds AVCHD (BD-on-DVD) folders | — |
| 6 | 1 | `KroutonBEWriter` → `BigEndianWriter` | type | VideoKit/BDMVNavigationWriter.swift | Big-endian byte and bit writer | — |
| 7 | 3 | `ifoBup32KECCPaddingSectors` → `ifoToBackupPaddingSectors` | member | VideoKit/VideoAuthoringEngine.swift | "32KECC" read as a word; the doc comment gives the size | — |

#### LabelKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `KroutonLabelGeometryEngine` → `LabelGeometry` | type | LabelKit/LabelGeometry.swift | Label geometry and rendering functions; its files are already LabelGeometry+Role.swift | name in verify messages or strings (rewritten) |
| 2 | 1 | `AutoLabelEngine.swift` → `AutoLabelComposer.swift` | file | LabelKit/AutoLabelEngine.swift | Holds AutoLabelComposer; the app's adapter was called AutoLabelEngine | — |

#### RescueKit

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `RescueEngine.swift` → `RescuePolicy.swift` | file | RescueKit/RescueEngine.swift | Follows the type | — |
| 2 | 1 | `KroutonRescueEngine` → `RescuePolicy` | type | RescueKit/RescueEngine.swift | What to do with each sector, and the archival grade | — |

#### NetworkSpool

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `SpoolLANSecurityEngine` → `SpoolHostCheck` | type | NetworkSpool/SpoolTelemetry.swift | Checks a typed host is on the local network before connecting | name in verify messages or strings (rewritten) |
| 2 | 2 | `SpoolExtentPipeline.swift` → `SpoolUploadSender.swift` | file | NetworkSpool/SpoolExtentPipeline.swift | Matches its type | — |

#### KroutonVerify

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 1 | `KroutonTestHarness` → `VerifyHarness` | type | KroutonVerify/VerifyHarness.swift | Matches its files (VerifyHarness+Suite.swift) and CLAUDE.md | — |
| 2 | 3 | `centre` → `center` | member | KroutonVerify/VerifyHarness+PlanetChecks.swift | US spelling. The new name is used elsewhere by an unrelated member; no clash in the same scope | word in UI text (left alone) |

#### Tests

| # | Tier | Old → New | Kind | Declared in | Why | Hazards |
|---|---|---|---|---|---|---|
| 1 | 3 | `testDMGOutputHonoursCompression` → `testDMGOutputHonorsCompression` | member | Tests/BurnKitTests/DiscImageArgumentsTests.swift | US spelling | — |

### Tier 4 — the prefix drop, by module

Each row drops `Krouton` and nothing else (the file rows rename files whose names keep the prefix but match no type).

#### KroutonApp (120)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonDigitsOnlyTextField` → `DigitsOnlyTextField` | type | KroutonApp/Features/AudioCD/AudioMasteringBatchAndDiscViews.swift | — |
| `KroutonRedBookAudioWorkspaceView` → `RedBookAudioWorkspaceView` | type | KroutonApp/Features/AudioCD/AudioMasteringWorkspaces.swift | — |
| `KroutonCarSafeAudioWorkspaceView` → `CarSafeAudioWorkspaceView` | type | KroutonApp/Features/AudioCD/CarSafeAudioWorkspace.swift | — |
| `KroutonDataAndArchivalWorkspaceView` → `DataAndArchivalWorkspaceView` | type | KroutonApp/Features/Data/DataAndArchivalWorkspaces.swift | — |
| `KroutonDiscImageInspectorWorkspaceView` → `DiscImageInspectorWorkspaceView` | type | KroutonApp/Features/Data/DiscImageInspectorWorkspace.swift | — |
| `KroutonFinderDiscStageView` → `FinderDiscStageView` | type | KroutonApp/Features/Data/FinderDiscStageView.swift | — |
| `KroutonFinderViewOptionsPopover` → `FinderViewOptionsPopover` | type | KroutonApp/Features/Data/FinderViewOptionsPopover.swift | — |
| `KroutonHybridLBAMapPopoverView` → `HybridLBAMapPopoverView` | type | KroutonApp/Features/Data/MasteringTelemetryPopovers.swift | — |
| `KroutonAudioCuePopoverView` → `AudioCuePopoverView` | type | KroutonApp/Features/Data/MasteringTelemetryPopovers.swift | — |
| `KroutonVideoBitratePopoverView` → `VideoBitratePopoverView` | type | KroutonApp/Features/Data/MasteringTelemetryPopovers.swift | — |
| `KroutonHeroTextOutlineModifier` → `HeroTextOutlineModifier` | type | KroutonApp/Features/Depot/KroutonDepotHeroBannerView.swift | — |
| `KroutonDepotHeroBannerView` → `DepotHeroBannerView` | type | KroutonApp/Features/Depot/KroutonDepotHeroBannerView.swift | — |
| `KroutonWorkflowBlueprintView` → `WorkflowBlueprintView` | type | KroutonApp/Features/Depot/KroutonDepotHeroStudio.swift | — |
| `KroutonDepotWorkspaceView` → `DepotWorkspaceView` | type | KroutonApp/Features/Depot/KroutonDepotWorkspaceView.swift | — |
| `KroutonDiscLabelWorkspaceView` → `DiscLabelWorkspaceView` | type | KroutonApp/Features/Label/DiscLabelWorkspace.swift | — |
| `KroutonDiscLabelArtworkCanvas` → `DiscLabelArtworkCanvas` | type | KroutonApp/Features/Label/KroutonDiscLabelArtworkCanvas.swift | — |
| `KroutonRetroConsoleWorkspaceView` → `RetroConsoleWorkspaceView` | type | KroutonApp/Features/Retro/RetroConsoleWorkspaces.swift | — |
| `KroutonRipCancelToken` → `RipCancelToken` | type | KroutonApp/Features/Rip/CopyAndRipWorkspaces.swift | — |
| `KroutonCopyAndRipWorkspaceView` → `CopyAndRipWorkspaceView` | type | KroutonApp/Features/Rip/CopyAndRipWorkspaces.swift | — |
| `KroutonRipTrackOutcome` → `RipTrackOutcome` | type | KroutonApp/Features/Rip/CopyAndRipWorkspaces.swift | — |
| `KroutonAVCHDPanelView` → `AVCHDPanelView` | type | KroutonApp/Features/Video/AVCHDPanelView.swift | — |
| `KroutonVideoAuthoringWorkspaceView` → `VideoAuthoringWorkspaceView` | type | KroutonApp/Features/Video/VideoAuthoringWorkspaces.swift | — |
| `KroutonAppKitBridge` → `AppKitBridge` | type | KroutonApp/Shell/App/KroutonAppKitBridge.swift | path string in krouton-verify (rewritten with the file) |
| `KroutonAppDelegate` → `AppDelegate` | type | KroutonApp/Shell/App/KroutonAppKitBridge.swift | objc class name changes (not archived) |
| `KroutonMenuBarStatusLabel` → `MenuBarStatusLabel` | type | KroutonApp/Shell/App/KroutonMenuBarStatusView.swift | — |
| `KroutonMenuBarStatusView` → `MenuBarStatusView` | type | KroutonApp/Shell/App/KroutonMenuBarStatusView.swift | — |
| `KroutonWorkspaceCommands` → `WorkspaceCommands` | type | KroutonApp/Shell/App/KroutonMenuCommands.swift | — |
| `KroutonImporterIntent` → `ImporterIntent` | type | KroutonApp/Shell/App/KroutonStageImporter.swift | — |
| `KroutonStageImporterBridge` → `StageImporterBridge` | type | KroutonApp/Shell/App/KroutonStageImporter.swift | — |
| `KroutonStageImporterModifier` → `StageImporterModifier` | type | KroutonApp/Shell/App/KroutonStageImporter.swift | — |
| `KroutonSceneActionBinder` → `SceneActionBinder` | type | KroutonApp/Shell/App/KroutonWindowManager.swift | — |
| `KroutonCLIRunner` → `CLIRunner` | type | KroutonApp/Shell/CLI/KroutonCLIRunner.swift | path string in krouton-verify (rewritten with the file) |
| `KroutonBrandLogoView` → `BrandLogoView` | type | KroutonApp/Shell/DesignSystem/KroutonBrandLogoView.swift | — |
| `KroutonPillMetrics` → `PillMetrics` | type | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonPillButtonStyle` → `PillButtonStyle` | type | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonPillPicker` → `PillPicker` | type | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonTogglePill` → `TogglePill` | type | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonReadoutStyle` → `ReadoutStyle` | type | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonMasteringDeckCard` → `MasteringDeckCard` | type | KroutonApp/Shell/DesignSystem/KroutonSharedWorkspaceComponents.swift | **string-matched by krouton-verify** (search string rewritten) |
| `KroutonEmptyDropZoneView` → `EmptyDropZoneView` | type | KroutonApp/Shell/DesignSystem/KroutonSharedWorkspaceComponents.swift | **string-matched by krouton-verify** (search string rewritten) |
| `KroutonStyledIconBadge` → `StyledIconBadge` | type | KroutonApp/Shell/DesignSystem/KroutonStyledIconBadge.swift | — |
| `KroutonColorHarmonyLUT` → `ColorHarmonyLUT` | type | KroutonApp/Shell/DesignSystem/KroutonThemeEngine.swift | — |
| `KroutonDiscArtworkView` → `DiscArtworkView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonAuxModalsAndScopes.swift | — |
| `KroutonDiscMediaPopover` → `DiscMediaPopover` | type | KroutonApp/Shell/ModalsAndSettings/KroutonAuxModalsAndScopes.swift | — |
| `KroutonMasteringReportSheet` → `MasteringReportSheet` | type | KroutonApp/Shell/ModalsAndSettings/KroutonAuxModalsAndScopes.swift | — |
| `KroutonCloudSettingsRowView` → `CloudSettingsRowView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonCloudSettingsRowView.swift | — |
| `KroutonFloatingPhaseScopeView` → `FloatingPhaseScopeView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonFloatingPhaseScopeWindow.swift | — |
| `KroutonTutorialTargetZone` → `TutorialTargetZone` | type | KroutonApp/Shell/ModalsAndSettings/KroutonGuidedTutorialController.swift | — |
| `KroutonGuidedTutorialID` → `GuidedTutorialID` | type | KroutonApp/Shell/ModalsAndSettings/KroutonGuidedTutorialController.swift | — |
| `KroutonGuidedTutorialStep` → `GuidedTutorialStep` | type | KroutonApp/Shell/ModalsAndSettings/KroutonGuidedTutorialController.swift | — |
| `KroutonNotificationSoundControlView` → `NotificationSoundControlView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonNotificationSoundControlView.swift | — |
| `KroutonMiniPhaseScopeView` → `MiniPhaseScopeView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonPhaseScopeMiniViews.swift | — |
| `KroutonPairingCodeSheet` → `PairingCodeSheet` | type | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+BurnServersCard.swift | — |
| `KroutonSettingsCategory` → `SettingsCategory` | type | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow.swift | — |
| `KroutonSettingsWindowView` → `SettingsWindowView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow.swift | — |
| `KroutonStorageAndResetPaneView` → `StorageAndResetPaneView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonStorageAndResetPaneView.swift | — |
| `KroutonManualChapter` → `ManualChapter` | type | KroutonApp/Shell/ModalsAndSettings/KroutonUserManual.swift | — |
| `KroutonManualDocument` → `ManualDocument` | type | KroutonApp/Shell/ModalsAndSettings/KroutonUserManual.swift | named in Scripts/build-manual.py (rewritten) |
| `KroutonManualLibrary` → `ManualLibrary` | type | KroutonApp/Shell/ModalsAndSettings/KroutonUserManual.swift | — |
| `KroutonUserManualWindowView` → `UserManualWindowView` | type | KroutonApp/Shell/ModalsAndSettings/KroutonUserManualWindowView.swift | — |
| `KroutonBurnSetSheetView` → `BurnSetSheetView` | type | KroutonApp/Shell/NavigationAndRack/KroutonBurnSetSheetView.swift | path string in krouton-verify (rewritten with the file) |
| `KroutonDestinationCardView` → `DestinationCardView` | type | KroutonApp/Shell/NavigationAndRack/KroutonDestinationCardView.swift | — |
| `KroutonDiscImagePlaceholderDocument` → `DiscImagePlaceholderDocument` | type | KroutonApp/Shell/NavigationAndRack/KroutonDestinationCardView.swift | — |
| `KroutonDiscImageTargetRowView` → `DiscImageTargetRowView` | type | KroutonApp/Shell/NavigationAndRack/KroutonDestinationCardView.swift | — |
| `KroutonDestinationRackColumnView` → `DestinationRackColumnView` | type | KroutonApp/Shell/NavigationAndRack/KroutonDestinationSubViews.swift | — |
| `KroutonRipCodecPickerView` → `RipCodecPickerView` | type | KroutonApp/Shell/NavigationAndRack/KroutonRipCodecPickerView.swift | — |
| `KroutonBurnSetController` → `BurnSetController` | type | KroutonApp/Shell/Services/KroutonBurnSetController.swift | **string-matched by krouton-verify** (search string rewritten); path string in krouton-verify (rewritten with the file) |
| `KroutonCloudDocuments` → `CloudDocuments` | type | KroutonApp/Shell/Services/KroutonCloudDocuments.swift | — |
| `KroutonCloudSettings` → `CloudSettings` | type | KroutonApp/Shell/Services/KroutonCloudSettings.swift | — |
| `KroutonLabelSuggester` → `LabelSuggester` | type | KroutonApp/Shell/Services/KroutonLabelSuggester.swift | — |
| `KroutonLiveStatus` → `LiveStatus` | type | KroutonApp/Shell/Services/KroutonLiveStatus.swift | — |
| `KroutonMotionPreference` → `MotionPreference` | type | KroutonApp/Shell/Services/KroutonMotion.swift | — |
| `KroutonReduceMotionReader` → `ReduceMotionReader` | type | KroutonApp/Shell/Services/KroutonMotion.swift | — |
| `KroutonNotificationSound` → `NotificationSound` | type | KroutonApp/Shell/Services/KroutonNotificationSound.swift | **persisted**: Codable (notificationEvents) |
| `KroutonOSDesktopBridge` → `OSDesktopBridge` | type | KroutonApp/Shell/Services/KroutonOSDesktopBridge.swift | path string in krouton-verify (rewritten with the file) |
| `KroutonPowerAndBurnAssertion` → `PowerAndBurnAssertion` | type | KroutonApp/Shell/Services/KroutonPowerAndBurnAssertion.swift | — |
| `KroutonStorageAndReset` → `StorageAndReset` | type | KroutonApp/Shell/Services/KroutonStorageAndReset.swift | — |
| `KroutonWidgetBridge` → `WidgetBridge` | type | KroutonApp/Shell/Services/KroutonWidgetBridge.swift | — |
| `KroutonAVCHDController` → `AVCHDController` | type | KroutonApp/Shell/StateAndModels/KroutonAVCHDController.swift | — |
| `KroutonDepotFeed` → `DepotFeed` | type | KroutonApp/Shell/StateAndModels/KroutonDepotFeed.swift | — |
| `KroutonDepotDownloadError` → `DepotDownloadError` | type | KroutonApp/Shell/StateAndModels/KroutonDepotFeed.swift | — |
| `KroutonDepotDownloadProgress` → `DepotDownloadProgress` | type | KroutonApp/Shell/StateAndModels/KroutonDepotFeed.swift | objc class name changes (not archived) |
| `KroutonDepotDownloader` → `DepotDownloader` | type | KroutonApp/Shell/StateAndModels/KroutonDepotFeed.swift | — |
| `KroutonLabelCanvasSnapshot` → `LabelCanvasSnapshot` | type | KroutonApp/Shell/StateAndModels/KroutonObservableFeatureStores.swift | — |
| `KroutonProjectSourceRecord` → `ProjectSourceRecord` | type | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | **persisted**: Codable .krut |
| `KroutonSavedDestinationRecord` → `SavedDestinationRecord` | type | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | **persisted**: Codable .krut |
| `KroutonProjectManifest` → `ProjectManifest` | type | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | **persisted**: Codable .krut |
| `KroutonProjectFileDocument` → `ProjectFileDocument` | type | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | — |
| `KroutonProjectDialogBridge` → `ProjectDialogBridge` | type | KroutonApp/Shell/StateAndModels/KroutonProjectAndSessionVault.swift | — |
| `KroutonRescueController` → `RescueController` | type | KroutonApp/Shell/StateAndModels/KroutonRescueController.swift | — |
| `KroutonMapSaver` → `MapSaver` | type | KroutonApp/Shell/StateAndModels/KroutonRescueController.swift | — |
| `KroutonPersistedSessionSnapshot` → `PersistedSessionSnapshot` | type | KroutonApp/Shell/StateAndModels/KroutonSessionPersistence.swift | **persisted**: Codable session file |
| `KroutonCrashRecoveryController` → `CrashRecoveryController` | type | KroutonApp/Shell/StateAndModels/KroutonSessionPersistence.swift | — |
| `KroutonCrashRecoveryBannerView` → `CrashRecoveryBannerView` | type | KroutonApp/Shell/StateAndModels/KroutonSessionPersistence.swift | — |
| `KroutonAccentColorPreset` → `AccentColorPreset` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | **persisted**: ids saved (selectedAccentIndex) |
| `KroutonTrackIconSizeMode` → `TrackIconSizeMode` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | **persisted**: raw values saved (sidebarIconSize) |
| `KroutonStageFolderColorMode` → `StageFolderColorMode` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | **persisted**: raw values saved (folderColorMode) |
| `KroutonDepotCatalogItem` → `DepotCatalogItem` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | — |
| `KroutonDepotFeedSubscription` → `DepotFeedSubscription` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | — |
| `KroutonDiscLabelGeometry` → `DiscLabelGeometry` | type | KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift | — |
| `KroutonBurnInputError` → `BurnInputError` | type | KroutonApp/Shell/StateAndModels/KroutonStateStore+BurnInput.swift | — |
| `KroutonBluRayRootError` → `BluRayRootError` | type | KroutonApp/Shell/StateAndModels/KroutonStateStore+BurnSupport.swift | — |
| `KroutonStateStore` → `StateStore` | type | KroutonApp/Shell/StateAndModels/KroutonStateStore.swift | **string-matched by krouton-verify** (search string rewritten); path string in krouton-verify (rewritten with the file) |
| `KroutonProjectSheetModifier` → `ProjectSheetModifier` | type | KroutonApp/Shell/Workspace/KroutonMainWorkspaceView+DropAndSheets.swift | — |
| `KroutonProjectDialogFolder` → `ProjectDialogFolder` | type | KroutonApp/Shell/Workspace/KroutonMainWorkspaceView+DropAndSheets.swift | — |
| `KroutonMainWorkspaceView` → `MainWorkspaceView` | type | KroutonApp/Shell/Workspace/KroutonMainWorkspaceView.swift | name in verify messages or strings (rewritten) |
| `KroutonStageImporter.swift` → `StageImporter.swift` | file | KroutonApp/Shell/App/KroutonStageImporter.swift | — |
| `KroutonDesignSystem.swift` → `DesignTokens.swift` | file | KroutonApp/Shell/DesignSystem/KroutonDesignSystem.swift | — |
| `KroutonPillControls.swift` → `PillControls.swift` | file | KroutonApp/Shell/DesignSystem/KroutonPillControls.swift | — |
| `KroutonSharedWorkspaceComponents.swift` → `SharedWorkspaceComponents.swift` | file | KroutonApp/Shell/DesignSystem/KroutonSharedWorkspaceComponents.swift | — |
| `KroutonPhaseScopeMiniViews.swift` → `PhaseScopeMiniViews.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonPhaseScopeMiniViews.swift | — |
| `KroutonUserManual.swift` → `UserManual.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonUserManual.swift | — |
| `KroutonMotion.swift` → `MotionPreference.swift` | file | KroutonApp/Shell/Services/KroutonMotion.swift | — |
| `KroutonSettingsWindow.swift` → `SettingsWindow.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow.swift | — |
| `KroutonSettingsWindow+AuxPanes.swift` → `SettingsWindow+AuxPanes.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+AuxPanes.swift | — |
| `KroutonSettingsWindow+BurnServersCard.swift` → `SettingsWindow+BurnServersCard.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+BurnServersCard.swift | — |
| `KroutonSettingsWindow+BurnersNetworkPane.swift` → `SettingsWindow+BurnersNetworkPane.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+BurnersNetworkPane.swift | — |
| `KroutonSettingsWindow+FormatChooserPane.swift` → `SettingsWindow+FormatChooserPane.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+FormatChooserPane.swift | — |
| `KroutonSettingsWindow+GeneralPane.swift` → `SettingsWindow+GeneralPane.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+GeneralPane.swift | — |
| `KroutonSettingsWindow+HardwareAndMediaPanes.swift` → `SettingsWindow+HardwareAndMediaPanes.swift` | file | KroutonApp/Shell/ModalsAndSettings/KroutonSettingsWindow+HardwareAndMediaPanes.swift | — |

#### OpticalCore (56)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonPoolDispatchMode` → `PoolDispatchMode` | type | OpticalCore/Burning/BurnPoolQueue.swift | **persisted**: Codable raw values |
| `KroutonPoolBurnTicket` → `PoolBurnTicket` | type | OpticalCore/Burning/BurnPoolQueue.swift | — |
| `KroutonPoolDriveDescriptor` → `PoolDriveDescriptor` | type | OpticalCore/Burning/BurnPoolQueue.swift | — |
| `KroutonDrivePoolState` → `DrivePoolState` | type | OpticalCore/Burning/BurnPoolQueue.swift | — |
| `KroutonPersistedDecoder` → `PersistedDecoder` | type | OpticalCore/Codable/PersistedDecoder.swift | — |
| `KroutonPersistedDefault` → `PersistedDefault` | type | OpticalCore/Codable/PersistedDefaults.swift | — |
| `KroutonPersistedJSON` → `PersistedJSON` | type | OpticalCore/Codable/PersistedDefaults.swift | — |
| `KroutonPersistedDecodingContext` → `PersistedDecodingContext` | type | OpticalCore/Codable/PersistedDefaults.swift | — |
| `KroutonPersistedKey` → `PersistedKey` | type | OpticalCore/Codable/PersistedDefaults.swift | — |
| `KroutonConsoleDisc` → `ConsoleDisc` | type | OpticalCore/Console/ConsoleDiscIdentifier.swift | — |
| `KroutonConsoleDiscIdentifier` → `ConsoleDiscIdentifier` | type | OpticalCore/Console/ConsoleDiscIdentifier.swift | — |
| `KroutonDiscJugglerImage` → `DiscJugglerImage` | type | OpticalCore/Console/DiscJugglerImage.swift | — |
| `KroutonSectorSource` → `SectorSource` | type | OpticalCore/DriveCommands/SectorSource.swift | — |
| `KroutonSectorReadError` → `SectorReadError` | type | OpticalCore/DriveCommands/SectorSource.swift | — |
| `KroutonCDExtraLayout` → `CDExtraLayout` | type | OpticalCore/Models/CDExtraLayout.swift | — |
| `KroutonBurnSupport` → `BurnSupport` | type | OpticalCore/Models/FormatBurnSupport.swift | — |
| `KroutonSpanningDiscMedium` → `SpanningDiscMedium` | type | OpticalCore/Models/MultiDiscSpanner.swift | — |
| `KroutonDiscVolumeMetadata` → `DiscVolumeMetadata` | type | OpticalCore/Models/MultiDiscSpanner.swift | — |
| `KroutonMountedDiscVolume` → `MountedDiscVolume` | type | OpticalCore/Models/OpticalDriveAndAudioModels.swift | — |
| `KroutonOpticalDriveInfo` → `OpticalDriveInfo` | type | OpticalCore/Models/OpticalDriveAndAudioModels.swift | — |
| `KroutonTrackPregapStyle` → `TrackPregapStyle` | type | OpticalCore/Models/OpticalDriveAndAudioModels.swift | — |
| `KroutonRedBookTrack` → `RedBookTrack` | type | OpticalCore/Models/OpticalDriveAndAudioModels.swift | name in verify messages or strings (rewritten) |
| `KroutonCDTextSanitizer` → `CDTextSanitizer` | type | OpticalCore/Models/OpticalDriveAndAudioModels.swift | — |
| `KroutonRipTrackItem` → `RipTrackItem` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonVideoExtractTitleItem` → `VideoExtractTitleItem` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonConsoleMasteringConfig` → `ConsoleMasteringConfig` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | name in verify messages or strings (rewritten) |
| `KroutonWebEndpoints` → `WebEndpoints` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonKrutCoreSpec` → `KrutCoreSpec` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | name in verify messages or strings (rewritten); **persisted**: Codable .krut: keys unchanged; docs/schema/krut/v1.json unaffected |
| `KroutonRGBAColor` → `RGBAColor` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonVectorBackgroundStyle` → `VectorBackgroundStyle` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonBackgroundAdjustments` → `BackgroundAdjustments` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonKaleidoscopeMirrorRig` → `KaleidoscopeMirrorRig` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonGPUSeedPattern` → `GPUSeedPattern` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonVectorShapeKind` → `VectorShapeKind` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonNormalizedPoint` → `NormalizedPoint` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonLabelTextElement` → `LabelTextElement` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonVectorShapeLayer` → `VectorShapeLayer` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | — |
| `KroutonEmbeddedLabelSpec` → `EmbeddedLabelSpec` | type | OpticalCore/Models/OpticalMasteringDomainModels.swift | name in verify messages or strings (rewritten); **persisted**: Codable .krut |
| `KroutonStagedFileEntry` → `StagedFileEntry` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonBurnTelemetrySample` → `BurnTelemetrySample` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonBatchBurnState` → `BatchBurnState` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonDrivePhaseScopeTelemetry` → `DrivePhaseScopeTelemetry` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonBurnSessionReport` → `BurnSessionReport` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonDriveTelemetryStore` → `DriveTelemetryStore` | type | OpticalCore/Models/OpticalSectorAndTelemetryModels.swift | — |
| `KroutonFormatID` → `FormatID` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | **string-matched by krouton-verify** (search string rewritten) |
| `KroutonCopyTaskID` → `CopyTaskID` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | name in verify messages or strings (rewritten) |
| `KroutonMasteringWorkspaceKind` → `MasteringWorkspaceKind` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | — |
| `KroutonWorkflowFilterGroup` → `WorkflowFilterGroup` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | — |
| `KroutonOpticalWorkflowSpec` → `OpticalWorkflowSpec` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | — |
| `KroutonOpticalWorkflowCatalog` → `OpticalWorkflowCatalog` | type | OpticalCore/Models/OpticalWorkflowCatalog.swift | — |
| `KroutonPlanetSettings` → `PlanetSettings` | type | OpticalCore/Models/PlanetAndPrintSettings.swift | — |
| `KroutonLabelPrintSettings` → `LabelPrintSettings` | type | OpticalCore/Models/PlanetAndPrintSettings.swift | — |
| `KroutonWidgetSnapshot` → `WidgetSnapshot` | type | OpticalCore/Models/WidgetSnapshot.swift | **persisted**: Codable app-group JSON: keys unchanged; XcodeHost widget updated |
| `KroutonColumnSize` → `ColumnSize` | type | OpticalCore/Models/WindowLayout.swift | — |
| `KroutonColumnBreakpoint` → `ColumnBreakpoint` | type | OpticalCore/Models/WindowLayout.swift | — |
| `KroutonWindowLayout` → `WindowLayout` | type | OpticalCore/Models/WindowLayout.swift | name in verify messages or strings (rewritten) |

#### DriveKit (21)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonBurnJobContext` → `BurnJobContext` | type | DriveKit/KroutonActiveBurnSession.swift | — |
| `KroutonActiveBurnSession` → `ActiveBurnSession` | type | DriveKit/KroutonActiveBurnSession.swift | — |
| `KroutonDriveIdentity` → `DriveIdentity` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonBurnMediaDecision` → `BurnMediaDecision` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonBurnMediaPolicy` → `BurnMediaPolicy` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonDiscImageError` → `DiscImageError` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonDiscImageArguments` → `DiscImageArguments` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonBurnStageItem` → `BurnStageItem` | type | DriveKit/KroutonBurnPreflight.swift | — |
| `KroutonBurnAbortSwitch` → `BurnAbortSwitch` | type | DriveKit/KroutonDiscImageBurner.swift | — |
| `KroutonConnectedDrive` → `ConnectedDrive` | type | DriveKit/KroutonDiscImageBurner.swift | — |
| `KroutonBlankDiscInfo` → `BlankDiscInfo` | type | DriveKit/KroutonDiscImageBurner.swift | — |
| `KroutonDiscImageBurner` → `DiscImageBurner` | type | DriveKit/KroutonDiscImageBurner.swift | **string-matched by krouton-verify** (search string rewritten) |
| `KroutonDiscReadbackVerifier` → `DiscReadbackVerifier` | type | DriveKit/KroutonDiscReadbackVerifier.swift | — |
| `KroutonMMCDirectAccess` → `MMCDirectAccess` | type | DriveKit/KroutonMMCDirectAccess.swift | — |
| `KroutonMMCDeviceSession` → `MMCDeviceSession` | type | DriveKit/KroutonMMCDirectAccess.swift | — |
| `KroutonAudioBurnTrack` → `AudioBurnTrack` | type | DriveKit/KroutonOpticalDriveBank+AudioBurn.swift | — |
| `KroutonAudioBurnDisc` → `AudioBurnDisc` | type | DriveKit/KroutonOpticalDriveBank+AudioBurn.swift | — |
| `KroutonPCMTrackProducer` → `PCMTrackProducer` | type | DriveKit/KroutonOpticalDriveBank+AudioBurn.swift | objc class name changes (not archived) |
| `KroutonSectorTrackProducer` → `SectorTrackProducer` | type | DriveKit/KroutonOpticalDriveBank+DiscJugglerBurn.swift | objc class name changes (not archived) |
| `KroutonActiveEraseSession` → `ActiveEraseSession` | type | DriveKit/KroutonOpticalDriveBank+EraseSession.swift | — |
| `KroutonBurnPreflight.swift` → `BurnPreflight.swift` | file | DriveKit/KroutonBurnPreflight.swift | — |

#### BurnKit (3)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonBurnCoordinator` → `BurnCoordinator` | type | BurnKit/BurnCoordinator.swift | name in verify messages or strings (rewritten) |
| `KroutonLocalBurnRequest` → `LocalBurnRequest` | type | BurnKit/BurnCoordinator.swift | — |
| `KroutonAfterBurnStep` → `AfterBurnStep` | type | BurnKit/BurnCoordinator.swift | — |

#### ImageKit (32)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonRawSectorMode` → `RawSectorMode` | type | ImageKit/DiscImageDepot.swift | — |
| `KroutonDiscImageCueTrack` → `DiscImageCueTrack` | type | ImageKit/DiscImageDepot.swift | — |
| `KroutonDiscImageClassification` → `DiscImageClassification` | type | ImageKit/DiscImageDepot.swift | — |
| `KroutonFinderDisplayMode` → `FinderDisplayMode` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderSortKey` → `FinderSortKey` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderGroupKey` → `FinderGroupKey` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderLabelPosition` → `FinderLabelPosition` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderGalleryThumbSize` → `FinderGalleryThumbSize` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderBackgroundKind` → `FinderBackgroundKind` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderTagColor` → `FinderTagColor` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderItemAnnotation` → `FinderItemAnnotation` | type | ImageKit/FinderLayoutBlueprint.swift | — |
| `KroutonFinderLayoutBlueprint` → `FinderLayoutBlueprint` | type | ImageKit/FinderLayoutBlueprint.swift | name in verify messages or strings (rewritten) |
| `KroutonHFSOrder` → `HFSOrder` | type | ImageKit/HFSCatalog.swift | — |
| `KroutonHFSBTree` → `HFSBTree` | type | ImageKit/HFSCatalog.swift | — |
| `KroutonHFSError` → `HFSError` | type | ImageKit/HFSImageWriter.swift | — |
| `KroutonHFSImageWriter` → `HFSImageWriter` | type | ImageKit/HFSImageWriter.swift | — |
| `KroutonHybridImageOptions` → `HybridImageOptions` | type | ImageKit/HybridImageBuilder.swift | — |
| `KroutonBuiltDiscImage` → `BuiltDiscImage` | type | ImageKit/HybridImageBuilder.swift | — |
| `KroutonHybridImageError` → `HybridImageError` | type | ImageKit/HybridImageBuilder.swift | — |
| `KroutonImageBuildCancellation` → `ImageBuildCancellation` | type | ImageKit/HybridImageBuilder.swift | — |
| `KroutonHybridImageBuilder` → `HybridImageBuilder` | type | ImageKit/HybridImageBuilder.swift | — |
| `KroutonHybridExtent` → `HybridExtent` | type | ImageKit/HybridImagePlanner.swift | — |
| `KroutonHybridLayoutPlan` → `HybridLayoutPlan` | type | ImageKit/HybridImagePlanner.swift | — |
| `KroutonHybridImagePlanner` → `HybridImagePlanner` | type | ImageKit/HybridImagePlanner.swift | — |
| `KroutonParityError` → `ParityError` | type | ImageKit/ParityRecoveryWriter.swift | — |
| `KroutonUDFVolume` → `UDFVolume` | type | ImageKit/UDFDescriptors.swift | — |
| `KroutonUDFTime` → `UDFTime` | type | ImageKit/UDFDescriptors.swift | — |
| `KroutonUDFLongAD` → `UDFLongAD` | type | ImageKit/UDFDescriptors.swift | — |
| `KroutonUDF` → `UDF` | type | ImageKit/UDFDescriptors.swift | — |
| `KroutonISO` → `ISO` | type | ImageKit/UDFImageWriter+ISO9660.swift | — |
| `KroutonUDFImageWriter` → `UDFImageWriter` | type | ImageKit/UDFImageWriter.swift | — |
| `KroutonUDFError` → `UDFError` | type | ImageKit/UDFImageWriter.swift | — |

#### AudioKit (22)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonAccurateRipDiscID` → `AccurateRipDiscID` | type | AudioKit/AccurateRipVerifier.swift | — |
| `KroutonAccurateRipTrackResult` → `AccurateRipTrackResult` | type | AudioKit/AccurateRipVerifier.swift | — |
| `KroutonAccurateRipReport` → `AccurateRipReport` | type | AudioKit/AccurateRipVerifier.swift | — |
| `KroutonAccurateRipVerifier` → `AccurateRipVerifier` | type | AudioKit/AccurateRipVerifier.swift | — |
| `KroutonOutcomeBox` → `OutcomeBox` | type | AudioKit/AccurateRipVerifier.swift | — |
| `KroutonRenderedAudioTrack` → `RenderedAudioTrack` | type | AudioKit/AudioDiscRenderer.swift | — |
| `KroutonAudioRenderError` → `AudioRenderError` | type | AudioKit/AudioDiscRenderer.swift | — |
| `KroutonAudioDiscRenderer` → `AudioDiscRenderer` | type | AudioKit/AudioDiscRenderer.swift | — |
| `KroutonCDTextPack` → `CDTextPack` | type | AudioKit/AudioEngine.swift | — |
| `KroutonCrossfadeCurve` → `CrossfadeCurve` | type | AudioKit/AudioEngine.swift | — |
| `KroutonTrackTransitionSpec` → `TrackTransitionSpec` | type | AudioKit/AudioEngine.swift | name in verify messages or strings (rewritten) |
| `KroutonIdentifiedTrackMetadata` → `IdentifiedTrackMetadata` | type | AudioKit/AudioEngine.swift | — |
| `KroutonTrackAutoIdentifier` → `TrackAutoIdentifier` | type | AudioKit/AudioEngine.swift | name in verify messages or strings (rewritten) |
| `KroutonMountedCDTrackDescriptor` → `MountedCDTrackDescriptor` | type | AudioKit/AudioSampleDecoder.swift | — |
| `KroutonMountedAudioCDSnapshot` → `MountedAudioCDSnapshot` | type | AudioKit/AudioSampleDecoder.swift | — |
| `KroutonRippedTrackResult` → `RippedTrackResult` | type | AudioKit/AudioSampleDecoder.swift | — |
| `KroutonAudioTags` → `AudioTags` | type | AudioKit/AudioTagWriter.swift | — |
| `KroutonAudioTagError` → `AudioTagError` | type | AudioKit/AudioTagWriter.swift | — |
| `KroutonAudioTagWriter` → `AudioTagWriter` | type | AudioKit/AudioTagWriter.swift | — |
| `KroutonTagResultBox` → `TagResultBox` | type | AudioKit/AudioTagWriter.swift | — |
| `KroutonCRC32` → `CRC32` | type | AudioKit/KroutonCRC32.swift | — |
| `KroutonRipCodec` → `RipCodec` | type | AudioKit/RipCodec.swift | **persisted**: raw values saved on rip cards |

#### VideoKit (18)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonAVCHDDisc` → `AVCHDDisc` | type | VideoKit/AVCHDOnDVDAuthoringEngine.swift | — |
| `KroutonAVCHDError` → `AVCHDError` | type | VideoKit/AVCHDOnDVDAuthoringEngine.swift | — |
| `KroutonBDMVVideoFormat` → `BDMVVideoFormat` | type | VideoKit/BDMVNavigationWriter.swift | — |
| `KroutonBDMVClip` → `BDMVClip` | type | VideoKit/BDMVNavigationWriter.swift | — |
| `KroutonBDMVWriter` → `BDMVWriter` | type | VideoKit/BDMVNavigationWriter.swift | — |
| `KroutonCarAudioOptions` → `CarAudioOptions` | type | VideoKit/CarAudioDiscPreparer.swift | — |
| `KroutonCarAudioError` → `CarAudioError` | type | VideoKit/CarAudioDiscPreparer.swift | — |
| `KroutonCarAudioDiscPreparer` → `CarAudioDiscPreparer` | type | VideoKit/CarAudioDiscPreparer.swift | — |
| `KroutonM2TSAnalysis` → `M2TSAnalysis` | type | VideoKit/M2TSStreamAnalyzer.swift | — |
| `KroutonM2TSError` → `M2TSError` | type | VideoKit/M2TSStreamAnalyzer.swift | — |
| `KroutonM2TSAnalyzer` → `M2TSAnalyzer` | type | VideoKit/M2TSStreamAnalyzer.swift | — |
| `KroutonVideoShrinkError` → `VideoShrinkError` | type | VideoKit/VideoAuthoringEngine+Shrink.swift | — |
| `KroutonVideoTargetMedium` → `VideoTargetMedium` | type | VideoKit/VideoAuthoringEngine.swift | — |
| `KroutonVideoBitrateBudget` → `VideoBitrateBudget` | type | VideoKit/VideoAuthoringEngine.swift | — |
| `KroutonDVD9ShrinkPlan` → `DVD9ShrinkPlan` | type | VideoKit/VideoAuthoringEngine.swift | — |
| `KroutonDVD9CellDescriptor` → `DVD9CellDescriptor` | type | VideoKit/VideoAuthoringEngine.swift | — |
| `KroutonShrunkDVD5CellEntry` → `ShrunkDVD5CellEntry` | type | VideoKit/VideoAuthoringEngine.swift | — |
| `KroutonDVD9MenuShrinkBlueprint` → `DVD9MenuShrinkBlueprint` | type | VideoKit/VideoAuthoringEngine.swift | — |

#### LabelKit (4)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonDiscHubGeometry` → `DiscHubGeometry` | type | LabelKit/LabelGeometry.swift | **persisted**: raw values saved in labels |
| `KroutonPolarArcGlyphPlacement` → `PolarArcGlyphPlacement` | type | LabelKit/LabelGeometry.swift | — |
| `KroutonPlanetSource` → `PlanetSource` | type | LabelKit/PlanetProjection.swift | — |
| `KroutonPlanetProjection` → `PlanetProjection` | type | LabelKit/PlanetProjection.swift | — |

#### RescueKit (10)

| Old → New | Kind | Declared in | Hazards |
|---|---|---|---|
| `KroutonSectorSink` → `SectorSink` | type | RescueKit/DiscRescuer.swift | — |
| `KroutonImageFileSink` → `ImageFileSink` | type | RescueKit/DiscRescuer.swift | — |
| `KroutonRescuePlan` → `RescuePlan` | type | RescueKit/DiscRescuer.swift | — |
| `KroutonDiscRescuer` → `DiscRescuer` | type | RescueKit/DiscRescuer.swift | — |
| `KroutonSectorRescueAction` → `SectorRescueAction` | type | RescueKit/RescueEngine.swift | — |
| `KroutonSectorRescueDecision` → `SectorRescueDecision` | type | RescueKit/RescueEngine.swift | — |
| `KroutonRescueSectorStatus` → `RescueSectorStatus` | type | RescueKit/RescueEngine.swift | — |
| `KroutonOpticalRescueMapSnapshot` → `OpticalRescueMapSnapshot` | type | RescueKit/RescueEngine.swift | — |
| `KroutonArchivalQualityCertificate` → `ArchivalQualityCertificate` | type | RescueKit/RescueEngine.swift | — |
| `KroutonRescueMap` → `RescueMap` | type | RescueKit/RescueMap.swift | — |


### Kept on purpose

| Name | Why it keeps `Krouton` |
|---|---|
| `KroutonApp` | the App type and the module |
| `KroutonDomainIdentity` | the product's identity (bundle prefix, subsystems) |
| `KroutonEntryPoint` | public; called by `KroutonMain` and `XcodeHost/App`; `EntryPoint` is taken by `M2TSAnalysis.EntryPoint` |
| `KroutonL10n` | `Scripts/extract-strings.py` matches `KroutonL10n.tr` |
| `KroutonAppIntentsPackage`, `KroutonStatusIntent`, `KroutonEjectIntent`, `KroutonOpenIntent`, `KroutonListOpticalDrivesIntent`, `KroutonInspectDiscImageIntent`, `KroutonPlanMultiDiscSpanIntent`, `KroutonBuildHybridISOIntent`, `KroutonOpenWorkspaceIntent`, `KroutonShortcutDiscMedium`, `KroutonShortcutsProvider` | App Intents: the system stores these names in people's shortcuts; CI's `xcode-app` job greps for `KroutonEjectIntent` |
| `KroutonBurnAttributes` (XcodeHost) | ActivityKit matches Live Activities by the attributes type |

## Files to move and split

The script renames files; splitting needs hands. Do each split in its module's PR, after the
script, so the type names are already final. File sizes now (ceilings: 400 lines in KroutonApp
and KroutonVerify, 500 elsewhere):

**Split along the lines they already have**

| File (after renames) | Lines | Split into |
|---|---|---|
| `KroutonApp/Shell/StateAndModels/KroutonStateDomainModels.swift` (+`CardPresets`) | 343 + 111 | `AppearanceOptions.swift` (AccentColorPreset, AppearanceMode, IconStyle, SidebarIconSize, FolderColorMode, LabelTemplate, AppLanguage), `SidebarGroup.swift`, `DepotModels.swift` (DepotCatalogItem, DepotFeedSubscription), `DiscLabelGeometry.swift`, `DestinationCard.swift` (DestinationCard, DestinationKind, NotificationEventSetting) and `DestinationCard+Presets.swift`. **Update** `VerifyHarness+SavedDestinationChecks.swift`, which opens this file by path. |
| `OpticalCore/Models/OpticalMasteringDomainModels.swift` | 415 | `LabelDesign.swift` (RGBAColor, VectorBackgroundStyle, BackgroundAdjustments, KaleidoscopeMirrorRig, GPUSeedPattern, VectorShapeKind, NormalizedPoint, LabelTextElement, VectorShapeLayer, EmbeddedLabelSpec), `KrutProject.swift` (KrutCoreSpec, KrutSecurity, WebEndpoints), `RipAndExtractItems.swift`, `ConsoleMasteringConfig.swift` |
| `OpticalCore/Models/OpticalSectorAndTelemetryModels.swift` | 288 | `StagedFileEntry.swift` (no sectors in it), `BurnTelemetry.swift` |
| `OpticalCore/Models/OpticalDriveAndAudioModels.swift` | 284 | `OpticalDriveInfo.swift` (MountedDiscVolume, OpticalDriveInfo), `RedBookTrack.swift` (TrackPregapStyle, RedBookTrack, CDTextSanitizer) |
| `OpticalCore/InspectorsAndPrep/MediaProbe.swift` (was `KroutonMediaPrepAndColorEngine.swift`) | 376 | `MediaProbe.swift`, `SectorInspector.swift`, `ColorMath.swift`. It also imports SwiftUI inside a portable-core module: check Suite 31 while there |
| `AudioKit/RedBookAudio.swift` (was `AudioEngine.swift`) | 353 | `RedBookAudio.swift`, `TrackTransition.swift` (CrossfadeCurve, TrackTransitionSpec, SpliceTransitionMode), `TrackAutoIdentifier.swift` |
| `AudioKit/AudioSampleDecoder.swift` | 466 | `MountedAudioCDReader.swift` (MountedCDTrackDescriptor, MountedAudioCDSnapshot, RippedTrackResult, MountedAudioCDReader) |
| `AudioKit/TrackMetadata.swift` (was `HonestTrackData.swift`) | 305 | `LoudnessMeter.swift`, `PeakPyramid.swift` |
| `DriveKit/BurnPreflight.swift` (was `KroutonBurnPreflight.swift`) | 143 | `DriveIdentity.swift`, `BurnMediaPolicy.swift`, `DiscImageArguments.swift`, `BurnFolderStager.swift` |
| `NetworkSpool/SpoolTelemetry.swift` | 126 | move `SpoolHostCheck` to `SpoolEndpointPolicy.swift`, the other half of the same check |
| `LabelKit/LabelGeometry.swift` | 161 | `evaluateSectorRescue`, `buildOpticalRescueMap`, `evaluateArchivalDiscGrade` are RescueKit pass-throughs: call `RescuePolicy` directly and drop LabelKit's RescueKit dependency (open question 6) |
| `KroutonApp/…/Splice/SpliceWindowState.swift` (was `SpliceDragController.swift`) | 211 | `SpliceDragModifier.swift` |
| `KroutonApp/…/Splice/SpliceWorkspaceView.swift` | 324 | `SpliceFloatingWindowView.swift` |
| `KroutonApp/Shell/StateAndModels/SessionSnapshot.swift` | 370 | `CrashRecoveryController.swift`; `CrashRecoveryBannerView` moves to `Shell/ModalsAndSettings/` (a view in StateAndModels) |
| `KroutonApp/Shell/ModalsAndSettings/MasteringReportSheet.swift` | 161 | `DiscArtworkView.swift`, `DiscMediaPopover.swift` |
| `KroutonApp/Shell/DesignSystem/ColorHarmony.swift` | 200 | the `StateStore` extension → `StateStore+Colors.swift` |
| `Persistence/SessionStore.swift` | 472 | `RunLock.swift` (RunMarker, LaunchVerdict, RunLock, RestoreDecision), `BurnJournal.swift` |

**Close to the ceiling** (split before the next feature lands in them): `DriveController+BurnSession.swift`
499/500, `DriveController.swift` 477, `AudioProject.swift` 458, `UDFImageWriter.swift` 432,
`LabelGeometry+OpticalPlayground.swift` 420, `OpticalDiscVolumeScanner.swift` 416, and in
KroutonApp/KroutonVerify `SpliceWaveformCanvas.swift` 396, `VerifyHarness+LabelAndPersistenceSuites.swift`
391, `DestinationRackColumnView+WaitingPool.swift` 388.

**Left as they are**: `KroutonMenuCommands.swift` and `+EditAndView` hold `WorkspaceCommands`, but
`Scripts/build-manual.py` globs `KroutonMenuCommands*.swift` and a krouton-verify suite filters on
the `KroutonMenuCommands` prefix. Rename them by hand, with both, if wanted.

**In the wrong folder**

- `CrashRecoveryBannerView` is a view in `StateAndModels/` → `ModalsAndSettings/`.
- `TutorialController` and `ManualLibrary` are models in `ModalsAndSettings/` → `StateAndModels/`.
- `Features/Data/MasteringTelemetryPopovers.swift` holds audio and video popovers too → `Shell/Workspace/`.
- `Shell/` must keep exactly its 8 folders (Suite 2), so moves go between them, never into new ones.

**Same job, two names** (not renames; decide, then merge)

- Three big-endian helpers: `ByteOrder` (OpticalCore), `SpoolBytes`, `MMCBytes`, plus `BigEndianWriter` in VideoKit.
- Two stagers: `BurnSetStager` (BurnKit, sets) and `BurnFolderStager` (DriveKit, one burn).
- Spanning: `DiscPlanner`, `BurnSetPlanner`, `ManualDiscBreaks`, `SpanManifest`: the glossary in
  `ARCHITECTURE.md` should say which does what.
- "Depot" means the Disc Image Depot downloads (app); ImageKit's former `KroutonDiscImageDepot` was
  never part of it, hence `DiscImageClassifier`.

## Sequencing

1. **Merge the open PRs first.** The renames touch 291 files; nothing else should be in flight.
   Merge this PR (doc and tool only, no code change) whenever.
2. **One module per PR**, so CI compiles each step: `python3 -I Scripts/apply-renames.py --module X`
   applies the rows declared in module X and rewrites their callers everywhere. Order (each builds
   on the one before, and the busy app comes last): OpticalCore, AudioKit, LabelKit, RescueKit,
   ImageKit, VideoKit, NetworkSpool, BurnKit, DriveKit, KroutonApp, KroutonVerify + Tests.
   If PRs keep arriving, do tiers 1–3 first (`--tier 1 --tier 2 --tier 3`, 102 rows), and the
   prefix drop (tier 4, 286 rows) per module afterwards.
3. In each PR: run `--dry-run --module X` and read it; apply; do that module's splits by hand;
   then `swift build`, `swift test`, `swift run krouton-verify`,
   `python3 Scripts/extract-strings.py --check`, `python3 Scripts/build-manual.py --check`.
   Search for the old names once more (`git grep -w OldName`) and check the CHANGELOG entry.
4. Rerunning is safe: an applied row reports *already applied*.

### What to watch, and what the script does about it

| Hazard | Found | What happens |
|---|---|---|
| Codable keys, raw values, `CodingKeys` | 25 renamed types hold saved raw values or Codable keys (marked **persisted** above) | Type renames are safe. No row renames a stored property or saved case; a `case`/`member` row inside a Codable type or with an implicit raw value is refused unless the row says why (the two `ProceduralPreset` cases: `rawValue` is never read) |
| UserDefaults keys | `krouton.pref.*` are raw values of `DefaultsKey` | unchanged |
| `@objc` and Objective-C class names | `PCMTrackProducer`, `SectorTrackProducer`, `DepotDownloadProgress`, `AppDelegate` are `NSObject` subclasses | class names change; nothing archives them, and DiscRecording calls producers by selector (the `@objc(...)` selectors are untouched) |
| App Intents identifiers | 11 types + `KroutonBurnAttributes` | kept; the script refuses an App Intents/widget type row unless it allows `intent` |
| String Catalog keys | no type name is a key; renames change no interface text | `extract-strings.py --check` passes after a full apply on a copy of the tree |
| Scene ids | `"main"`, `"track-montage"`, `"phase-scope"` | strings, untouched |
| krouton-verify string matching | 7 names searched for in source (marked **string-matched**), 7 rows whose file is opened or matched by path, 19 rows named in check messages | rewritten with the code, files renamed with their paths; every `X+Role.swift` still has its `X.swift` after a full apply |
| Suite 1's food-word regex | bans `Recipe`, `Slice`, `Crust`… in type names | no new name uses them |
| `PENDING_INTEGRATION.md` (Suite 28) | entries name public types | rewritten with them |
| The manual and CI scripts | `build-manual.py` globs `KroutonMenuCommands*.swift` (not renamed) and names `KroutonManualDocument` in its docstring (row allows `ci`); `ci.yml` greps `KroutonEjectIntent` (kept) | refused unless the row allows `ci`/`manual` |
| NSError domains | `"KroutonRealCDExtractor"`, `"DiscImageDepotOperations"` | change with the type; nothing compares them |
| History | `CHANGELOG.md`, `dev-notes/project_history.md` and the dated hand-offs | never rewritten |

### Dry run on 2026-11-28 (branch from `agents/git-worktrees`, commit `ecaff7d`)

`python3 -I Scripts/apply-renames.py --dry-run`: 388 rows, 388 to apply, 0 refused; 3,907 changed
lines in 291 files; 120 files renamed. By tier: 1 → 62 rows (1,063 lines, 29 files renamed),
2 → 34 (169, 23), 3 → 6 (15, 1), 4 → 286 (2,660, 67). Applied module by module to a copy of the
tree (OpticalCore 70 rows, AudioKit 28, LabelKit 6, RescueKit 12, ImageKit 37, VideoKit 25,
NetworkSpool 2, BurnKit 6, DriveKit 26, KroutonApp 173, KroutonVerify 2, Tests 1), a further
run reports all 388 *already applied*, no `+Role` file is left without its base file,
no two modules declare the same top-level type, and both `--check` scripts pass. Swift itself is
checked by CI, as there's no Swift toolchain where this was written.
