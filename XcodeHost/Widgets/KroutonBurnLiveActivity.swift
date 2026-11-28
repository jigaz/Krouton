// MARK: - Live Activity (macOS 27.3 and later)

// Built only with the macOS 27.3 SDK, which adds ActivityKit for Mac apps: set
// KROUTON_LIVE_ACTIVITIES in project.yml's widget target and add KroutonBurnLiveActivity() to
// KroutonWidgets. Plan and model: dev-notes/live-updates-iphone-watch-mac.md (plan A).
#if KROUTON_LIVE_ACTIVITIES
import ActivityKit
import OpticalCore
import SwiftUI
import WidgetKit

struct KroutonBurnAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var fraction: Double?
        var expectedEnd: Date?
    }
    var volumeTitle: String
    var drive: String
}

struct KroutonBurnLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KroutonBurnAttributes.self) { context in
            VStack(alignment: .leading) {
                Text(context.attributes.volumeTitle).font(.headline)
                if let end = context.state.expectedEnd {
                    ProgressView(timerInterval: Date()...end, countsDown: false)
                } else if let fraction = context.state.fraction {
                    ProgressView(value: fraction)
                }
                Text(context.state.phase).font(.caption)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text(context.state.phase) }
            } compactLeading: {
                Image(systemName: "opticaldisc")
            } compactTrailing: {
                Text(verbatim: context.state.fraction.map { "\(Int($0 * 100))%" } ?? "")
            } minimal: {
                Image(systemName: "opticaldisc")
            }
        }
    }
}
#endif
