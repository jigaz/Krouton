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
