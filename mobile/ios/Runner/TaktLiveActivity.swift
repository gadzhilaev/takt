import Flutter
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Канал `takt/live_activity`: Flutter включает/обновляет/завершает Live Activity.
/// Активность включает сам пользователь (тумблер в профиле), без навязывания.
enum TaktLiveActivity {
    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "takt/live_activity", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isSupported":
                result(isSupported())
            case "show":
                let args = call.arguments as? [String: Any] ?? [:]
                Task { result(await show(args)) }
            case "end":
                Task {
                    await endAll()
                    result(true)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    static func isSupported() -> Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    /// Start or update the single Takt activity.
    static func show(_ args: [String: Any]) async -> Bool {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
            return false
        }
        var deadline: Date?
        if let ms = args["deadline_ms"] as? Int, ms > 0 {
            deadline = Date(timeIntervalSince1970: Double(ms) / 1000)
        }
        let state = TaktActivityAttributes.ContentState(
            kind: args["kind"] as? String ?? "checkin",
            title: args["title"] as? String ?? "Чек-ин",
            subtitle: args["subtitle"] as? String ?? "",
            answered: args["answered"] as? Int ?? 0,
            total: args["total"] as? Int ?? 0,
            deadline: deadline
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(12 * 3600))
        if let current = Activity<TaktActivityAttributes>.activities.first {
            await current.update(content)
            return true
        }
        let attributes = TaktActivityAttributes(
            projectName: args["project_name"] as? String ?? "",
            url: args["url"] as? String ?? "takt://checkin"
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    static func endAll() async {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            for activity in Activity<TaktActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
