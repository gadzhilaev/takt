import WidgetKit
import SwiftUI

/// WidgetKit extension for Takt. Requires App Group `group.ru.gadzhilaev.takt`
/// shared with the Flutter Runner target (configure in Xcode).
struct TaktEntry: TimelineEntry {
    let date: Date
    let projectName: String
    let openCount: Int
    let lines: [String]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaktEntry {
        TaktEntry(date: Date(), projectName: "Takt", openCount: 0, lines: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TaktEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaktEntry>) -> ()) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> TaktEntry {
        let defaults = UserDefaults(suiteName: "group.ru.gadzhilaev.takt")
        let project = defaults?.string(forKey: "project_name") ?? "Takt"
        let count = defaults?.integer(forKey: "open_count") ?? 0
        var lines: [String] = []
        if let raw = defaults?.string(forKey: "snapshot"),
           let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tasks = json["tasks"] as? [[String: Any]] {
            for t in tasks.prefix(5) {
                let title = t["title"] as? String ?? ""
                let prio = t["priority"] as? String ?? "medium"
                let mark = prio == "urgent" ? "!" : (prio == "high" ? "•" : "·")
                lines.append("\(mark) \(title)")
            }
        }
        return TaktEntry(date: Date(), projectName: project, openCount: count, lines: lines)
    }
}

struct TaktHomeWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.projectName)
                .font(.headline)
                .foregroundStyle(Color(red: 0.125, green: 0.161, blue: 0.220))
            Text("\(entry.openCount) незавершённых")
                .font(.caption)
                .foregroundStyle(Color(red: 0.192, green: 0.373, blue: 0.447))
            if family != .systemSmall {
                ForEach(entry.lines.prefix(family == .systemLarge ? 7 : 3), id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 0.969, green: 0.973, blue: 0.980)
        }
        .widgetURL(URL(string: "takt://board"))
    }
}

@main
struct TaktHomeWidget: Widget {
    let kind: String = "TaktHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TaktHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Takt")
        .description("Незавершённые задачи проекта")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
