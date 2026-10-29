import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Config Intent (per-instance)

enum TaskModeAppEnum: String, AppEnum {
    case mine
    case all

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Режим задач")
    static var caseDisplayRepresentations: [TaskModeAppEnum: DisplayRepresentation] = [
        .mine: "Мои задачи",
        .all: "Все задачи",
    ]
}

struct ProjectEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Проект")
    static var defaultQuery = ProjectEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ProjectEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        SnapshotStore.projects().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        SnapshotStore.projects()
    }

    func defaultResult() async -> ProjectEntity? {
        SnapshotStore.projects().first
    }
}

struct TaktWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Takt"
    static var description = IntentDescription("Задачи проекта на главном экране и экране блокировки")

    @Parameter(title: "Режим", default: .mine)
    var mode: TaskModeAppEnum

    @Parameter(title: "Проект")
    var project: ProjectEntity?

    init() {
        mode = .mine
        project = nil
    }

    init(mode: TaskModeAppEnum, project: ProjectEntity?) {
        self.mode = mode
        self.project = project
    }
}

// MARK: - Model

struct WidgetTask: Identifiable, Hashable {
    let id: String
    let title: String
    let priority: String
    let statusName: String
    let projectId: String
}

struct TaktEntry: TimelineEntry {
    let date: Date
    let loggedIn: Bool
    let mode: TaskModeAppEnum
    let titleLabel: String
    let projectName: String
    let projectId: String
    let openCount: Int
    let urgentCount: Int
    let tasks: [WidgetTask]
}

// MARK: - Snapshot store (App Group, no tokens)

enum SnapshotStore {
    static let suite = "group.ru.gadzhilaev.takt"

    static func defaults() -> UserDefaults? {
        UserDefaults(suiteName: suite)
    }

    static func projects() -> [ProjectEntity] {
        guard let json = loadJSON() else { return [] }
        var out: [ProjectEntity] = []
        if let list = json["projects"] as? [[String: Any]] {
            for p in list {
                let id = p["id"] as? String ?? ""
                let name = p["name"] as? String ?? ""
                if !id.isEmpty, !name.isEmpty {
                    out.append(ProjectEntity(id: id, name: name))
                }
            }
        }
        if out.isEmpty {
            let id = json["default_project_id"] as? String ?? json["project_id"] as? String ?? ""
            let name = json["project_name"] as? String ?? "Проект"
            if !id.isEmpty { out.append(ProjectEntity(id: id, name: name)) }
        }
        return out
    }

