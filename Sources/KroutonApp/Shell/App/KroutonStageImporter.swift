import OpticalCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Deterministic SwiftUI .fileImporter Coordinator for Optical Payloads & Copy/Rip Paths

public enum KroutonImporterIntent: Sendable {
    case stageOpticalPayload
    case customCallback
}

@MainActor
final class KroutonStageImporterBridge: ObservableObject {
    static let shared = KroutonStageImporterBridge()
    @Published var isShowingImporter: Bool = false
    @Published var allowedTypes: [UTType] = [.item, .folder]
    @Published var allowsMultipleSelection: Bool = true
    @Published var activeIntent: KroutonImporterIntent = .stageOpticalPayload
    var customCompletion: (([URL]) -> Void)? = nil

    func presentImporter(allowedTypes: [UTType], allowsMultiple: Bool, onPick: (([URL]) -> Void)? = nil) {
        self.allowedTypes = allowedTypes.isEmpty ? [.item, .folder] : allowedTypes
        self.allowsMultipleSelection = allowsMultiple
        self.activeIntent = (onPick == nil) ? .stageOpticalPayload : .customCallback
        self.customCompletion = onPick
        self.isShowingImporter = true
    }
}

struct KroutonStageImporterModifier: ViewModifier {
    @ObservedObject var store: KroutonStateStore
    @ObservedObject private var bridge = KroutonStageImporterBridge.shared

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $bridge.isShowingImporter,
            allowedContentTypes: bridge.allowedTypes,
            allowsMultipleSelection: bridge.allowsMultipleSelection
        ) { result in
            defer {
                bridge.customCompletion = nil
                bridge.activeIntent = .stageOpticalPayload
            }
            if case .success(let urls) = result {
                if let custom = bridge.customCompletion {
                    custom(urls)
                } else {
                    store.addStagedURLs(urls)
                }
            }
        }
    }
}
