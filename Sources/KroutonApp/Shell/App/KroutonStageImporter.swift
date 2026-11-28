import Observation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Open Panel for Adding Files

/// What the open panel's result is for: the deck, or a caller's own completion.
enum KroutonImporterIntent: Sendable {
    case stageOpticalPayload
    case customCallback
}

/// Lets any code (a menu item, a button deep in a workspace) show the one SwiftUI
/// `.fileImporter` that `KroutonStageImporterModifier` attaches to the main window.
@Observable
@MainActor
final class KroutonStageImporterBridge {
    static let shared = KroutonStageImporterBridge()
    var isShowingImporter: Bool = false
    var allowedTypes: [UTType] = [.item, .folder]
    var allowsMultipleSelection: Bool = true
    var activeIntent: KroutonImporterIntent = .stageOpticalPayload
    var customCompletion: (([URL]) -> Void)? = nil

    func presentImporter(allowedTypes: [UTType], allowsMultiple: Bool, onPick: (([URL]) -> Void)? = nil) {
        self.allowedTypes = allowedTypes.isEmpty ? [.item, .folder] : allowedTypes
        self.allowsMultipleSelection = allowsMultiple
        self.activeIntent = (onPick == nil) ? .stageOpticalPayload : .customCallback
        self.customCompletion = onPick
        self.isShowingImporter = true
    }
}

/// Attaches the open panel to the main window and sends what's picked to the deck or to the
/// caller's completion.
struct KroutonStageImporterModifier: ViewModifier {
    var store: KroutonStateStore
    @State private var bridge = KroutonStageImporterBridge.shared

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: Bindable(bridge).isShowingImporter,
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
