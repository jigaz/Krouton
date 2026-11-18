import AudioToolbox
import DriveKit
import Foundation
import ImageIO
import NetworkSpool
import OpticalCore
import SwiftUI
import UniformTypeIdentifiers
import os

// MARK: - Main Workspace File Panel, Drag-and-Drop Collector & Project Sheet Modifier

extension KroutonMainWorkspaceView {
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
        guard !matching.isEmpty else { return false
}

        let group = DispatchGroup()
        let collectedURLs = OSAllocatedUnfairLock(initialState: [URL]())

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
                    collectedURLs.withLock { $0.append(url) }
                }
            }
        }
        group.notify(queue: .main) {
            let beforeReject = store.rejectedDropNotice
            store.addStagedURLs(collectedURLs.withLock { $0 })
            if store.rejectedDropNotice != nil && store.rejectedDropNotice != beforeReject {
                triggerDropRejectShake()
            }
        }
        return true
    }

    @ViewBuilder
    func splitColumnsLayout(windowSize: CGSize) -> some View {
        let totalW = windowSize.width
        let minLeftW: CGFloat = 182
        let maxLeftW: CGFloat = 340
        let minCenterW: CGFloat = 345
        let minRightW: CGFloat = 262
        let maxRightW: CGFloat = 440
        let splittersW: CGFloat = (isLeftSidebarCollapsed ? 0 : 11) + (isRightSidebarCollapsed ? 0 : 11)
        let effectiveRightRef = isRightSidebarCollapsed ? 0 : max(minRightW, rightColumnLiveWidth)
        let maxAllowedLeft = max(minLeftW, min(maxLeftW, totalW - effectiveRightRef - minCenterW - splittersW))
        let clampedLeft = min(max(minLeftW, leftColumnLiveWidth), maxAllowedLeft)
        let drawLeftW: CGFloat = isLeftSidebarCollapsed ? 0 : clampedLeft
        let maxAllowedRight = max(minRightW, min(maxRightW, totalW - drawLeftW - minCenterW - splittersW))
        let clampedRight = min(max(minRightW, rightColumnLiveWidth), maxAllowedRight)
        let drawRightW: CGFloat = isRightSidebarCollapsed ? 0 : clampedRight
        let centerLiveW = max(0, totalW - drawLeftW - drawRightW - splittersW)

        HStack(spacing: 0) {
            if !isLeftSidebarCollapsed {
                KroutonLeftFormatChooserColumnView(store: store, driveManager: driveManager, isLeftSidebarUltraSkinny: isLeftSidebarUltraSkinny)
                    .frame(width: clampedLeft)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .transition(.move(edge: .leading))

                leftColumnSplitter(totalW: totalW, clampedLeft: clampedLeft, drawRightW: drawRightW, minCenterW: minCenterW)
            }

            centerAdaptableWorkspace
                .frame(width: centerLiveW)
                .frame(maxHeight: .infinity)
                .clipped()

            if !isRightSidebarCollapsed {
                rightColumnSplitter(totalW: totalW, drawLeftW: drawLeftW, clampedRight: clampedRight, minRightW: minRightW, minCenterW: minCenterW)

                KroutonDestinationRackColumnView(
                    store: store,
                    driveManager: driveManager,
                    isRightQueueCompact: isRightQueueCompact,
                    primarySelectedDrive: primarySelectedDrive
                )
                .frame(width: clampedRight)
                .frame(maxHeight: .infinity)
                .clipped()
                .transition(.move(edge: .trailing))
            }
        }
        .frame(width: totalW, alignment: .leading)
        .coordinateSpace(name: "KroutonSplitSpace")
        .overlay {
            KroutonGuidedTutorialOverlayView(
                store: store,
                driveManager: driveManager,
                leftWidth: drawLeftW,
                centerWidth: centerLiveW,
                rightWidth: drawRightW,
                totalSize: windowSize
            )
        }
        .onAppear {
            isLeftSidebarCompact = clampedLeft < 265
            isLeftSidebarUltraSkinny = clampedLeft < 215
            isRightQueueCompact = clampedRight < 355
            isCenterWorkspaceUltraCompact = centerLiveW < 500
            isCenterWorkspaceNarrow = centerLiveW < 520
        }
        .onChange(of: centerLiveW) { _, newCenterW in
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

    private func leftColumnSplitter(totalW: CGFloat, clampedLeft: CGFloat, drawRightW: CGFloat, minCenterW: CGFloat) -> some View {
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
                    let maxL = max(182, min(340, totalW - drawRightW - minCenterW - 22))
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
    }

    private func rightColumnSplitter(totalW: CGFloat, drawLeftW: CGFloat, clampedRight: CGFloat, minRightW: CGFloat, minCenterW: CGFloat) -> some View {
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
                    let maxR = max(minRightW, min(440, totalW - drawLeftW - minCenterW - 22))
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
    }
}


struct KroutonProjectSheetModifier: ViewModifier {
    var store: KroutonStateStore
    var driveManager: KroutonOpticalDriveBank
    var bridge = KroutonProjectDialogBridge.shared

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: Bindable(bridge).isShowingExporter,
                document: bridge.exportDocument,
                contentType: .kroutonProject,
                defaultFilename: bridge.defaultFilename
            ) { _ in }
            .fileImporter(
                isPresented: Bindable(bridge).isShowingImporter,
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
