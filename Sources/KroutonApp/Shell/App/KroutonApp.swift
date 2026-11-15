import NetworkSpool
import DriveKit
import SwiftUI
import Foundation
import AudioToolbox
import ImageIO
import UniformTypeIdentifiers
import OpticalCore

public enum KroutonOSDesktopBridge {
    private static let activeLock = NSLock()
    nonisolated(unsafe) private static var _isVisiblyActive: Bool = true

    public static func setApplicationVisiblyActive(_ active: Bool) {
        activeLock.lock()
        _isVisiblyActive = active
        activeLock.unlock()
    }

    public static func revealInFinder(url: URL) { _ = LSOpenCFURLRef(url as CFURL, nil) }
    static func playAcousticCue() {
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
    let driveManager = KroutonOpticalDriveBank()
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

    func openSettingsWindow(store: KroutonStateStore, driveManager: KroutonOpticalDriveBank, pane: KroutonSettingsCategory? = nil) {
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
            .onAppear {
                KroutonWindowManager.shared.bindSceneActions(openWindow: openWindow, dismissWindow: dismissWindow)
                KroutonCrashRecoveryController.shared.evaluateLaunchStateAndHydrateIfClean(store: KroutonWindowManager.shared.store)
            }
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
            KroutonWorkspaceCommands(wm: wm)
        }

        Window("Krouton Settings", id: "settings") {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 1120, height: 720)

        WindowGroup("Phase Scope", id: "phase-scope", for: String.self) { $driveID in
            let targetID = driveID ?? "network-spool-drive"
            KroutonFloatingPhaseScopeView(
                driveID: targetID,
                store: wm.store,
                driveManager: wm.driveManager,
                onDockInline: { KroutonWindowManager.shared.closeFloatingPhaseScopeWindow(driveID: targetID) }
            )
            .modifier(KroutonSceneActionBinder())
            .onDisappear { wm.driveManager.setFloatingScopeOpen(for: targetID, isOpen: false, keepInlineVisible: true) }
        }
        .defaultSize(width: 780, height: 520)

        Window("Track Montage Editor", id: "track-montage") {
            KroutonFloatingTrackMontageWindowView(store: wm.store)
                .modifier(KroutonSceneActionBinder())
        }
        .defaultSize(width: 960, height: 280)

        Settings {
            KroutonSettingsWindowView(store: wm.store, driveManager: wm.driveManager)
        }
    }
}

struct KroutonMainWorkspaceView: View {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    @ObservedObject var spoolClient: SpoolRemoteNodeClient = .shared

    @State var enableCustomFinderLayoutTab: Bool = false
    @State var finderIconSize: Double = 256
    @State var fitToDiscDVD9Shrink: Bool = true
    @State var preserveMenusAndExtras: Bool = true
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
    // Red Book Audio CD & CD-Extra Mastering State
    @State var cdTextAlbumTitle: String = ""
    @State var cdTextAlbumPerformer: String = ""
    @State var auditioningTrackID: UUID? = nil
    // Car-Safe MP3 / FLAC CD Mastering State
    // Video Disc Authoring & Dual-Layer Break State
    // M-DISC Archival PAR2 State
    // New Data Disc File System Bridge State
    // Dedicated Disc Image Burner State

