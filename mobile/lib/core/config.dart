class AppConfig {
  AppConfig._();

  /// Override with `--dart-define=API_BASE=https://…` for staging/prod.
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const appGroupId = 'group.ru.takt.mobile';
  static const widgetNameAndroid = 'TaktWidgetProvider';
  static const widgetNameIos = 'TaktHomeWidget';
}
