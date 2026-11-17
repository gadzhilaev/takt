import AppIntents
import Foundation
import UIKit

// Shortcuts / Siri: «Пройти чек-ин», «Мои задачи на сегодня», «Сводка по проекту».
// Данные — из App Group (тот же снимок, что у виджетов; без JWT).

private enum SharedSnapshot {
    static let suite = "group.ru.gadzhilaev.takt"

    static func json(_ key: String) -> [String: Any]? {
        guard let raw = UserDefaults(suiteName: suite)?.string(forKey: key),
              let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

@MainActor
private func openInApp(_ link: String) async {
    guard let url = URL(string: link) else { return }
    // The intent runs in the app process after it comes to the foreground.
    try? await Task.sleep(nanoseconds: 300_000_000)
    await UIApplication.shared.open(url)
}

@available(iOS 16.0, *)
struct ShortcutProject: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Проект")
    static var defaultQuery = ShortcutProjectQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

@available(iOS 16.0, *)
struct ShortcutProjectQuery: EntityQuery {
    private func all() -> [ShortcutProject] {
        let list = SharedSnapshot.json("snapshot")?["projects"] as? [[String: Any]] ?? []
        return list.compactMap { p in
            guard let id = p["id"] as? String, let name = p["name"] as? String else { return nil }
            return ShortcutProject(id: id, name: name)
        }
    }

    func entities(for identifiers: [String]) async throws -> [ShortcutProject] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShortcutProject] { all() }
}

@available(iOS 16.0, *)
struct StartCheckinIntent: AppIntent {
    static var title: LocalizedStringResource = "Пройти чек-ин"
    static var description = IntentDescription("Открывает сегодняшний чек-ин по вашим задачам")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let id = SharedSnapshot.json("checkin")?["checkin_id"] as? String
        await openInApp(id.map { "takt://checkin/\($0)" } ?? "takt://checkin")
        return .result()
    }
}

@available(iOS 16.0, *)
struct MyTasksTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Мои задачи на сегодня"
    static var description = IntentDescription("Коротко: что у вас в работе и что в чек-ине")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var lines: [String] = []
        if let checkin = SharedSnapshot.json("checkin"),
           let tasks = checkin["tasks"] as? [[String: Any]] {
            let open = tasks.filter { $0["answer"] == nil || $0["answer"] is NSNull }
            if !open.isEmpty {
                lines.append("В чек-ине \(open.count): " + open.prefix(3).compactMap { $0["title"] as? String }.joined(separator: "; "))
            }
        }
        if let snapshot = SharedSnapshot.json("snapshot"),
           let tasks = snapshot["tasks"] as? [[String: Any]], !tasks.isEmpty {
            let titles = tasks.prefix(5).compactMap { $0["title"] as? String }
            lines.append("Мои задачи: " + titles.joined(separator: "; "))
        }
        let text = lines.isEmpty ? "Открытых задач нет." : lines.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

@available(iOS 16.0, *)
struct ProjectDigestIntent: AppIntent {
    static var title: LocalizedStringResource = "Сводка по проекту"
    static var description = IntentDescription("Открывает вкладку «Сводка» проекта")
    static var openAppWhenRun = true

    @Parameter(title: "Проект") var project: ShortcutProject?

    func perform() async throws -> some IntentResult {
        let id = project?.id
            ?? (SharedSnapshot.json("snapshot")?["project_id"] as? String)
            ?? (SharedSnapshot.json("checkin")?["project_id"] as? String)
        await openInApp(id.map { "takt://digest?project=\($0)" } ?? "takt://digest")
        return .result()
    }
}

@available(iOS 16.0, *)
struct TaktShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCheckinIntent(),
            phrases: ["Пройти чек-ин в \(.applicationName)", "Чек-ин \(.applicationName)"],
            shortTitle: "Пройти чек-ин",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: MyTasksTodayIntent(),
            phrases: ["Мои задачи на сегодня в \(.applicationName)", "Задачи \(.applicationName)"],
            shortTitle: "Мои задачи на сегодня",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: ProjectDigestIntent(),
            phrases: ["Сводка по проекту в \(.applicationName)", "Сводка \(.applicationName)"],
            shortTitle: "Сводка по проекту",
            systemImageName: "chart.bar"
        )
    }
}
