import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../core/token_storage.dart';
import '../../../shared/models/models.dart';
import 'oauth_models.dart';

class OAuthRepository {
  OAuthRepository(this._api);

  final ApiClient _api;

  /// HTTPS callback registered in VK/Yandex consoles. Server bounces to [callbackDeepLink].
  static String get mobileRedirectUri =>
      '${AppConfig.apiBase}/api/v1/auth/oauth/callback';

  /// Deep link captured by ASWebAuthenticationSession after the HTTPS bounce.
  static const callbackDeepLink = 'takt://oauth/callback';
  static const callbackUrlScheme = 'takt';

  TokenStorage get _tokens => _api.tokens;

  Map<String, dynamic>? _providersCache;
  Future<Map<String, dynamic>>? _providersInflight;

  /// Уже загруженный ответ `/providers` (или null, если ещё не грели).
  Map<String, dynamic>? get cachedProviders => _providersCache;

  /// Карта `providers` для кнопок — без повторного запроса, если кэш есть.
  Map<String, dynamic>? get cachedProviderMap {
    final raw = _providersCache?['providers'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Прогрев на splash: один inflight на всех потребителей.
  Future<void> prefetchProviders() async {
    try {
      await providers();
    } catch (e) {
      debugPrint('── OAuth providers prefetch ✕ $e');
    }
  }

  Future<Map<String, dynamic>> providers({bool force = false}) async {
    if (!force && _providersCache != null) return _providersCache!;
    return _providersInflight ??= () async {
      try {
        final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/auth/oauth/providers');
        _providersCache = res.data ?? {};
        return _providersCache!;
      } finally {
        _providersInflight = null;
      }
    }();
  }

  /// Полный вход/регистрация через провайдера. Apple — системный sheet;
  /// VK / Яндекс — ASWebAuthenticationSession (HTTPS callback → takt:// bounce).
  Future<UserProfile> signIn(String provider, {bool link = false}) async {
    debugPrint('── OAuth → start provider=$provider link=$link');
    try {
      final user = provider == OAuthProviderId.apple
          ? await _signInApple(link: link)
          : await _signInBrowserProvider(provider, link: link);
      debugPrint('── OAuth ← ok provider=$provider user=${user.email}');
      return user;
    } catch (e, st) {
      debugPrint('── OAuth ✕ provider=$provider error=$e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<UserProfile> _signInApple({bool link = false}) async {
    late final AuthorizationCredentialAppleID credential;
    try {
      debugPrint('── OAuth Apple → native SignInWithApple sheet');
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      debugPrint('── OAuth Apple ← credential (hasToken=${credential.identityToken != null})');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const OAuthException('Вход отменён', cancelled: true);
      }
      throw OAuthException(e.message);
    } on MissingPluginException catch (e) {
      debugPrint('── OAuth Apple ✕ MissingPluginException: $e');
      throw const OAuthException(
        'Плагин Apple не подключён. Полностью остановите приложение и снова запустите flutter run.',
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const OAuthException('Apple не вернул токен');
    }

    final parts = <String>[
      if ((credential.givenName ?? '').trim().isNotEmpty) credential.givenName!.trim(),
      if ((credential.familyName ?? '').trim().isNotEmpty) credential.familyName!.trim(),
    ];
    final displayName = parts.isEmpty ? null : parts.join(' ');

    return _completeMobile(
      provider: OAuthProviderId.apple,
      idToken: idToken,
      displayName: displayName,
      link: link,
    );
  }

  Future<UserProfile> _signInBrowserProvider(String provider, {bool link = false}) async {
    debugPrint('── OAuth $provider → /start (in-app browser, https callback)');
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/auth/oauth/$provider/start',
      queryParameters: {
        'client': 'mobile',
        // Server ignores custom schemes for mobile and uses HTTPS callback.
        'redirect_uri': mobileRedirectUri,
        if (link) 'link': 'true',
      },
    );
    final url = res.data?['authorize_url'] as String?;
    final state = res.data?['state'] as String?;
    if (url == null || url.isEmpty || state == null || state.isEmpty) {
      throw const OAuthException('Сервер вернул некорректный ответ для входа');
    }

    await _preflightAuthorizeHost(url);

    late final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: false),
      );
    } on Exception catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('cancel') || text.contains('cancell')) {
        // Not marked cancelled: blank/DNS Safari sheet looks the same as user close —
        // show a hint instead of silently ignoring.
        throw const OAuthException(
          'Вход не завершён. Если страница провайдера не открылась — проверьте интернет '
          'или попробуйте на телефоне (симулятор часто не открывает oauth.yandex.ru / id.vk.com).',
        );
      }
      throw OAuthException(_api.messageFromError(e));
    }

    final uri = Uri.parse(callback);
    final error = uri.queryParameters['error'] ?? uri.queryParameters['oauth_error'];
    if (error != null && error.isNotEmpty) {
      final msg = uri.queryParameters['message']?.trim();
      throw OAuthException(
        (msg != null && msg.isNotEmpty) ? msg : error,
      );
    }
    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'] ?? state;
    final deviceId = uri.queryParameters['device_id'];
    if (code == null || code.isEmpty) {
      throw const OAuthException('Провайдер не вернул код авторизации');
    }

    return _completeMobile(
      provider: provider,
      code: code,
      state: returnedState,
      deviceId: deviceId,
      link: link,
    );
  }

  /// Early DNS/connectivity check so we don't show a blank Safari sheet.
  Future<void> _preflightAuthorizeHost(String authorizeUrl) async {
    final host = Uri.tryParse(authorizeUrl)?.origin;
    if (host == null || host.isEmpty) return;
    try {
      final probe = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          followRedirects: true,
          validateStatus: (_) => true,
        ),
      );
      await probe.head(host);
    } on DioException catch (e) {
      debugPrint('── OAuth preflight ✕ $host: $e');
      final dns = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          (e.message ?? '').toLowerCase().contains('failed host lookup');
      if (dns) {
        throw OAuthException(
          'Не удаётся открыть $host. Проверьте интернет / DNS. '
          'На iOS Simulator это частая проблема — проверьте вход на телефоне.',
        );
      }
      // Other probe failures (405 etc.) are fine — host is reachable.
    } catch (e) {
      debugPrint('── OAuth preflight ✕ $host: $e');
    }
  }

  Future<UserProfile> _completeMobile({
    required String provider,
    String? code,
    String? idToken,
    String? state,
    String? deviceId,
    String? displayName,
    bool link = false,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/oauth/mobile',
      data: {
        'provider': provider,
        'redirect_uri': mobileRedirectUri,
        'code': ?code,
        'id_token': ?idToken,
        'state': ?state,
        'device_id': ?deviceId,
        'display_name': ?displayName,
        'link': link,
      },
    );
    final data = res.data;
    if (data == null) throw const OAuthException('Пустой ответ сервера');
    if (!link) {
      await _persistTokens(data);
    }
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const OAuthException('Сервер не вернул профиль пользователя');
    }
    return UserProfile.fromJson(userJson);
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw const OAuthException('Сервер не вернул токены');
    }
    await _tokens.saveTokens(access: access, refresh: refresh);
  }

  Future<List<Map<String, dynamic>>> identities() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/auth/oauth/identities');
    final items = res.data?['items'];
    if (items is List) {
      return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> unlink(String identityId) async {
    await _api.dio.delete('/api/v1/auth/oauth/identities/$identityId');
  }
}

bool isOAuthCancel(Object e) {
  if (e is OAuthException && e.cancelled) return true;
  if (e is DioException) {
    final data = e.response?.data;
    String? code;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        final err = detail['error'];
        if (err is Map) code = err['code'] as String?;
      }
      final err = data['error'];
      if (err is Map) code = err['code'] as String?;
    }
    return code == 'access_denied' || e.type == DioExceptionType.cancel;
  }
  if (kDebugMode && e.toString().toLowerCase().contains('cancel')) return true;
  return false;
}
