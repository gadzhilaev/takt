import 'config.dart';

/// Product contact / legal links.
abstract final class TaktLinks {
  static const supportEmail = 'support@taktapp.ru';
  static const supportMailto = 'mailto:support@taktapp.ru?subject=Takt%20поддержка';

  static String get webOrigin {
    final api = AppConfig.apiBase;
    return api.replaceFirst(RegExp(r'/api(?:/v1)?/?$'), '');
  }

  static String get privacyUrl => '$webOrigin/privacy';
}
