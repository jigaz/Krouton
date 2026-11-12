import SwiftUI
import Foundation
import AudioToolbox
import ImageIO
import UniformTypeIdentifiers
import OpticalDough

public enum KroutonOSDesktopBridge {
    private static let activeLock = NSLock()
    nonisolated(unsafe) private static var _isVisiblyActive: Bool = true

    public static func setApplicationVisiblyActive(_ active: Bool) {
        activeLock.lock()
        _isVisiblyActive = active
        activeLock.unlock()
    }

    public static func playAcousticCue() {
        AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
    }

    public static func copyTextToClipboard(_ text: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        p.standardInput = pipe
        if (try? p.run()) != nil {
            pipe.fileHandleForWriting.write(Data(text.utf8))
            try? pipe.fileHandleForWriting.close()
            p.waitUntilExit()
        }
    }

    public static func revealURLsInFinder(_ urls: [URL]) {
        guard let u = urls.first else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-R", u.path]
        try? p.run()
    }

    public static func revealFolderInFinder(path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = [path]
        try? p.run()
    }

    @MainActor
    public static func printSwiftUIView<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cg = renderer.cgImage,
              let data = CFDataCreateMutable(nil, 0),
              let dst = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dst, cg, nil)
        guard CGImageDestinationFinalize(dst) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Krouton-Print.png")
        try? (data as Data).write(to: url, options: .atomic)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Preview", url.path]
        try? p.run()
    }

    public static func isSystemDarkMode() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    public static func postVoiceOverAnnouncement(_ message: String) {
        Task { @MainActor in AccessibilityNotification.Announcement(message).post() }
    }

    public static var didBecomeActiveNotification: Notification.Name { Notification.Name("KroutonDidBecomeActive") }
    public static var didResignActiveNotification: Notification.Name { Notification.Name("KroutonDidResignActive") }
    public static var didChangeWindowOcclusionNotification: Notification.Name { Notification.Name("KroutonOcclusion") }

    public static func isApplicationVisiblyActive() -> Bool {
        activeLock.lock()
        defer { activeLock.unlock() }
        return _isVisiblyActive
    }
}

@MainActor
final class KroutonWindowManager: ObservableObject {
    static let shared = KroutonWindowManager()
    let store = KroutonStateStore()
    let driveManager = KroutonToasterBank()
    var openWindowAction: OpenWindowAction?
    var dismissWindowAction: DismissWindowAction?

    func bindSceneActions(openWindow: OpenWindowAction, dismissWindow: DismissWindowAction) {
        self.openWindowAction = openWindow
        self.dismissWindowAction = dismissWindow
    }

    func openFloatingPhaseScopeWindow(driveID: String) {
        let targetID = driveManager.driveForID(driveID)?.id ?? driveID
        guard !targetID.isEmpty else { return }
        driveManager.setFloatingScopeOpen(for: targetID, isOpen: true)
        openWindowAction?(id: "phase-scope", value: targetID)
    }

    func closeFloatingPhaseScopeWindow(driveID: String, suckIntoMiniGraph: Bool = true) {
        driveManager.setFloatingScopeOpen(for: driveID, isOpen: false, keepInlineVisible: suckIntoMiniGraph)
        dismissWindowAction?(id: "phase-scope", value: driveID)
    }

    func openMainWindow() { openWindowAction?(id: "main") }

    func openSettingsWindow(store: KroutonStateStore, driveManager: KroutonToasterBank, pane: KroutonSettingsCategory? = nil) {
        if let p = pane { store.selectedSettingsPane = p }
        openWindowAction?(id: "settings")
    }
}

struct KroutonSceneActionBinder: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { KroutonWindowManager.shared.bindSceneActions(openWindow: openWindow, dismissWindow: dismissWindow) }
            .onChange(of: scenePhase) { _, phase in
                let active = (phase == .active)
                KroutonOSDesktopBridge.setApplicationVisiblyActive(active)
                NotificationCenter.default.post(name: active ? KroutonOSDesktopBridge.didBecomeActiveNotification : KroutonOSDesktopBridge.didResignActiveNotification, object: nil)
            }
    }
}

@main
struct KroutonApp: App {
    @StateObject private var wm = KroutonWindowManager.shared

    var body: some Scene {
        Window("Krouton", id: "main") {
            KroutonMainWorkspaceView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 1380, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Show Krouton Workspace") { KroutonWindowManager.shared.openMainWindow() }
                    .keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: wm.store, driveManager: wm.driveManager)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(wm.store.uiSecondaryAccent)
                        Text(KroutonL10n.tr("Settings..."))
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("Krouton Settings", id: "settings") {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 1120, height: 720)

        WindowGroup("Phase Scope", id: "phase-scope", for: String.self) { $driveID in
            let targetID = driveID ?? "krumb-network-toaster"
            KroutonFloatingThermometerView(
                driveID: targetID,
                store: wm.store,
                driveManager: wm.driveManager,
                onDockInline: { KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: targetID) }
            )
            .modifier(KroutonSceneActionBinder())
            .onDisappear { wm.driveManager.setFloatingScopeOpen(for: targetID, isOpen: false, keepInlineVisible: true) }
        }
        .defaultSize(width: 780, height: 520)

