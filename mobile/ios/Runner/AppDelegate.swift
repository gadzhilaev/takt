import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // AppDelegate — делегат центра уведомлений: свои кнопки чек-ина обрабатываем здесь,
    // остальное (тапы по push) уходит плагинам через super (firebase_messaging).
    UNUserNotificationCenter.current().delegate = self
    CheckinNotifications.registerCategories()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if CheckinNotifications.handle(response, completion: completionHandler) {
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}

/// Кнопки уведомления чек-ина: ответ уходит на сервер без открытия приложения.
/// Авторизация — одноразовый токен из push (`action_token`), JWT здесь не нужен.
enum CheckinNotifications {
  static let categoryOne = "TAKT_CHECKIN_ONE"
  static let categoryMany = "TAKT_CHECKIN_MANY"
  static let done = "TAKT_DONE"
  static let inProgress = "TAKT_IN_PROGRESS"
  static let blocked = "TAKT_BLOCKED"
  static let open = "TAKT_OPEN"
  static let appGroup = "group.ru.gadzhilaev.takt"

  static func registerCategories() {
    let doneAction = UNNotificationAction(
      identifier: done, title: "Сделал", options: [.authenticationRequired])
    let progressAction = UNNotificationAction(
      identifier: inProgress, title: "В работе", options: [.authenticationRequired])
    let blockedAction = UNTextInputNotificationAction(
      identifier: blocked,
      title: "Застрял",
      options: [.authenticationRequired],
      textInputButtonTitle: "Отправить",
      textInputPlaceholder: "Что мешает?")
    let openAction = UNNotificationAction(
      identifier: open, title: "Открыть чек-ин", options: [.foreground])
    UNUserNotificationCenter.current().setNotificationCategories([
      UNNotificationCategory(
        identifier: categoryOne,
        actions: [doneAction, progressAction, blockedAction],
        intentIdentifiers: [],
        options: []),
      UNNotificationCategory(
        identifier: categoryMany,
        actions: [openAction],
        intentIdentifiers: [],
        options: []),
    ])
  }

  static func answer(for action: String) -> String? {
    switch action {
    case done: return "done"
    case inProgress: return "in_progress"
    case blocked: return "blocked"
    default: return nil
    }
  }

  /// true — ответ обработан здесь (completion вызывается ровно один раз).
  static func handle(_ response: UNNotificationResponse, completion: @escaping () -> Void) -> Bool {
    guard let answer = answer(for: response.actionIdentifier) else { return false }
    let info = response.notification.request.content.userInfo
    guard
      let checkinId = info["checkin_id"] as? String,
      let taskId = info["task_id"] as? String,
      let token = info["action_token"] as? String
    else { return false }

    var body: [String: Any] = [
      "checkin_id": checkinId,
      "task_id": taskId,
      "answer": answer,
      "token": token,
    ]
    if answer == "blocked",
      let text = (response as? UNTextInputNotificationResponse)?.userText
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    {
      body["reason"] = String(text.prefix(280))
    }

    let base = UserDefaults(suiteName: appGroup)?.string(forKey: "takt_api_base") ?? "https://taktapp.ru"
    let path = (info["action_path"] as? String) ?? "/api/v1/rhythm/push-answer"
    guard let url = URL(string: path, relativeTo: URL(string: base)),
      let data = try? JSONSerialization.data(withJSONObject: body)
    else {
      notifyFailure(info: info, completion: completion)
      return true
    }

    var request = URLRequest(url: url, timeoutInterval: 20)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = data

    let bg = UIApplication.shared.beginBackgroundTask(withName: "takt.checkin.answer")
    URLSession.shared.dataTask(with: request) { _, resp, error in
      let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
      let ok = error == nil && (200..<300).contains(code)
      let finish = {
        if bg != .invalid { UIApplication.shared.endBackgroundTask(bg) }
        completion()
      }
      if ok {
        DispatchQueue.main.async(execute: finish)
      } else {
        notifyFailure(info: info, completion: finish)
      }
    }.resume()
    return true
  }

  /// Не молчим: просим ответить в приложении (тап откроет приложение с баннером чек-ина).
  private static func notifyFailure(info: [AnyHashable: Any], completion: @escaping () -> Void) {
    let content = UNMutableNotificationContent()
    content.title = "Ответ не отправлен"
    content.body = "Откройте чек-ин в Takt и ответьте там"
    content.sound = nil
    let request = UNNotificationRequest(
      identifier: "takt-checkin-failed-\(info["checkin_id"] as? String ?? "x")",
      content: content,
      trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in
      DispatchQueue.main.async(execute: completion)
    }
  }
}
