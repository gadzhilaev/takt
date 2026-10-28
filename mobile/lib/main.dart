import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/push/fcm_bootstrap.dart';
import 'core/token_storage.dart';
import 'features/notifications/data/notifications_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId(AppConfig.appGroupId);

  final tokens = TokenStorage();
  final api = ApiClient(tokens: tokens);
  final notifications = NotificationsRepository(api);
  final fcm = FcmBootstrap(notifications);
  await fcm.init();

  if (fcm.ready) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = FcmBootstrap.routeFromMessage(message);
      debugPrint('FCM opened: $route');
      TaktApp.pendingDeepLink = route;
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      TaktApp.pendingDeepLink = FcmBootstrap.routeFromMessage(initial);
    }
  }

  final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  if (widgetUri != null) {
    TaktApp.pendingDeepLink ??= '/board';
  }

  runApp(TaktApp(tokens: tokens, api: api, fcm: fcm));
}
