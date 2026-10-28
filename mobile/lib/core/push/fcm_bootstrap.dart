import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';
import '../../features/notifications/data/notifications_repository.dart';

/// Background isolate handler — must be top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background: ${message.messageId} ${message.data}');
}

class FcmBootstrap {
  FcmBootstrap(this._notifications);

  final NotificationsRepository _notifications;
  bool ready = false;
  String? token;
  StreamSubscription<String>? _refreshSub;

  /// Soft-init: app runs without google-services; push activates when configured.
  ///
  /// Uses classic FCM registration tokens (`getToken`) so backend
  /// `firebase_admin.messaging.Message(token=…)` keeps working.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // ignore: deprecated_member_use
      token = await messaging.getToken();
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((t) async {
        token = t;
        await _register(t);
      });
      ready = true;
      debugPrint('FCM ready, token=${token != null}');
    } catch (e, st) {
      ready = false;
      debugPrint(
        'FCM unavailable (add google-services / GoogleService-Info): $e\n$st',
      );
    }
  }

  Future<void> registerForUser() async {
    if (!ready) return;
    // ignore: deprecated_member_use
    final t = token ?? await FirebaseMessaging.instance.getToken();
    if (t == null) return;
    token = t;
    await _register(t);
  }

  Future<void> unregister() async {
    if (!ready || token == null) return;
    try {
      await _notifications.unregisterDeviceToken(
        token: token!,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _register(String t) async {
    try {
      await _notifications.registerDeviceToken(
        token: t,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }

  /// Deep-link path from notification data (`url` or project/task ids).
  static String? routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final url = data['url'] ?? data['path'];
    if (url is String && url.isNotEmpty) {
      return url.startsWith('/') ? url : '/$url';
    }
    final projectId = data['project_id'] ?? data['projectId'];
    final taskId = data['task_id'] ?? data['taskId'];
    if (projectId is String && projectId.isNotEmpty) {
      final q = StringBuffer('/board?project=$projectId');
      if (taskId is String && taskId.isNotEmpty) q.write('&task=$taskId');
      return q.toString();
    }
    return null;
  }

  void dispose() {
    _refreshSub?.cancel();
  }
}
