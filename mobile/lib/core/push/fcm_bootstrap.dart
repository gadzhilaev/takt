import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _promptSeenKey = 'takt_push_prompt_seen';

  /// Firebase initialized (no system permission yet).
  bool firebaseReady = false;

  /// Permission requested and token pipeline wired.
  bool ready = false;

  /// Drives go_router refresh when the intro is completed.
  final ValueNotifier<bool> promptSeenListenable = ValueNotifier(false);

  bool get promptSeen => promptSeenListenable.value;

  String? token;
  StreamSubscription<String>? _refreshSub;

  Future<void> loadPromptState() async {
    final prefs = await SharedPreferences.getInstance();
    promptSeenListenable.value = prefs.getBool(_promptSeenKey) ?? false;
  }

  Future<void> markPromptSeen() async {
    if (promptSeenListenable.value) return;
    promptSeenListenable.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptSeenKey, true);
  }

  /// Soft Firebase init only. Does **not** ask for notification permission.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      firebaseReady = true;
    } catch (e) {
      firebaseReady = false;
      debugPrint('FCM unavailable (проверьте GoogleService-Info / google-services): $e');
    }
  }

  /// Call after the in-app intro: system permission dialog, then token.
  Future<void> enablePush() async {
    if (!firebaseReady) {
      await init();
      if (!firebaseReady) {
        await markPromptSeen();
        return;
      }
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // ignore: deprecated_member_use
      token = await messaging.getToken();
      await _refreshSub?.cancel();
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((t) async {
        token = t;
        await _register(t);
      });
      ready = true;
      debugPrint('FCM ready, token=${token != null}');
      if (token != null) await _register(token!);
    } catch (e) {
      ready = false;
      final msg = e.toString();
      if (msg.contains('apns-token-not-set')) {
        debugPrint('FCM: push пока недоступен (нет APNS-токена; на симуляторе это нормально)');
      } else {
        debugPrint('FCM enable failed: $e');
      }
    } finally {
      await markPromptSeen();
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

  /// Current OS permission without prompting.
  Future<PushPermission> currentPermission() async {
    if (!firebaseReady) return PushPermission.unavailable;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          return PushPermission.authorized;
        case AuthorizationStatus.provisional:
          return PushPermission.provisional;
        case AuthorizationStatus.denied:
        case AuthorizationStatus.deniedPermanently:
          return PushPermission.denied;
        case AuthorizationStatus.notDetermined:
          return PushPermission.notDetermined;
      }
    } catch (_) {
      return PushPermission.unavailable;
    }
  }

  /// When permission is already denied, the OS will not show the prompt again.
  /// Profile UI tells the user to enable notifications in system Settings.
  /// (Opening Settings requires a dedicated plugin; we avoid re-prompting here.)
  Future<void> openSystemSettings() async {
    debugPrint(
      'Push denied: enable notifications in system Settings → Takt',
    );
  }

  void dispose() {
    _refreshSub?.cancel();
    promptSeenListenable.dispose();
  }
}

enum PushPermission {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
}
