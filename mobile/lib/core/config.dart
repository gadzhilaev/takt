import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Override with `--dart-define=API_BASE=http://127.0.0.1:8000` for local backend.
  /// Release default: production domain.
  static String get apiBase {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kReleaseMode) return 'https://taktapp.ru';
    // Debug/profile without override still hits prod so device testing works
    // without dart-define; local backend: pass API_BASE explicitly.
    return 'https://taktapp.ru';
  }

  static const appGroupId = 'group.ru.gadzhilaev.takt';
  static const widgetNameAndroid = 'TaktWidgetProvider';
  static const widgetNameIos = 'TaktHomeWidget';
}
