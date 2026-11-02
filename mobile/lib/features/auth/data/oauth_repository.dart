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

  /// HTTPS callback registered in VK/Yandex consoles. Server bounces to [callbackDeepLink]
  /// when the session does not capture the HTTPS redirect itself.
  static String get mobileRedirectUri =>
      '${AppConfig.apiBase}/api/v1/auth/oauth/callback';

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
  /// VK / Яндекс — ASWebAuthenticationSession (launch → provider → HTTPS callback).
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
        throw const OAuthException('', cancelled: true);
      }
      // Системный текст Apple / иначе через API-слой при complete.
      throw OAuthException(_api.messageFromError(e));
    } on MissingPluginException catch (e) {
      throw OAuthException(_api.messageFromError(e));
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const OAuthException('', cancelled: true);
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
    debugPrint('── OAuth $provider → /start');
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/auth/oauth/$provider/start',
      queryParameters: {
        'client': 'mobile',
        'redirect_uri': mobileRedirectUri,
        if (link) 'link': 'true',
      },
    );
    final authorizeUrl = res.data?['authorize_url'] as String?;
    final state = res.data?['state'] as String?;
    if (authorizeUrl == null || authorizeUrl.isEmpty || state == null || state.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        message: 'invalid_oauth_start',
      );
    }

    // Сначала taktapp.ru (резолвится), потом 302 на VK/Яндекс.
    // Callback scheme только `takt` (Info.plist): https-scheme без Associated Domains
    // на iOS сразу даёт cancel и sheet даже не открывается.
    final launchUri = Uri.parse('${AppConfig.apiBase}/api/v1/auth/oauth/launch').replace(
      queryParameters: {'url': authorizeUrl},
    );

    debugPrint('── OAuth $provider → launch via taktapp.ru → $callbackUrlScheme');
    late final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: launchUri.toString(),
        callbackUrlScheme: callbackUrlScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: false),
      );
    } on Exception catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('cancel') || text.contains('cancell')) {
        throw const OAuthException('', cancelled: true);
      }
      throw OAuthException(_api.messageFromError(e));
    }

    final uri = Uri.parse(callback);
    final error = uri.queryParameters['error'] ?? uri.queryParameters['oauth_error'];
    if (error != null && error.isNotEmpty) {
      // Текст с сервера (bounce / callback query `message`).
      final msg = uri.queryParameters['message']?.trim();
      throw OAuthException(
        (msg != null && msg.isNotEmpty) ? msg : error,
      );
    }
    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'] ?? state;
    final deviceId = uri.queryParameters['device_id'];
    if (code == null || code.isEmpty) {
      throw const OAuthException('', cancelled: true);
    }

    return _completeMobile(
      provider: provider,
      code: code,
      state: returnedState,
      deviceId: deviceId,
      link: link,
    );
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
    if (data == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
      );
    }
    if (!link) {
      await _persistTokens(data);
    }
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
      );
    }
    return UserProfile.fromJson(userJson);
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/oauth/mobile'),
        type: DioExceptionType.badResponse,
      );
    }
    await _tokens.saveTokens(access: access, refresh: refresh);
  }

  Future<({List<Map<String, dynamic>> items, bool hasPassword})> identitiesDetailed() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/auth/oauth/identities');
    final items = res.data?['items'];
    final list = items is List ? items.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    final hasPassword = res.data?['has_password'] as bool? ?? false;
    return (items: list, hasPassword: hasPassword);
  }

  Future<List<Map<String, dynamic>>> identities() async {
    final detailed = await identitiesDetailed();
    return detailed.items;
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
