import OpticalCore
import SwiftUI
import WidgetKit

// MARK: - Krouton's Widgets

/// The widget extension: the desktop and Notification Center status widget. The Live Activity
/// (`KroutonBurnLiveActivity.swift`) joins it when built with the macOS 27.3 SDK.
@main
struct KroutonWidgets: WidgetBundle {
    var body: some Widget {
        KroutonStatusWidget()
    }
}

// MARK: - Status Widget

struct KroutonStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: KroutonWidgetSnapshot?
}

struct KroutonStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> KroutonStatusEntry {
        KroutonStatusEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (KroutonStatusEntry) -> Void) {
        completion(KroutonStatusEntry(date: Date(), snapshot: context.isPreview ? .sample : KroutonWidgetSnapshot.read()))
    }

    /// The app reloads the widget on every change, so the timeline only needs a slow refresh
    /// for the "2 hours ago" text.
    func getTimeline(in context: Context, completion: @escaping (Timeline<KroutonStatusEntry>) -> Void) {
        let entry = KroutonStatusEntry(date: Date(), snapshot: KroutonWidgetSnapshot.read())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct KroutonStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: KroutonWidgetSnapshot.widgetKind, provider: KroutonStatusProvider()) { entry in
            KroutonStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Krouton")
        .description("What Krouton is burning, copying or downloading, and the last disc it finished.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct KroutonStatusWidgetView: View {
    let entry: KroutonStatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Krouton", systemImage: "opticaldisc")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if let tasks = entry.snapshot?.tasks, !tasks.isEmpty {
                ForEach(Array(tasks.prefix(family == .systemSmall ? 1 : 3).enumerated()), id: \.offset) { _, task in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.headline)
                            .lineLimit(1)
                        if let fraction = task.fraction {
                            ProgressView(value: fraction)
                            Text(verbatim: "\(Int((fraction * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView().progressViewStyle(.linear)
                        }
                    }
                }
            } else if let finished = entry.snapshot?.lastFinished, let at = entry.snapshot?.lastFinishedAt {
                Text("Nothing running")
                    .font(.headline)
                Text("\(finished) finished \(at, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing running")
                    .font(.headline)
                Text("Open Krouton to burn, copy or rip a disc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

extension KroutonWidgetSnapshot {
    static var sample: KroutonWidgetSnapshot {
        KroutonWidgetSnapshot(tasks: [Task(title: "Writing", detail: "Holiday Photos", fraction: 0.42, symbol: "opticaldisc")],
                              lastFinished: nil, lastFinishedAt: nil)
    }
}
