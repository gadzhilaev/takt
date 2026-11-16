import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config.dart';
import '../pending_deep_link.dart';

/// Действия уведомления чек-ина. Идентификаторы совпадают с iOS (AppDelegate.swift).
abstract final class CheckinActions {
  static const done = 'TAKT_DONE';
  static const inProgress = 'TAKT_IN_PROGRESS';
  static const blocked = 'TAKT_BLOCKED';
  static const open = 'TAKT_OPEN';

  static String? answerFor(String actionId) => switch (actionId) {
        done => 'done',
        inProgress => 'in_progress',
        blocked => 'blocked',
        _ => null,
      };
}

bool isCheckinPush(Map<String, dynamic> data) => data['kind'] == 'rhythm_checkin';

/// Тело `POST /api/v1/rhythm/push-answer` из данных push и выбранного действия.
/// null — действие не отвечает на задачу (например «Открыть чек-ин») или данных не хватает.
Map<String, dynamic>? pushAnswerBody(
  Map<String, dynamic> data,
  String actionId, {
  String? input,
}) {
  final answer = CheckinActions.answerFor(actionId);
  final checkinId = data['checkin_id'];
  final taskId = data['task_id'];
  final token = data['action_token'];
  if (answer == null || checkinId is! String || taskId is! String || token is! String) {
    return null;
  }
  final reason = (input ?? '').trim();
  return {
    'checkin_id': checkinId,
    'task_id': taskId,
    'answer': answer,
    'token': token,
    if (answer == 'blocked' && reason.isNotEmpty)
      'reason': reason.length > 280 ? reason.substring(0, 280) : reason,
  };
}

/// Android: data-сообщение чек-ина показываем сами — с кнопками ответа.
/// iOS: кнопки рисует система по категории APNs, ответ шлёт AppDelegate.swift.
class CheckinPush {
  CheckinPush._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _channel = AndroidNotificationDetails(
    'takt_checkin',
    'Чек-ин',
    channelDescription: 'Ежедневный вопрос по вашим задачам',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// [onOpen] — переход в приложение (тап по уведомлению или «Открыть чек-ин»).
  static Future<void> init({void Function(String route)? onOpen}) async {
    if (!_android || _ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => _onResponse(r, onOpen),
      onDidReceiveBackgroundNotificationResponse: checkinNotificationBackgroundResponse,
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final resp = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && resp != null) {
      final route = _routeFor(resp.payload);
      if (route != null) PendingDeepLink.value ??= route;
    }
  }

  static Future<void> show(Map<String, dynamic> data) async {
    if (!_android) return;
    if (!_ready) await init();
    final single = data['task_count'] == '1' && data['task_id'] is String;
    final actions = single
        ? const [
            AndroidNotificationAction(CheckinActions.done, 'Сделал'),
            AndroidNotificationAction(CheckinActions.inProgress, 'В работе'),
            AndroidNotificationAction(
              CheckinActions.blocked,
              'Застрял',
              inputs: [AndroidNotificationActionInput(label: 'Что мешает?')],
              allowGeneratedReplies: false,
            ),
          ]
        : const [
            AndroidNotificationAction(
              CheckinActions.open,
              'Открыть чек-ин',
              showsUserInterface: true,
            ),
          ];
    await _plugin.show(
      id: (data['checkin_id'] as String? ?? '').hashCode & 0x7fffffff,
      title: data['title'] as String? ?? 'Чек-ин на сегодня',
      body: data['body'] as String?,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          importance: _channel.importance,
          priority: _channel.priority,
          category: _channel.category,
          actions: actions,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> _onResponse(
    NotificationResponse r,
    void Function(String route)? onOpen,
  ) async {
    final handled = await handleAction(r);
    if (handled) return;
    final route = _routeFor(r.payload);
    if (route != null) onOpen?.call(route);
  }

  static String? _routeFor(String? payload) {
    final data = _decode(payload);
    if (data == null || !isCheckinPush(data)) return null;
    final id = data['checkin_id'];
    return id is String && id.isNotEmpty ? '/checkin/$id' : '/checkin';
  }

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final v = jsonDecode(payload);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Ответ прямо из уведомления. true — действие было ответом (успешно или нет).
  static Future<bool> handleAction(NotificationResponse r) async {
    final data = _decode(r.payload);
    final actionId = r.actionId;
    if (data == null || actionId == null) return false;
    final body = pushAnswerBody(data, actionId, input: r.input);
    if (body == null) return false;
    final ok = await postPushAnswer(body, path: data['action_path'] as String?);
    if (!ok) {
      // Не молчим: просим открыть чек-ин в приложении.
      await _plugin.show(
        id: (data['checkin_id'] as String? ?? '').hashCode & 0x7fffffff,
        title: 'Ответ не отправлен',
        body: 'Откройте чек-ин в Takt и ответьте там',
        notificationDetails: const NotificationDetails(android: _channel),
        payload: r.payload,
      );
    }
    return true;
  }
}

/// Отправка ответа без сессии приложения: авторизация — одноразовым токеном из push.
Future<bool> postPushAnswer(Map<String, dynamic> body, {String? path}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse(AppConfig.apiBase).resolve(path ?? '/api/v1/rhythm/push-answer');
    final req = await client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 20));
    await res.drain<void>();
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (e) {
    debugPrint('checkin push answer failed: $e');
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Нажатие кнопки, когда приложение в фоне или закрыто (отдельный isolate).
@pragma('vm:entry-point')
Future<void> checkinNotificationBackgroundResponse(NotificationResponse r) async {
  await CheckinPush.handleAction(r);
}
