import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/token_storage.dart';
import 'main.dart' as app;

/// One-shot entry for store screenshots (password only via --dart-define).
///
/// ```bash
/// flutter run -d <sim> -t lib/main_store_shots.dart \
///   --dart-define=SKIP_PUSH_INTRO=true \
///   --dart-define=STORE_EMAIL=store.review@taktapp.ru \
///   --dart-define=STORE_PASSWORD='…' \
///   --dart-define=STORE_PROJECT_ID=<uuid> \
///   --dart-define=STORE_ROUTE=/board?project=<uuid>
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('STORE_EMAIL');
  const password = String.fromEnvironment('STORE_PASSWORD');
  const projectId = String.fromEnvironment('STORE_PROJECT_ID');
  const route = String.fromEnvironment('STORE_ROUTE', defaultValue: '/projects');

  if (email.isEmpty || password.isEmpty) {
    throw StateError(
      'Pass --dart-define=STORE_EMAIL=… and --dart-define=STORE_PASSWORD=… '
      '(see private store-review credentials).',
    );
  }

  final dio = Dio(
    BaseOptions(
      // API_BASE (dart-define) — локальный стенд; по умолчанию prod.
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final res = await dio.post<Map<String, dynamic>>(
    '/api/v1/auth/login',
    data: {'email': email, 'password': password},
  );
  final data = res.data!;
  await TokenStorage().saveTokens(
    access: data['access_token'] as String,
    refresh: data['refresh_token'] as String,
  );

  final prefs = await SharedPreferences.getInstance();
  if (projectId.isNotEmpty) {
    await prefs.setString('takt_last_project_id', projectId);
  }
  // Store shots: включить Live Activity до runApp (профиль по умолчанию выкл.).
  if (const bool.fromEnvironment('STORE_LIVE_ACTIVITY')) {
    await prefs.setBool('takt_live_activity_enabled', true);
  }
  if (route.isNotEmpty) {
    TaktApp.pendingDeepLink = route;
  }

  await app.main();
}