    var primarySelectedDrive: KroutonOpticalDriveInfo? {
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
            KroutonCrashRecoveryBannerView(store: store)

            GeometryReader { windowGeo in
                let totalW = windowGeo.size.width
                let minLeftW: CGFloat = 182
                let maxLeftW: CGFloat = 340
                let minCenterW: CGFloat = 345
                let minRightW: CGFloat = 262
                let maxRightW: CGFloat = 440
                let splittersW: CGFloat = 22
                let maxAllowedLeft = max(minLeftW, min(maxLeftW, totalW - max(minRightW, rightColumnLiveWidth) - minCenterW - splittersW))
                let clampedLeft = min(max(minLeftW, leftColumnLiveWidth), maxAllowedLeft)
                let maxAllowedRight = max(minRightW, min(maxRightW, totalW - clampedLeft - minCenterW - splittersW))
                let clampedRight = min(max(minRightW, rightColumnLiveWidth), maxAllowedRight)

                let centerLiveW = max(0, totalW - clampedLeft - clampedRight - 22)

                HStack(spacing: 0) {
                    KroutonLeftFormatChooserColumnView(store: store, driveManager: driveManager, isLeftSidebarUltraSkinny: isLeftSidebarUltraSkinny)
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
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { val in
                                if rightSidebarDragStartWidth == nil { rightSidebarDragStartWidth = clampedRight }
                                let startW = rightSidebarDragStartWidth ?? clampedRight
                                let maxR = max(minRightW, min(440, totalW - clampedLeft - minCenterW - 22))
                                let newW = min(max(minRightW, startW - val.translation.width), maxR)
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

                    KroutonDestinationRackColumnView(
                        store: store,
                        driveManager: driveManager,
                        isRightQueueCompact: isRightQueueCompact,
                        enableCustomFinderLayoutTab: enableCustomFinderLayoutTab,
                        finderIconSize: finderIconSize,
                        primarySelectedDrive: primarySelectedDrive
                    )
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
                    isCenterWorkspaceNarrow = centerLiveW < 520
                }
                .onChange(of: clampedRight) { _, newRightW in
                    var tx = Transaction(); tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isRightQueueCompact && newRightW < 355 { isRightQueueCompact = true }
                        else if isRightQueueCompact && newRightW > 368 { isRightQueueCompact = false }
                    }
                }
                .onChange(of: clampedLeft) { _, newLeftW in
                    var tx = Transaction(); tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isLeftSidebarCompact && newLeftW < 258 { isLeftSidebarCompact = true }
                        else if isLeftSidebarCompact && newLeftW > 272 { isLeftSidebarCompact = false }
                        if !isLeftSidebarUltraSkinny && newLeftW < 215 { isLeftSidebarUltraSkinny = true }
                        else if isLeftSidebarUltraSkinny && newLeftW > 228 { isLeftSidebarUltraSkinny = false }
                    }
                }
                .onChange(of: centerLiveW) { _, newCenterW in
                    // Hysteresis deadband (705pt <-> 735pt) for Center Workspace 1-Column / 2-Column & Hero Schematic box!
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if !isCenterWorkspaceNarrow && newCenterW < 510 {
                            isCenterWorkspaceNarrow = true
                        } else if isCenterWorkspaceNarrow && newCenterW > 535 {
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
        .preferredColorScheme(store.resolvedColorScheme)
        .environment(\.locale, store.activeLocale)
        .tint(store.activeAccent)
        .onAppear { store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: driveManager.availableDrives) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: store.selectedTaskID) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .onChange(of: store.selectedCategory) { _, _ in store.reconcileUniqueDriveAssignments(driveManager: driveManager) }
        .sheet(item: $driveManager.completionReport) { report in
            KroutonMasteringReportSheet(report: report, accent: store.activeAccent) {
                driveManager.completionReport = nil
            }
        }
        .modifier(KroutonStageImporterModifier(store: store))
        .modifier(KroutonProjectSheetModifier(store: store, driveManager: driveManager))
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



    // MARK: - CENTER COLUMN: ADAPTABLE WORKSPACE + INTEGRATED CAPACITY BAR (Global graph removed)
    var centerAdaptableWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                switch store.selectedCategory {
                case .burn:
                    KroutonBurnStationWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive,
                        isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                        enableCustomFinderLayoutTab: $enableCustomFinderLayoutTab,
                        finderIconSize: $finderIconSize,
                        fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                        preserveMenusAndExtras: preserveMenusAndExtras,
                        cdTextAlbumTitle: $cdTextAlbumTitle,
                        cdTextAlbumPerformer: $cdTextAlbumPerformer,
                        auditioningTrackID: $auditioningTrackID,
                        isDropTargeted: $isDropTargeted,
                        onPromptToAddFiles: promptToAddFiles,
                        onHandleFinderDrop: handleFinderDrop(providers:)
                    )
                        .offset(x: sin(dropRejectShakePhase * .pi * 4) * 8)
                case .depot:
                    KroutonDepotWorkspaceView(store: store, isCenterWorkspaceNarrow: isCenterWorkspaceNarrow)
                case .copy:
                    KroutonCopyAndRipWorkspaceView(
                        store: store,
                        primarySelectedDrive: primarySelectedDrive,
                        isCenterWorkspaceNarrow: isCenterWorkspaceNarrow,
                        fitToDiscDVD9Shrink: $fitToDiscDVD9Shrink,
                        preserveMenusAndExtras: $preserveMenusAndExtras,
                        cdTextAlbumTitle: $cdTextAlbumTitle,
                        cdTextAlbumPerformer: $cdTextAlbumPerformer
                    )
                case .label:
                    KroutonDiscLabelWorkspaceView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Integrated Central Workspace Capacity Allocation Bar (Hidden in Label Designer mode)
            if store.selectedCategory != .label {
                KroutonCentralWorkspaceCapacityBarView(store: store, activeDiscCapacityBytes: activeDiscCapacityBytes, primarySelectedDrive: primarySelectedDrive)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        final class URLDropCollector: @unchecked Sendable {
            let lock = NSLock()
            var urls: [URL] = []
        }
        let group = DispatchGroup()
        let collector = URLDropCollector()

        for provider in matching {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let resolvedURL: URL? = {
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    } else if let url = item as? URL {
                        return url
                    }
                    return nil
                }()
                if let url = resolvedURL {
                    collector.lock.lock()
                    collector.urls.append(url)
                    collector.lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            let beforeReject = store.rejectedDropNotice
            store.addStagedURLs(collector.urls)
            if store.rejectedDropNotice != nil && store.rejectedDropNotice != beforeReject {
                triggerDropRejectShake()
            }
        }
        return true
    }
}

struct KroutonProjectSheetModifier: ViewModifier {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject var driveManager: KroutonOpticalDriveBank
    @ObservedObject private var bridge = KroutonProjectDialogBridge.shared

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $bridge.isShowingExporter,
                document: bridge.exportDocument,
                contentType: .kroutonProject,
                defaultFilename: bridge.defaultFilename
            ) { _ in }
            .fileImporter(
                isPresented: $bridge.isShowingImporter,
                allowedContentTypes: [.kroutonProject, .json],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result,
                   let url = urls.first,
                   let data = try? Data(contentsOf: url),
                   let manifest = try? KroutonProjectManifest.decode(from: data) {
                    store.applyProjectManifest(manifest, projectURL: url, driveManager: driveManager)
                }
            }
    }
}
