import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/push/checkin_push.dart';
import 'core/push/fcm_bootstrap.dart';
import 'core/token_storage.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/widget_sync/widget_sync.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep native splash (same brand as Dart SplashPage) until first Flutter frame.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Только портрет на телефонах (iOS и Android); Info.plist — тот же набор.
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  await HomeWidget.setAppGroupId(AppConfig.appGroupId);
  // Адрес API для ответа на чек-ин из уведомления на iOS (AppDelegate.swift читает App Group).
  await HomeWidget.saveWidgetData<String>('takt_api_base', AppConfig.apiBase);
  await CheckinPush.init(
    onOpen: (route) {
      TaktApp.pendingDeepLink = route;
      TaktApp.onWidgetDeepLink?.call();
    },
  );

  final tokens = TokenStorage();
  final api = ApiClient(tokens: tokens);
  final notifications = NotificationsRepository(api);
  final fcm = FcmBootstrap(notifications);
  await fcm.loadPromptState();
  // Local QA / CI: --dart-define=SKIP_PUSH_INTRO=true skips the first-run push screen.
  if (const bool.fromEnvironment('SKIP_PUSH_INTRO')) {
    await fcm.markPromptSeen();
  }
  final onboarding = OnboardingController();
  await onboarding.load();
  // Local QA / CI / golden: skip product onboarding.
  if (const bool.fromEnvironment('SKIP_ONBOARDING')) {
    await onboarding.markSeen();
  }
  await fcm.init();

  if (fcm.firebaseReady) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = FcmBootstrap.routeFromMessage(message);
      debugPrint('FCM opened: $route');
      TaktApp.pendingDeepLink = route;
      // Приложение уже запущено — переходим сразу (чек-ин, задача).
      TaktApp.onWidgetDeepLink?.call();
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      TaktApp.pendingDeepLink = FcmBootstrap.routeFromMessage(initial);
    }
  }

  final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  if (widgetUri != null) {
    TaktApp.pendingDeepLink ??= WidgetSync.routeFromAny(widgetUri);
  }

  HomeWidget.widgetClicked.listen((uri) {
    if (uri == null) return;
    TaktApp.pendingDeepLink = WidgetSync.routeFromAny(uri);
    TaktApp.onWidgetDeepLink?.call();
  });

  runApp(TaktApp(tokens: tokens, api: api, fcm: fcm, onboarding: onboarding));
}