        Settings {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
        }
    }
}

struct KroutonMainWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonToasterBank
    @ObservedObject var krumb: KrumbKitchenClient = .shared

    @State var enableCustomFinderLayoutTab: Bool = false
    @State var showTartineLBAMapPopover: Bool = false
    @State var showMarmaladeCuePopover: Bool = false
    @State var showVideoOvenPopover: Bool = false
    @State var activeDataWorkspaceTab: Int = 0
    @State var finderBgColor: Color = Color(red: 0.13, green: 0.17, blue: 0.24)
    @State var finderIconSize: Double = 256
    @State var fitToDiscDVD9Shrink: Bool = true
    @State var preserveMenusAndExtras: Bool = true
    @State var labelDiscTitle: String = "THE KROUTON ARCHIVE"
    @State var labelSubtitle: String = "2026 MASTER EDITION"
    @State var autoLabelSearchQuery: String = "Dark Side of the Moon"
    @State var depotSearchQuery: String = ""
    @State var leftColumnLiveWidth: CGFloat = 196
    @State var rightColumnLiveWidth: CGFloat = 315
    @State var leftSidebarDragStartWidth: CGFloat? = nil
    @State var rightSidebarDragStartWidth: CGFloat? = nil
    @State var dropRejectShakePhase: CGFloat = 0
    @State var isLeftSidebarCompact: Bool = false
    @State var isLeftSidebarUltraSkinny: Bool = false
    @State var isRightQueueCompact: Bool = false
    @State var isCenterWorkspaceNarrow: Bool = false
    @State var isCenterWorkspaceUltraCompact: Bool = false
    @State var isDropTargeted: Bool = false
    @State var activeDiscPopoverCardID: UUID? = nil
    @State var romWriteModeDAO96SubQ: Bool = true
    @State var romBitsetDVDROM: Bool = true
    @State var romPerformOPCBeforeWrite: Bool = true
    @State var xboxLayerBreakPreset: String = "Auto (.dvd / Calculate Optimal)"
    // Red Book CD-DA & CD-Extra Mastering State
    @State var cdTextAlbumTitle: String = "KROUTON SESSIONS VOL. I"
    @State var cdTextAlbumPerformer: String = "THE OPTICAL COLLECTIVE"
    @State var cdTextUPCBarcode: String = "012345678905"
    @State var enableHiddenTrackOneHTOA: Bool = false
    @State var defaultAudioTransition: String = "2.0s Standard Pre-Gap (INDEX 00)"
    @State var auditioningTrackID: UUID? = nil
    // Car-Safe MP3 / FLAC CD Mastering State
    @State var carSafeZeroPadNumbers: Bool = true
    @State var carSafeStripAppleDouble: Bool = true
    @State var carSafeEnforceID3v23: Bool = true
    @State var carSafeGenerateM3U: Bool = true
    @State var carSafeTranscodeTarget: String = "320 kbps CBR MP3 (Universal Car Deck)"
    // Video Disc Authoring & Dual-Layer Break State
    @State var videoMenuTemplate: String = "Dark Studio Chapter Grid"
    @State var videoSystemStandard: String = "NTSC 16:9 (29.97 / 23.976p)"
    @State var videoAudioEncoding: String = "AC-3 Dolby Digital 5.1 (448 kbps)"
    @State var videoDualLayerBreakSector: String = "Auto Cell Boundary (LBA 2,086,912 • 16-Sector ECC Aligned)"
    // M-DISC Archival PAR2 State
    @State var mdiscPar2RedundancyPct: Double = 15.0
    // New Data Disc File System Bridge State
    @State var selectedDataFileSystemBridge: String = "Universal 4-Way Bridge (UDF 1.02 + HFS+ + Joliet + Rock Ridge)"
    @State var preserveMacExtendedAttributes: Bool = true
    @State var enforce8Dot3RetroCompatibility: Bool = false
    // Dedicated Disc Image Burner State
    @State var discImageWriteMethod: String = "DAO / SAO Sector-Exact (Preserve System Area & Boot Catalog)"
    @State var verifyImageSHA256BeforeBurn: Bool = true
    @State var inspectedImageLBA: Int = 17
    @State var computedImageSHA256: String = ""
    @State var imageActionStatusBanner: String = ""
    @State var audioRipCodec: String = "FLAC (Lossless)"
    @State var audioRipAccurateRip: Bool = true
    @State var audioRipGenerateCueLog: Bool = true
    @State var audioRipSelectedTracks: Set<Int> = [1, 2, 3, 4, 5]
    @State var videoExtractMode: String = "Lossless MKV Remux"
    @State var videoExtractMinSeconds: Int = 120
    @State var videoExtractKeepChapters: Bool = true
    @State var videoExtractSelectedTitles: Set<String> = ["TITLE_01", "TITLE_02"]
    @State var ps1AutoMergeMultiBinAndCHD: Bool = true
    @State var ps2ApplyESRPatch: Bool = false
    @State var gcPadToOuterEdge3GB: Bool = true
    @State var wiiLayerMode: String = "Auto-Detect (DVD5 4.7GB / DVD9 LBA 2084960)"
    @State var xboxVerifyStealthSectors: Bool = true
    @State var cdExtraDataVolumeName: String = "BONUS_EXTRA"
    @State var cdExtraIncludeLinerNotes: Bool = true
    @State var avchdBitrateCap: String = "18 Mbps (3x DVD-R Safe)"
    @State var uhdPreserveHDR10DolbyVision: Bool = true
    @State var copySourceOverrideLabel: String = ""
    @State var copyOutputFolderPath: String = "~/Music/Krouton Rips"
    @State var copyStatusBanner: String = ""
    @State var audioRipTracks: [KroutonRipTrackItem] = KroutonRipTrackItem.defaultRedBookTOC
    @State var videoExtractTitles: [KroutonVideoExtractTitleItem] = KroutonVideoExtractTitleItem.defaultVideoTitles

    var primarySelectedDrive: KroutonToasterInfo? {
        if let firstBurnerCard = store.destinationQueue.first(where: { $0.kind == .physicalBurner }),
           let match = driveManager.driveForID(firstBurnerCard.targetDriveID) {
            return match
        }
        return driveManager.selectedDrive ?? driveManager.availableDrives.first
    }

    var activeDiscCapacityBytes: Int64 {
        if let drive = primarySelectedDrive, drive.isMediaPresent, drive.freeBytes > 0 {
            return drive.freeBytes
        }
        let activeSpec = store.discFormats.first(where: { $0.id == store.selectedTaskID })
        let gb = activeSpec?.capacityGB ?? 4.7
        return Int64(gb * 1_000_000_000.0)
    }

    var activeDiscTotalSectorsLBA: Int64 {
        max(1, activeDiscCapacityBytes / 2048)
    }

    var body: some View {
        VStack(spacing: 0) {
            topProToolbar
            Divider()

            GeometryReader { windowGeo in
                let totalW = windowGeo.size.width
                let minCenterW: CGFloat = 320
                let maxAllowedLeft = max(182, min(340, totalW - rightColumnLiveWidth - minCenterW - 22))
                let clampedLeft = min(max(182, leftColumnLiveWidth), maxAllowedLeft)
                let maxAllowedRight = max(195, min(440, totalW - clampedLeft - minCenterW - 22))
                let clampedRight = min(max(195, rightColumnLiveWidth), maxAllowedRight)

                let centerLiveW = max(0, totalW - clampedLeft - clampedRight - 22)

                HStack(spacing: 0) {
                    leftFormatChooserColumn
                        .frame(width: clampedLeft)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    ZStack {
                        Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 1)
                        Capsule().fill(Color.secondary.opacity(0.45)).frame(width: 3, height: 28)
                    }
                    .frame(width: 11)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { val in
                                if leftSidebarDragStartWidth == nil { leftSidebarDragStartWidth = clampedLeft }
                                let startW = leftSidebarDragStartWidth ?? clampedLeft
                                let maxL = max(182, min(340, totalW - clampedRight - minCenterW - 22))
                                let newW = min(max(182, startW + val.translation.width), maxL)
                                var tx = Transaction(); tx.disablesAnimations = true
                                withTransaction(tx) {
                                    leftColumnLiveWidth = newW
                                    if !isLeftSidebarCompact && newW < 258 { isLeftSidebarCompact = true }
                                    else if isLeftSidebarCompact && newW > 272 { isLeftSidebarCompact = false }
                                    if !isLeftSidebarUltraSkinny && newW < 215 { isLeftSidebarUltraSkinny = true }
                                    else if isLeftSidebarUltraSkinny && newW > 228 { isLeftSidebarUltraSkinny = false }
                                }
                            }
                            .onEnded { _ in
                                leftColumnLiveWidth = clampedLeft
                                leftSidebarDragStartWidth = nil
                            }
                    )

                    centerAdaptableWorkspace
                        .frame(width: centerLiveW)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    ZStack {
                        Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 1)
                        Capsule().fill(Color.secondary.opacity(0.45)).frame(width: 3, height: 28)
                    }
                    .frame(width: 11)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { val in
                                if rightSidebarDragStartWidth == nil { rightSidebarDragStartWidth = clampedRight }
                                let startW = rightSidebarDragStartWidth ?? clampedRight
                                let maxR = max(195, min(440, totalW - clampedLeft - minCenterW - 22))
                                let newW = min(max(195, startW - val.translation.width), maxR)
                                var tx = Transaction(); tx.disablesAnimations = true
                                withTransaction(tx) {
                                    rightColumnLiveWidth = newW
                                    if !isRightQueueCompact && newW < 355 { isRightQueueCompact = true }
                                    else if isRightQueueCompact && newW > 368 { isRightQueueCompact = false }
                                }
                            }
                            .onEnded { _ in
                                rightColumnLiveWidth = clampedRight
                                rightSidebarDragStartWidth = nil
                            }
                    )

                    rightDestinationColumn
                        .frame(width: clampedRight)
                        .frame(maxHeight: .infinity)
                        .clipped()
                }
                .frame(width: totalW, alignment: .leading)
                .coordinateSpace(name: "KroutonSplitSpace")
                .onAppear {
                    isLeftSidebarCompact = clampedLeft < 265
                    isLeftSidebarUltraSkinny = clampedLeft < 215
                    isRightQueueCompact = clampedRight < 355
                    isCenterWorkspaceUltraCompact = centerLiveW < 500
                    isCenterWorkspaceNarrow = centerLiveW < 720
                }
                .onChange(of: centerLiveW) { _, newCenterW in
                    // Hysteresis deadband (705pt <-> 735pt) for Center Workspace 1-Column / 2-Column & Hero Schematic box!
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isCenterWorkspaceNarrow && newCenterW < 705 {
                            isCenterWorkspaceNarrow = true
                        } else if isCenterWorkspaceNarrow && newCenterW > 735 {
                            isCenterWorkspaceNarrow = false
                        }
                        if !isCenterWorkspaceUltraCompact && newCenterW < 495 {
                            isCenterWorkspaceUltraCompact = true
                        } else if isCenterWorkspaceUltraCompact && newCenterW > 515 {
                            isCenterWorkspaceUltraCompact = false
                        }
                    }
                }
            }
        }
        .frame(minWidth: 820, idealWidth: 1360, minHeight: 640, idealHeight: 860)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.11) : Color.clear)
        .background(Color.kroutonWindowSurface)
        .preferredColorScheme(store.appearanceMode.colorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
        .onAppear {
            reconcileUniqueDriveAssignments()
        }
        .onChange(of: driveManager.availableDrives) { _, _ in
            reconcileUniqueDriveAssignments()
        }
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }
        .modifier(KroutonStageImporterModifier(store: store))
    }

    var topProToolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "opticaldisc.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(store.activeAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(KroutonL10n.tr("KROUTON"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text("\(driveManager.availableDrives.count) Optical Drive(s) Online • \(driveManager.hardwareStatusLog)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(store.enableSecondaryAccentUITints ? store.activeSecondaryAccent.opacity(0.90) : Color.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    KroutonWindowManager.shared.openSettingsWindow(store: store, driveManager: driveManager)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text(KroutonL10n.tr("Settings..."))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.uiSecondaryAccent.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(store.uiSecondaryAccent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(store.enableSecondaryAccentUITints ? store.activeAccent.opacity(0.14) : Color.clear)
        .background(.ultraThinMaterial)
    }



    func taskRowButton(id: String, category: KroutonBakeryStation, title: String,
        shortTitle: String? = nil, colloquial: String, badge: String = "", sfSymbol: String) -> some View {
        let isSelected = (store.selectedTaskID == id)
        return Button {
            store.selectedCategory = category
            store.selectedTaskID = id
            store.rejectedDropNotice = nil
            store.purgeIncompatibleStagedFilesForCurrentTask()
            syncDefaultDestinationForCategory(category, taskID: id)
        } label: {
            HStack(spacing: 9) {
                let rowColor = store.effectiveColorForTask(id: id, category: category)
                KroutonStyledIconBadge(
                    sfSymbol: sfSymbol,
                    tintColor: rowColor,
                    style: store.iconWidgetStyle,
                    isSelectedRow: isSelected,
                    onAccentText: store.activeOnAccentText,
                    size: store.sidebarIconSize.iconFontSize + 11,
                    symbolSize: store.sidebarIconSize.iconFontSize - 1
                )

                VStack(alignment: .leading, spacing: 1) {
                    ViewThatFits(in: .horizontal) {
                        Text(KroutonL10n.tr(title))
                            .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                            .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Text(KroutonL10n.tr(shortTitle ?? title))
                            .font(.system(size: store.sidebarIconSize.titleFontSize, weight: .semibold))
                            .foregroundStyle(isSelected ? store.activeOnAccentText : .primary)
                            .lineLimit(1)
                    }
                    if !isLeftSidebarUltraSkinny {
                        Text(KroutonL10n.tr(colloquial))
                            .font(.system(size: max(9.5, store.sidebarIconSize.titleFontSize - 2.0)))
                            .foregroundStyle(isSelected ? store.activeOnAccentText.opacity(0.82) : .secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, store.sidebarIconSize.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? store.activeAccent : Color.clear)
            )
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.a11yIncreaseContrast && isSelected ? Color.primary : Color.clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(colloquial)")
    }

    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR (Global graph removed)
    var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                switch store.selectedCategory {
                case .burn:
                    burnWorkspaceView
                        .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)
                case .depot:
                    depotWorkspaceView
                case .copy:
                    copyWorkspaceView
                case .label:
                    labelWorkspaceView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Integrated Central Workspace Capacity Allocation Bar (Hidden in Label Designer mode)
            if store.selectedCategory != .label {
                centralWorkspaceCapacityBar
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }



    var filteredDepotItems: [KroutonPantryCatalogItem] {
        let channelFilter: String? = {
            switch store.selectedTaskID {
            case "depot-rescue": return "Rescue & Diagnostics"
            case "depot-linux": return "Live Linux & BSD"
            case "depot-vintage": return "Vintage Apple (archive.org)"
            case "depot-homebrew": return "Console Homebrew & ROMs"
            case "depot-coverdiscs": return "Cover Discs & Demoscene"
            case "depot-retropc": return "Retro PC & Alt OS"
            case "depot-ia-live": return "Internet Archive Live"
            default: return nil // "depot-all" shows all 60+ titles
            }
        }()

        return store.depotItems.filter { item in
            let matchesChannel = (channelFilter == nil) || (item.channel == channelFilter)
            let q = depotSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesQuery = q.isEmpty
                || item.title.lowercased().contains(q)
                || item.subtitle.lowercased().contains(q)
                || item.architecture.lowercased().contains(q)
                || item.bootStandard.lowercased().contains(q)
                || item.channel.lowercased().contains(q)
            return matchesChannel && matchesQuery
        }
    }

    var depotHeroSelectedItem: KroutonPantryCatalogItem {
        let items = filteredDepotItems
        if let selID = store.selectedDepotHeroItemID,
           let match = items.first(where: { $0.id == selID }) {
            return match
        }
        return items.first ?? store.depotItems[0]
    }

    var depotChannelHeadline: (badge: String, title: String, subtitle: String) {
        switch store.selectedTaskID {
        case "depot-rescue":
            return (
                "SYSTEM RESCUE & BIOS SUB-LIBRARY",
                "System Rescue & BIOS",
                "Bare-metal El Torito BIOS/UEFI recovery discs, partition editors, RAM analyzers & drive sanitizers."
            )
        case "depot-linux":
            return (
                "LIVE LINUX & BSD SUB-LIBRARY",
                "Live Linux & BSD",
                "Cryptographically verified hybrid ISO/UDF images ready for physical DVD/BD burning or VM test-boot."
            )
        case "depot-vintage":
            return (
                "VINTAGE APPLE & ARCHIVE.ORG SUB-LIBRARY",
                "Vintage Mac & Apple",
                "Bootable HFS Standard & Blessed System Folders for 680x0, PowerPC G3/G4/G5, A/UX & Apple IIgs."
            )
        case "depot-homebrew":
            return (
                "CONSOLE HOMEBREW & BOOT ROMS SUB-LIBRARY",
                "Console Homebrew & ROMs",
                "Legal optical boot discs (Swiss, FreeDVDBoot, UniROM, DreamShell, Pseudo Saturn Kai & 240p Test Suite)."
            )
        case "depot-coverdiscs":
            return (
                "90S COVER DISCS & DEMOSCENE SUB-LIBRARY",
                "90s Cover Discs & Scene",
                "Preserved MacAddict, Macworld, PC Gamer, Next Generation, Amiga Format & Assembly/Scene.org discs."
            )
        case "depot-retropc":
            return (
                "RETRO PC, DOS & ALT OS SUB-LIBRARY",
                "Retro PC, DOS & Alt OS",
                "Bootable optical releases for FreeDOS 1.4, Haiku, BeOS R5, IBM OS/2 Warp 4.52, ReactOS, Plan 9 & IRIX."
            )
        case "depot-ia-live":
            return (
                "INTERNET ARCHIVE LIVE API RESULTS",
                "Internet Archive Optical Software Query",
                "Live results fetched directly from archive.org/advancedsearch.php for optical ISO, BIN/CUE & CD-ROM media."
            )
        default:
            return (
                "COMPLETE OPTICAL LIBRARY (60+ VERIFIED TITLES)",
                "All Depot Library",
                "Select any sub-library in the left column or click any title card below to inspect its details in the Hero deck."
            )
        }
    }









    func addButtonTitle(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat {
            return "Add Audio Tracks (WAV / AIFF / FLAC / MP3)..."
        } else if spec.isCarSafeAudioFormat {
            return "Add Audio Files or Album Folders..."
        } else if spec.isVideoAuthoringFormat {
            return "Add Video Titles (MKV / MP4 / MOV / VIDEO_TS)..."
        } else if spec.isDiscImageBurnFormat {
            return "Select Disc Image (.ISO / .DMG / .BIN / .CUE / .CDR / .TOAST)..."
        } else if spec.id == "console-wii" {
            return "Select Wii Image (.RVZ / .WBFS / .ISO)..."
        } else if spec.id == "console-gc" {
            return "Select GameCube Image (.RVZ / .GCM / .ISO)..."
        } else if spec.id == "console-ps2" {
            return "Select PS2 Image (.ISO / .CHD / .BIN+.CUE)..."
        } else if spec.id == "console-ps1" {
            return "Select PS1 Image (.CUE+.BIN / .CHD / .CCD)..."
        } else if spec.id == "console-xbox" {
            return "Select Xbox Image (.ISO / .XISO / .DVD)..."
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "Select Console Image..."
        } else {
            return "Add Files or Folders..."
        }
    }

    func addButtonSymbol(for spec: KroutonRecipeSpec) -> String {
        if spec.isRedBookAudioFormat || spec.isCarSafeAudioFormat {
            return "waveform.badge.plus"
        } else if spec.isVideoAuthoringFormat {
            return "film.stack.fill"
        } else if spec.isDiscImageBurnFormat {
            return "opticaldisc.fill"
        } else if (spec.filterGroup == .console || spec.id.hasPrefix("console-")) {
            return "gamecontroller.fill"
        } else {
            return "plus.rectangle.on.folder.fill"
        }
    }

    // ==========================================================================
    // 1. RED BOOK AUDIO CD (CD-DA) & CD-EXTRA WAVEBURNER MASTERING STUDIO
    // ==========================================================================


    // ==========================================================================
    // 2. CAR-SAFE MP3 / FLAC AUDIO CD WORKSPACE (Head-Unit Sorting & Sanitizer)
    // ==========================================================================


    // ==========================================================================
    // 3. VIDEO DISC AUTHORING STUDIO (DVD-Video, AVCHD, BD-R SL/DL, UHD-BD)
    // ==========================================================================


    // ==========================================================================
    // 4. RETRO CONSOLE ROM & SECTOR VERIFICATION WORKSPACE (PS1/PS2/GC/Wii/Xbox)
    // ==========================================================================


    // ==========================================================================
    // 5A. DEDICATED DISC IMAGE (.ISO / .BIN / .DMG / .CDR) FULL-WORKSPACE DECK
    //     (Single-Image Radial Platter, Live LBA Hex Scope & Actionable Pills)
    // ==========================================================================


    // ==========================================================================
    // 5B. NEW DATA & ARCHIVAL DISC AUTHORING WORKSPACE
    //     (Author File/Folder Trees with Universal Bridge & Per-File OS Visibility)
    // ==========================================================================


    // MARK: - Retro Console ROM Mastering Deck & Pre-Flight Sanity Engine


    func currentPreFlightSanityWarning(for spec: KroutonRecipeSpec) -> String? {
        if (spec.filterGroup == .console || spec.id.hasPrefix("console-")), let drive = primarySelectedDrive, drive.isMediaPresent && drive.isMediaErasable {
            return "Retro Console Pickup Warning: \(drive.displayName) has rewritable \(drive.mediaType) loaded (~20% reflectivity). Vintage PS1/PS2/GameCube/Dreamcast optical pickups require high-reflectivity write-once CD-R or DVD-R media at 4x–8x."
        }
        if spec.id == "console-ps1" && !store.stagedFiles.isEmpty {
            let hasBin = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".bin") }
            let hasCue = store.stagedFiles.contains { $0.name.lowercased().hasSuffix(".cue") || $0.name.lowercased().hasSuffix(".ccd") }
            if hasBin && !hasCue {
                return "Missing .CUE Descriptor: A raw .BIN track is staged without its companion .CUE sheet. Add the .CUE file to preserve Red Book audio tracks and 2-second pre-gap offsets."
            }
        }
        if let hugeFile = store.stagedFiles.first(where: { $0.exceedsISO9660FourGiBLimit }) {
            return "4 GiB File Limit Notice: '\(hugeFile.name)' exceeds the 4 GiB ISO9660 Level 2 ceiling. Krouton will bridge this file via UDF 2.60 + HFS+."
        }
        if let longFile = store.stagedFiles.first(where: { $0.exceedsJoliet64CharLimit }) {
            return "Joliet 64-Char Notice: '\(longFile.name)' is \(longFile.name.count) characters long. Full name is preserved on Mac (HFS+) and UDF, and safely truncated in legacy Windows Joliet tables."
        }
        return nil
    }

    func promptToAddFiles() {
        let spec = store.activeFormatSpec()
        let exts = spec.allowedFileExtensions
        var types: [UTType] = exts.compactMap { UTType(filenameExtension: $0) }
        if spec.allowsDirectorySelection {
            types.append(.folder)
        }
        if types.isEmpty {
            types = spec.allowsDirectorySelection ? [.item, .folder] : [.item]
        }
        KroutonStageImporterBridge.shared.presentImporter(
            allowedTypes: types,
            allowsMultiple: (spec.id != "image-burn" && spec.filterGroup != .console)
        )
    }

    func triggerDropRejectShake() {
        dropRejectShakePhase = 1.0
        withAnimation(.easeOut(duration: 0.42)) {
            dropRejectShakePhase = 0.0
        }
    }

    func handleFinderDrop(providers: [NSItemProvider]) -> Bool {
        let spec = store.activeFormatSpec()
        var acceptedAny = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                acceptedAny = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let resolvedURL: URL? = {
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        } else if let url = item as? URL {
                            return url
                        }
                        return nil
                    }()
                    guard let url = resolvedURL else { return }
                    Task { @MainActor in
                        if store.selectedCategory == .burn && !store.isURLCompatible(url, for: spec) {
                            store.rejectedDropNotice = "Rejected '\(url.lastPathComponent)': \(spec.technicalName) only accepts \(spec.expectedMediaDescription)."
                            KroutonOSDesktopBridge.playAcousticCue()
                            triggerDropRejectShake()
                        } else {
                            store.addStagedURLs([url])
                        }
                    }
                }
            }
        }
        return acceptedAny
    }
    // MARK: - RIGHT COLUMN: UUID-SAFE DESTINATION CARDS + CLICKABLE DISC MEDIA INSPECTOR PILL


    // Safe UUID-based mutator helper so removing a card never triggers an out-of-bounds index crash
    func updateQueueItem(_ id: UUID, mutate: @escaping (inout KroutonBakeBatchItem) -> Void) {
        guard let idx = store.destinationQueue.firstIndex(where: { $0.id == id }) else { return }
        mutate(&store.destinationQueue[idx])
    }

    // Ensures every physicalBurner card has a unique targetDriveID so 2 cards never select the same drive
    func reconcileUniqueDriveAssignments() {
        guard !driveManager.availableDrives.isEmpty else { return }
        var claimedIDs = Set<String>()
        for idx in store.destinationQueue.indices {
            guard store.destinationQueue[idx].kind == .physicalBurner else { continue }
            let currentID = store.destinationQueue[idx].targetDriveID
            let isValidDrive = driveManager.availableDrives.contains(where: { $0.id == currentID })
            if isValidDrive && !claimedIDs.contains(currentID) {
                claimedIDs.insert(currentID)
            } else if let nextFree = driveManager.availableDrives.first(where: { !claimedIDs.contains($0.id) }) {
                store.destinationQueue[idx].targetDriveID = nextFree.id
                store.destinationQueue[idx].hardwareOrPath = nextFree.displayName
                claimedIDs.insert(nextFree.id)
            }
        }
    }



    func cardActionTitle(for kind: KroutonToasterOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "Burn Disc"
        case .discImage:
            return "Save Image"
        case .audioRip:
            return "Rip Audio"
        case .videoExtract:
            return "Extract Video"
        case .discPrinter:
            return "Print Label"
        case .pdfVector:
            return "Save PDF"
        }
    }

    func cardActionSymbol(for kind: KroutonToasterOutputKind) -> String {
        switch kind {
        case .physicalBurner, .networkBurner:
            return "flame.fill"
        case .discImage:
            return "internaldrive.fill"
        case .audioRip:
            return "waveform"
        case .videoExtract:
            return "film"
        case .discPrinter:
            return "printer.fill"
        case .pdfVector:
            return "doc.richtext.fill"
        }
    }

    func executeSingleDestination(_ target: KroutonBakeBatchItem) {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = KroutonToastReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the operation."
            )
            return
        }

        Task { @MainActor in
            await runTargetDestination(target)
        }
    }



    func executeDestinationQueue() {
        if driveManager.isExecutingQueue {
            driveManager.abortActiveBurn()
            return
        }

        if store.stagedFiles.isEmpty && store.selectedCategory == .burn {
            driveManager.completionReport = KroutonToastReport(
                isSuccess: false,
                title: "File List Is Empty",
                summary: "There are no files or folders staged in the central workspace.",
                driveModel: primarySelectedDrive?.displayName ?? "Optical Burner",
                firmwareRevision: primarySelectedDrive?.firmware ?? "1.0",
                mediaFormattedName: primarySelectedDrive?.mediaType ?? "None",
                volumeName: store.discVolumeTitle,
                sectorsWrittenLBA: 0,
                bytesWritten: 0,
                averageSpeedText: "0.0x",
                peakSpeedText: "0.0x",
                elapsedDurationText: "00:00",
                diagnosticAdvice: "Drag files or folders from Finder into the File List (or click 'Add Media or Files...') before starting the burn."
            )
            return
        }

        Task { @MainActor in
            for target in store.destinationQueue {
                await runTargetDestination(target)
            }
        }
    }

    var allowedDestinationsForCurrentCategory: [KroutonToasterOutputKind] {
        switch store.selectedCategory {
        case .burn, .depot:
            return [.physicalBurner, .networkBurner, .discImage]
        case .copy:
            return [.physicalBurner, .networkBurner, .discImage, .audioRip, .videoExtract]
        case .label:
            return [.discPrinter, .pdfVector]
        }
    }

    func syncDefaultDestinationForCategory(_ category: KroutonBakeryStation, taskID: String) {
        let firstDrive = driveManager.availableDrives.first
        let currentDriveName = firstDrive?.displayName ?? "Optical Drive"
        let currentDriveID = firstDrive?.id ?? ""

        switch category {
        case .burn, .depot:
            store.destinationQueue = [
                KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            ]
        case .copy:
            if taskID == "copy-rip-audio" {
                store.destinationQueue = [
                    KroutonBakeBatchItem(kind: .audioRip, targetDriveID: currentDriveID, hardwareOrPath: "~/Music/Krouton Rips/Apple Lossless", speedOrCodec: "ALAC (.m4a) + AccurateRip", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            } else if taskID == "copy-rip-video" {
                store.destinationQueue = [
                    KroutonBakeBatchItem(kind: .videoExtract, targetDriveID: currentDriveID, hardwareOrPath: "~/Movies/Krouton Extracts", speedOrCodec: "H.265 (HEVC 10-bit Hardware)", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
                ]
            } else {
                store.destinationQueue = [
                    KroutonBakeBatchItem(kind: .physicalBurner, targetDriveID: currentDriveID, hardwareOrPath: currentDriveName, speedOrCodec: "Max Safe (Auto)", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
                ]
            }
        case .label:
            store.destinationQueue = [
                KroutonBakeBatchItem(kind: .discPrinter, targetDriveID: "", hardwareOrPath: "Epson EcoTank Photo ET-8550 (CD/DVD Tray)", speedOrCodec: "Claria ET 6-Ink • 120mm / 18mm", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            ]
        }
    }

    func appendContextAwareDestination() {
        switch store.selectedCategory {
        case .burn, .depot:
            let usedDriveIDs = Set(store.destinationQueue.filter { $0.kind == .physicalBurner }.map { $0.targetDriveID })
            if let nextUnusedDrive = driveManager.availableDrives.first(where: { !usedDriveIDs.contains($0.id) }) {
                store.destinationQueue.append(
                    KroutonBakeBatchItem(
                        kind: .physicalBurner,
                        targetDriveID: nextUnusedDrive.id,
                        hardwareOrPath: nextUnusedDrive.displayName,
                        speedOrCodec: "Max Safe (Auto)",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: false
                    )
                )
            } else {
                store.destinationQueue.append(
                    KroutonBakeBatchItem(
                        kind: .discImage,
                        targetDriveID: "",
                        hardwareOrPath: "~/Desktop/\(store.discVolumeTitle).dmg",
                        speedOrCodec: "Hybrid UDF / HFS+ Image",
                        simulationMode: false,
                        verifyAfterBurn: true,
                        compressAfterCreation: true
                    )
                )
            }
        case .copy:
            store.destinationQueue.append(
                KroutonBakeBatchItem(kind: .discImage, targetDriveID: "", hardwareOrPath: "~/Desktop/Disc_Backup.iso", speedOrCodec: "1:1 Archival Sector Image", simulationMode: false, verifyAfterBurn: true, compressAfterCreation: false)
            )
        case .label:
            store.destinationQueue.append(
                KroutonBakeBatchItem(kind: .pdfVector, targetDriveID: "", hardwareOrPath: "~/Desktop/Epson_ET8550_Label_120mm.pdf", speedOrCodec: "300 DPI Vector PDF Proof", simulationMode: false, verifyAfterBurn: false, compressAfterCreation: false)
            )
        }
    }

    var primaryActionTitle: String {
        switch store.selectedCategory {
        case .burn: return "BURN (\(store.destinationQueue.count))"
        case .depot: return "GET & BURN ISO (\(store.destinationQueue.count))"
        case .copy: return "START COPY / EXTRACT (\(store.destinationQueue.count))"
        case .label: return "PRINT LABEL (\(store.destinationQueue.count))"
        }
    }

    var primaryActionSymbol: String {
        switch store.selectedCategory {
        case .burn: return "flame.fill"
        case .depot: return "arrow.down.doc.fill"
        case .copy: return "doc.on.doc.fill"
        case .label: return "printer.fill"
        }
    }
}