    static func loadJSON() -> [String: Any]? {
        guard let raw = defaults()?.string(forKey: "snapshot"),
              !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    static func entry(for configuration: TaktWidgetConfigIntent) -> TaktEntry {
        let defaults = defaults()
        var loggedIn = defaults?.object(forKey: "logged_in") as? Bool
        let mode = configuration.mode
        let modeKey = mode == .all ? "all" : "mine"
        let titleLabel = mode == .all ? "Все задачи" : "Мои задачи"

        var projectId = configuration.project?.id ?? ""
        var projectName = configuration.project?.name ?? ""
        var openCount = 0
        var urgentCount = 0
        var tasks: [WidgetTask] = []

        if let json = loadJSON() {
            if let flag = json["logged_in"] as? Bool { loggedIn = flag }
            if projectId.isEmpty {
                projectId = (json["default_project_id"] as? String)
                    ?? (json["project_id"] as? String)
                    ?? ""
            }
            if let byProject = json["by_project"] as? [String: Any],
               let bucket = byProject[projectId] as? [String: Any] {
                if projectName.isEmpty {
                    projectName = bucket["project_name"] as? String ?? projectName
                }
                if let scope = bucket[modeKey] as? [String: Any] {
                    openCount = scope["open_count"] as? Int ?? 0
                    urgentCount = scope["urgent_count"] as? Int ?? 0
                    tasks = parseTasks(scope["tasks"] as? [[String: Any]], fallbackProject: projectId)
                }
            } else {
                // v2 fallback — only "mine" style payload
                projectName = json["project_name"] as? String ?? projectName
                projectId = json["project_id"] as? String ?? projectId
                openCount = json["open_count"] as? Int ?? 0
                urgentCount = json["urgent_count"] as? Int ?? 0
                tasks = parseTasks(json["tasks"] as? [[String: Any]], fallbackProject: projectId)
            }
        } else {
            openCount = defaults?.integer(forKey: "open_count") ?? 0
            urgentCount = defaults?.integer(forKey: "urgent_count") ?? 0
            projectName = defaults?.string(forKey: "project_name") ?? projectName
        }

        if projectName.isEmpty { projectName = "Takt" }
        let isLoggedIn = loggedIn ?? ((!projectName.isEmpty && projectName != "Takt") || openCount > 0 || !tasks.isEmpty)

        return TaktEntry(
            date: Date(),
            loggedIn: isLoggedIn,
            mode: mode,
            titleLabel: titleLabel,
            projectName: projectName,
            projectId: projectId,
            openCount: openCount,
            urgentCount: urgentCount,
            tasks: tasks
        )
    }

    private static func parseTasks(_ list: [[String: Any]]?, fallbackProject: String) -> [WidgetTask] {
        guard let list else { return [] }
        return list.prefix(8).map { t in
            WidgetTask(
                id: t["id"] as? String ?? UUID().uuidString,
                title: t["title"] as? String ?? "",
                priority: t["priority"] as? String ?? "medium",
                statusName: t["status_name"] as? String ?? "",
                projectId: (t["project_id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackProject
            )
        }
    }
}

// MARK: - Timeline

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaktEntry {
        TaktEntry(
            date: Date(),
            loggedIn: true,
            mode: .mine,
            titleLabel: "Мои задачи",
            projectName: "Takt",
            projectId: "",
            openCount: 3,
            urgentCount: 1,
            tasks: [
                WidgetTask(id: "1", title: "Пример задачи", priority: "urgent", statusName: "В работе", projectId: ""),
                WidgetTask(id: "2", title: "Ещё одна задача", priority: "high", statusName: "К выполнению", projectId: ""),
            ]
        )
    }

    func snapshot(for configuration: TaktWidgetConfigIntent, in context: Context) async -> TaktEntry {
        SnapshotStore.entry(for: configuration)
    }

    func timeline(for configuration: TaktWidgetConfigIntent, in context: Context) async -> Timeline<TaktEntry> {
        let entry = SnapshotStore.entry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Colors

private enum TaktColor {
    static let accent = Color(red: 49 / 255, green: 95 / 255, blue: 114 / 255)
    static let graphite = Color(red: 32 / 255, green: 41 / 255, blue: 56 / 255)
    static let muted = Color(red: 102 / 255, green: 116 / 255, blue: 133 / 255)
    static let surface = Color.white
    static let board = Color(red: 233 / 255, green: 237 / 255, blue: 242 / 255)

    static let urgent = Color(red: 198 / 255, green: 63 / 255, blue: 63 / 255)
    static let high = Color(red: 196 / 255, green: 122 / 255, blue: 18 / 255)
    static let medium = Color(red: 50 / 255, green: 110 / 255, blue: 139 / 255)

    static let accentDark = Color(red: 106 / 255, green: 154 / 255, blue: 171 / 255)
    static let graphiteDark = Color(red: 231 / 255, green: 235 / 255, blue: 239 / 255)
    static let mutedDark = Color(red: 174 / 255, green: 184 / 255, blue: 195 / 255)
    static let surfaceDark = Color(red: 53 / 255, green: 61 / 255, blue: 71 / 255)
    static let boardDark = Color(red: 34 / 255, green: 39 / 255, blue: 46 / 255)
}

private func priorityColor(_ priority: String) -> Color {
    switch priority {
    case "urgent": return TaktColor.urgent
    case "high": return TaktColor.high
    default: return TaktColor.medium
    }
}

private func urgentEnding(_ n: Int) -> String {
    let mod10 = n % 10
    let mod100 = n % 100
    if mod10 == 1 && mod100 != 11 { return "ая" }
    if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return "ые" }
    return "ых"
}

private func taskWord(_ n: Int) -> String {
    let mod10 = n % 10
    let mod100 = n % 100
    if mod10 == 1 && mod100 != 11 { return "задача" }
    if mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14) { return "задачи" }
    return "задач"
}

// MARK: - Brand mark

/// Official symbol raster from `frontend/public/brand/takt-symbol.svg`.
private struct TaktMark: View {
    var size: CGFloat = 18

    var body: some View {
        Image("TaktSymbol")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size * 0.86, height: size)
            .accessibilityHidden(true)
    }
}

private struct TaktWidgetBackground: ViewModifier {
    @Environment(\.colorScheme) var scheme
    @Environment(\.widgetFamily) var family

    func body(content: Content) -> some View {
        let isAccessory = family == .accessoryInline
            || family == .accessoryCircular
            || family == .accessoryRectangular
        if isAccessory {
            content
        } else {
            let bg = scheme == .dark ? TaktColor.boardDark : TaktColor.board
            content.containerBackground(for: .widget) { bg }
        }
    }
}

// MARK: - Entry view

struct TaktHomeWidgetEntryView: View {
    var entry: TaktEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme
    @Environment(\.widgetRenderingMode) var renderingMode

    private var titleColor: Color { scheme == .dark ? TaktColor.graphiteDark : TaktColor.graphite }
    private var mutedColor: Color { scheme == .dark ? TaktColor.mutedDark : TaktColor.muted }
    private var accentColor: Color { scheme == .dark ? TaktColor.accentDark : TaktColor.accent }
    private var cardColor: Color { scheme == .dark ? TaktColor.surfaceDark : TaktColor.surface }

