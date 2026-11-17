import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Check-in snapshot (App Group, written by the app; no JWT)

struct CheckinTask: Identifiable, Hashable {
    let id: String
    let title: String
    let priority: String
    var answer: String?
}

struct CheckinSnapshot {
    let checkinId: String
    let projectName: String
    let date: String
    let token: String
    let actionPath: String
    var tasks: [CheckinTask]

    var total: Int { tasks.count }
    var answered: Int { tasks.filter { $0.answer != nil }.count }
    var open: [CheckinTask] { tasks.filter { $0.answer == nil } }
}

enum CheckinStore {
    static let suite = "group.ru.gadzhilaev.takt"
    static let key = "checkin"

    static func defaults() -> UserDefaults? { UserDefaults(suiteName: suite) }

    static func apiBase() -> String {
        defaults()?.string(forKey: "takt_api_base") ?? "https://taktapp.ru"
    }

    static func load() -> CheckinSnapshot? {
        guard let raw = defaults()?.string(forKey: key), !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["checkin_id"] as? String,
              let token = json["token"] as? String
        else { return nil }
        let tasks = (json["tasks"] as? [[String: Any]] ?? []).compactMap { t -> CheckinTask? in
            guard let tid = t["id"] as? String else { return nil }
            return CheckinTask(
                id: tid,
                title: t["title"] as? String ?? "Задача",
                priority: t["priority"] as? String ?? "medium",
                answer: t["answer"] as? String
            )
        }
        return CheckinSnapshot(
            checkinId: id,
            projectName: json["project_name"] as? String ?? "",
            date: json["date"] as? String ?? "",
            token: token,
            actionPath: json["action_path"] as? String ?? "/api/v1/rhythm/push-answer",
            tasks: tasks
        )
    }

    /// Optimistic local update after a successful answer from the widget.
    static func markAnswered(taskId: String, answer: String) {
        guard let raw = defaults()?.string(forKey: key),
              let data = raw.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var tasks = json["tasks"] as? [[String: Any]]
        else { return }
        for i in tasks.indices where tasks[i]["id"] as? String == taskId {
            tasks[i]["answer"] = answer
        }
        json["tasks"] = tasks
        json["answered"] = tasks.filter { $0["answer"] is String }.count
        if let out = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: out, encoding: .utf8) {
            defaults()?.set(str, forKey: key)
        }
    }

    /// Today's local date in Moscow-agnostic form: the server checks the real day anyway.
    static func isToday(_ snapshot: CheckinSnapshot) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Moscow")
        let today = f.string(from: Date())
        // Allow ±1 day of device/project timezone skew; the server is the source of truth.
        guard let d = f.date(from: snapshot.date), let t = f.date(from: today) else { return true }
        return abs(d.timeIntervalSince(t)) <= 86_400
    }
}

// MARK: - «Сделал» from the widget (iOS 17 interactive widget)

struct MarkCheckinDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить задачу сделанной"
    static var description = IntentDescription("Ответ «Сделал» на сегодняшний чек-ин Takt")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Чек-ин") var checkinId: String
    @Parameter(title: "Задача") var taskId: String

    init() {}

    init(checkinId: String, taskId: String) {
        self.checkinId = checkinId
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        guard let snap = CheckinStore.load(), snap.checkinId == checkinId else { return .result() }
        let body: [String: Any] = [
            "checkin_id": checkinId,
            "task_id": taskId,
            "answer": "done",
            "token": snap.token,
        ]
        guard let url = URL(string: snap.actionPath, relativeTo: URL(string: CheckinStore.apiBase())),
              let data = try? JSONSerialization.data(withJSONObject: body)
        else { return .result() }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        if let (_, resp) = try? await URLSession.shared.data(for: request),
           let code = (resp as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) {
            CheckinStore.markAnswered(taskId: taskId, answer: "done")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: TaktCheckinWidget.kind)
        return .result()
    }
}

// MARK: - Timeline

struct CheckinEntry: TimelineEntry {
    let date: Date
    let snapshot: CheckinSnapshot?
}

struct CheckinProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckinEntry {
        CheckinEntry(
            date: Date(),
            snapshot: CheckinSnapshot(
                checkinId: "demo", projectName: "Колледж", date: "", token: "", actionPath: "",
                tasks: [
                    CheckinTask(id: "1", title: "Перенести расписание в журнал", priority: "urgent"),
                    CheckinTask(id: "2", title: "Настроить проектор", priority: "high"),
                    CheckinTask(id: "3", title: "Проверить Wi‑Fi", priority: "medium"),
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckinEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckinEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [current()], policy: .after(next)))
    }

    private func current() -> CheckinEntry {
        let snap = CheckinStore.load().flatMap { CheckinStore.isToday($0) ? $0 : nil }
        return CheckinEntry(date: Date(), snapshot: snap)
    }
}

// MARK: - Views

private let accent = Color(red: 0x31 / 255, green: 0x5F / 255, blue: 0x72 / 255)
private let doneGreen = Color(red: 0x2F / 255, green: 0x6B / 255, blue: 0x4F / 255)

