import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../firebase_options.dart';
import '../../features/notifications/data/notifications_repository.dart';
import 'checkin_push.dart';

/// Background isolate handler — must be top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background: ${message.messageId}');
  // Android: чек-ин приходит data-сообщением — показываем сами, с кнопками ответа.
  if (Platform.isAndroid && isCheckinPush(message.data)) {
    await CheckinPush.show(message.data);
  }
}

class FcmBootstrap {
  FcmBootstrap(this._notifications);

  final NotificationsRepository _notifications;
  static const _promptNeverKey = 'takt_push_prompt_never';
  /// Legacy key from older builds — treated as «больше не показывать».
  static const _promptSeenLegacyKey = 'takt_push_prompt_seen';

  /// Firebase initialized (no system permission yet).
  bool firebaseReady = false;

  /// Permission requested and token pipeline wired.
  bool ready = false;

  /// User chose «Больше не показывать» (or completed Allow).
  final ValueNotifier<bool> promptNeverListenable = ValueNotifier(false);

  /// Skip only for this app process — next cold start may ask again.
  bool skippedThisSession = false;

  bool get promptNever => promptNeverListenable.value;

  /// Whether router should send user to the soft permission screen.
  bool get shouldShowPrompt => !promptNever && !skippedThisSession;

  /// Back-compat for older call sites / splash.
  bool get promptSeen => promptNever || skippedThisSession;

  final ValueNotifier<bool> promptSeenListenable = ValueNotifier(false);

  String? token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Latest foreground FCM payload for in-app toast UI.
  final ValueNotifier<RemoteMessage?> foregroundMessage = ValueNotifier(null);

  Future<void> loadPromptState() async {
    final prefs = await SharedPreferences.getInstance();
    final never = prefs.getBool(_promptNeverKey) ?? prefs.getBool(_promptSeenLegacyKey) ?? false;
    promptNeverListenable.value = never;
    promptSeenListenable.value = never || skippedThisSession;
  }

  Future<void> markPromptNever() async {
    promptNeverListenable.value = true;
    skippedThisSession = false;
    promptSeenListenable.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptNeverKey, true);
  }

  Future<void> markPromptSkipped() async {
    skippedThisSession = true;
    promptSeenListenable.value = true;
  }

  @Deprecated('Use markPromptNever / markPromptSkipped')
  Future<void> markPromptSeen() => markPromptNever();

  /// Soft Firebase init only. Does **not** ask for notification permission.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      firebaseReady = true;
      await _wireForegroundToast();
    } catch (e) {
      firebaseReady = false;
      debugPrint('FCM unavailable (проверьте GoogleService-Info / google-services): $e');
    }
  }

  Future<void> _wireForegroundToast() async {
    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      foregroundMessage.value = message;
    });
  }

  /// Call after the in-app intro: system permission dialog, then token.
  Future<bool> enablePush() async {
    if (!firebaseReady) {
      await init();
      if (!firebaseReady) return false;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      return await registerForUser();
    } catch (e) {
      ready = false;
      final msg = e.toString();
      if (msg.contains('apns-token-not-set')) {
        debugPrint('FCM: push пока недоступен (нет APNS-токена; на симуляторе это нормально)');
      } else {
        debugPrint('FCM enable failed: $e');
      }
      return false;
    }
  }

  Future<bool> registerForUser() async {
    if (!firebaseReady) await init();
    if (!firebaseReady) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.getNotificationSettings();
      final allowed = permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        ready = false;
        return false;
      }
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // ignore: deprecated_member_use
      token = await messaging.getToken();
      ready = token != null;
      await _refreshSub?.cancel();
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((t) async {
        token = t;
        await _register(t);
      });
      if (token != null) {
        ready = await _register(token!);
        if (ready) await markPromptNever();
        return ready;
      }
      ready = false;
      return false;
    } catch (e) {
      ready = false;
      if (e.toString().contains('apns-token-not-set')) {
        debugPrint('FCM: APNs token is not ready yet; registration will retry on resume');
      } else {
        debugPrint('FCM registration setup failed: $e');
      }
      return false;
    }
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

  Future<bool> _register(String t) async {
    try {
      await _notifications.registerDeviceToken(
        token: t,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      debugPrint('FCM token registered for signed-in user');
      return true;
    } catch (e) {
      debugPrint('FCM register failed: $e');
      return false;
    }
  }

  /// Deep-link path from notification data (`url` or project/task ids).
  static String? routeFromMessage(RemoteMessage message) => routeFromData(message.data);

  /// Same as [routeFromMessage] for a raw data map (also used by local notifications).
  static String? routeFromData(Map<String, dynamic> data) {
    if (data['kind'] == 'digest' && data['project_id'] is String) {
      final period = data['period'] is String ? '&period=${data['period']}' : '';
      return '/digest?project=${data['project_id']}$period';
    }
    if (data['kind'] == 'rhythm_checkin') {
      final id = data['checkin_id'];
      return id is String && id.isNotEmpty ? '/checkin/$id' : '/checkin';
    }
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

  /// Opens the OS settings screen for this app (notifications, etc.).
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  void dispose() {
    _refreshSub?.cancel();
    _foregroundSub?.cancel();
    promptSeenListenable.dispose();
    promptNeverListenable.dispose();
    foregroundMessage.dispose();
  }
}

enum PushPermission {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
}
