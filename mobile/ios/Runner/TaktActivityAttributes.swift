import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Live Activity «Чек-ин / ближайший срок». Файл входит в оба таргета (Runner и виджет):
/// ActivityKit сопоставляет атрибуты по типу.
@available(iOS 16.1, *)
struct TaktActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "checkin" | "deadline"
        var kind: String
        var title: String
        var subtitle: String
        var answered: Int
        var total: Int
        /// Срок задачи (для kind == "deadline"), иначе nil.
        var deadline: Date?
    }

    var projectName: String
    /// takt:// ссылка, куда ведёт тап по активности.
    var url: String
}
#endif