    var body: some View {
        Group {
            if !entry.loggedIn && entry.openCount == 0 && entry.tasks.isEmpty {
                signedOutView
            } else {
                switch family {
                case .systemSmall:
                    smallView
                case .systemMedium:
                    mediumView
                case .systemLarge:
                    largeView
                case .accessoryInline:
                    accessoryInline
                case .accessoryCircular:
                    accessoryCircular
                case .accessoryRectangular:
                    accessoryRectangular
                default:
                    mediumView
                }
            }
        }
        .modifier(TaktWidgetBackground())
        .widgetURL(openURL())
    }

    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                TaktMark(size: 16)
                Text("Takt")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(titleColor)
            }
            Spacer(minLength: 0)
            Text("Войдите, чтобы видеть задачи")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(mutedColor)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                TaktMark(size: 14)
                Text("Задачи")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
            }
            Text("\(entry.openCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .padding(.top, 2)
            Text(smallUrgentLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.urgentCount > 0 ? TaktColor.urgent : mutedColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.projectName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(mutedColor)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var smallUrgentLabel: String {
        if entry.openCount == 0 { return "Нет активных" }
        if entry.urgentCount == 0 { return "Нет срочных" }
        return "\(entry.urgentCount) срочн\(urgentEnding(entry.urgentCount))"
    }

    // MARK: Medium — vertical list, not big-number + squeezed cards

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                TaktMark(size: 14)
                Text(entry.titleLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(entry.openCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }
            Text(entry.projectName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(mutedColor)
                .lineLimit(1)

            if entry.tasks.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mutedColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(entry.tasks.prefix(3))) { task in
                        taskRow(task, showStatus: false, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
    }

    // MARK: Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                TaktMark(size: 15)
                Text(entry.titleLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(entry.openCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }
            HStack(spacing: 6) {
                Text(entry.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(mutedColor)
                    .lineLimit(1)
                if entry.urgentCount > 0 {
                    Text("·")
                        .foregroundStyle(mutedColor)
                    Text("\(entry.urgentCount) срочн\(urgentEnding(entry.urgentCount))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TaktColor.urgent)
                        .lineLimit(1)
                }
            }

            if entry.tasks.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(mutedColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(entry.tasks.prefix(6))) { task in
                        taskRow(task, showStatus: true, compact: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
    }

    private var emptyLabel: String {
        entry.mode == .mine ? "Нет назначенных задач" : "Нет активных задач"
    }

    // MARK: Lock Screen

    private var accessoryInline: some View {
        let text: String = {
            if entry.urgentCount > 0 {
                return "Takt · \(entry.urgentCount) срочн\(urgentEnding(entry.urgentCount))"
            }
            return "Takt · \(entry.openCount) \(taskWord(entry.openCount))"
        }()
        return Text(text)
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(entry.openCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.titleLabel)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text("\(entry.openCount) \(taskWord(entry.openCount))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1)
            if entry.urgentCount > 0 {
                Text("\(entry.urgentCount) срочн\(urgentEnding(entry.urgentCount))")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            } else {
                Text(entry.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func taskRow(_ task: WidgetTask, showStatus: Bool, compact: Bool) -> some View {
        Link(destination: taskURL(task)) {
            HStack(alignment: .center, spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(priorityColor(task.priority))
                    .frame(width: 3, height: showStatus ? 28 : 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.system(size: compact ? 12 : 12, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    if showStatus, !task.statusName.isEmpty {
                        Text(task.statusName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(mutedColor)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 6)
                Spacer(minLength: 0)
            }
            .padding(.vertical, showStatus ? 5 : 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cardColor)
            )
        }
        .buttonStyle(.plain)
    }

    private func openURL() -> URL {
        if entry.mode == .mine {
            return URL(string: "takt://my-tasks")!
        }
        var components = URLComponents()
        components.scheme = "takt"
        components.host = "board"
        if !entry.projectId.isEmpty {
            components.queryItems = [URLQueryItem(name: "project", value: entry.projectId)]
        }
        return components.url ?? URL(string: "takt://board")!
    }

    private func taskURL(_ task: WidgetTask) -> URL {
        var components = URLComponents()
        components.scheme = "takt"
        components.host = "task"
        var items = [URLQueryItem(name: "id", value: task.id)]
        let pid = task.projectId.isEmpty ? entry.projectId : task.projectId
        if !pid.isEmpty {
            items.append(URLQueryItem(name: "project", value: pid))
        }
        components.queryItems = items
        return components.url ?? URL(string: "takt://my-tasks")!
    }
}

// MARK: - Widget

@main
struct TaktHomeWidget: Widget {
    let kind: String = "TaktHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TaktWidgetConfigIntent.self, provider: Provider()) { entry in
            TaktHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Takt")
        .description("Мои или все задачи выбранного проекта")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}