private func priorityDot(_ p: String) -> Color {
    switch p {
    case "urgent": return Color(red: 0.78, green: 0.25, blue: 0.25)
    case "high": return Color(red: 0.77, green: 0.48, blue: 0.07)
    default: return Color(red: 0.20, green: 0.43, blue: 0.55)
    }
}

struct CheckinWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CheckinEntry

    var body: some View {
        content
            .widgetURL(URL(string: "takt://checkin"))
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular || family == .accessoryInline || family == .accessoryCircular {
                    Color.clear
                } else {
                    Color(UIColor.systemBackground)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: home
        }
    }

    private var inline: some View {
        if let s = entry.snapshot, !s.open.isEmpty {
            return Text("Чек-ин: \(s.answered) из \(s.total)")
        }
        return Text(entry.snapshot == nil ? "Чек-ина нет" : "Чек-ин пройден")
    }

    private var circular: some View {
        let s = entry.snapshot
        let value = s.map { Double($0.answered) / Double(max($0.total, 1)) } ?? 1
        return Gauge(value: value) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text(s.map { "\($0.open.count)" } ?? "✓")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.snapshot.map { "Чек-ин · \($0.answered)/\($0.total)" } ?? "Чек-ин")
                .font(.headline)
            if let first = entry.snapshot?.open.first {
                Text(first.title).font(.caption).lineLimit(2)
            } else {
                Text(entry.snapshot == nil ? "На сегодня вопросов нет" : "Все ответы даны")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle").foregroundStyle(accent)
                Text("Чек-ин").font(.headline)
                Spacer(minLength: 0)
                if let s = entry.snapshot {
                    Text("\(s.answered)/\(s.total)").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let s = entry.snapshot, !s.open.isEmpty {
                let limit = family == .systemSmall ? 2 : (family == .systemMedium ? 3 : 5)
                ForEach(s.open.prefix(limit)) { task in
                    HStack(spacing: 6) {
                        Circle().fill(priorityDot(task.priority)).frame(width: 6, height: 6)
                        Text(task.title).font(.caption).lineLimit(family == .systemSmall ? 2 : 1)
                        Spacer(minLength: 4)
                        Button(intent: MarkCheckinDoneIntent(checkinId: s.checkinId, taskId: task.id)) {
                            // В маленьком виджете места нет: галочка вместо слова, чтобы не рвать «Сделал».
                            if family == .systemSmall {
                                Image(systemName: "checkmark").font(.caption2.weight(.bold))
                                    .accessibilityLabel("Сделал")
                            } else {
                                Text("Сделал").font(.caption2.weight(.semibold)).fixedSize()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(doneGreen)
                        .controlSize(.mini)
                    }
                }
                Spacer(minLength: 0)
                Text(s.projectName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Spacer(minLength: 0)
                Text(entry.snapshot == nil ? "На сегодня вопросов нет" : "Все ответы даны — доска обновлена")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }
}

struct TaktCheckinWidget: Widget {
    static let kind = "TaktCheckinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CheckinProvider()) { entry in
            CheckinWidgetView(entry: entry)
        }
        .configurationDisplayName("Чек-ин")
        .description("Сегодняшние вопросы по задачам — «Сделал» прямо с экрана.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
    }
}

// MARK: - Live Activity

struct TaktLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaktActivityAttributes.self) { context in
            LiveActivityLockView(context: context)
                .activityBackgroundTint(Color(UIColor.systemBackground))
                .widgetURL(URL(string: context.attributes.url))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.kind == "checkin" ? "Чек-ин" : "Срок", systemImage: icon(context.state))
                        .font(.caption)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing(context.state).font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(context.state.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: icon(context.state)).foregroundStyle(accent)
            } compactTrailing: {
                trailing(context.state).font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: icon(context.state)).foregroundStyle(accent)
            }
            .widgetURL(URL(string: context.attributes.url))
        }
    }

    private func icon(_ s: TaktActivityAttributes.ContentState) -> String {
        s.kind == "checkin" ? "checkmark.circle" : "timer"
    }

    @ViewBuilder private func trailing(_ s: TaktActivityAttributes.ContentState) -> some View {
        if s.kind == "deadline", let d = s.deadline, d > Date() {
            Text(timerInterval: Date()...d, countsDown: true).frame(maxWidth: 56)
        } else {
            Text("\(s.answered)/\(s.total)")
        }
    }
}

private struct LiveActivityLockView: View {
    let context: ActivityViewContext<TaktActivityAttributes>

    var body: some View {
        let s = context.state
        HStack(spacing: 12) {
            Image(systemName: s.kind == "checkin" ? "checkmark.circle" : "timer")
                .font(.title2)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title).font(.headline).lineLimit(1)
                Text(s.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(context.attributes.projectName).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if s.kind == "deadline", let d = s.deadline, d > Date() {
                Text(timerInterval: Date()...d, countsDown: true)
                    .font(.headline.monospacedDigit())
                    .frame(maxWidth: 80)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("\(s.answered)/\(s.total)").font(.title3.weight(.semibold).monospacedDigit())
            }
        }
        .padding(14)
    }
}

// MARK: - Bundle

@main
struct TaktWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaktHomeWidget()
        TaktCheckinWidget()
        TaktLiveActivityWidget()
    }
}
