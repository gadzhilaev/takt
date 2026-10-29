import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';

class OAuthRepository {
  OAuthRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> providers() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/auth/oauth/providers');
    return res.data ?? {};
  }

  /// Opens system browser / ASWebAuthenticationSession via URL.
  /// Real Apple native Sign in with Apple requires platform setup + id_token to /mobile.
  Future<void> startWebOAuth(String provider, {bool link = false}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/auth/oauth/$provider/start',
      queryParameters: {
        'client': 'mobile',
        if (link) 'link': 'true',
      },
    );
    final url = res.data?['authorize_url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Нет authorize_url');
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw StateError('Не удалось открыть страницу входа');
  }

  Future<Map<String, dynamic>> completeMobile({
    required String provider,
    String? code,
    String? idToken,
    required String redirectUri,
    String? codeVerifier,
    String? deviceId,
    bool link = false,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/oauth/mobile',
      data: {
        'provider': provider,
        'code': ?code,
        'id_token': ?idToken,
        'redirect_uri': redirectUri,
        'code_verifier': ?codeVerifier,
        'device_id': ?deviceId,
        'link': link,
      },
    );
    return res.data ?? {};
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
  if (e is DioException) {
    final data = e.response?.data;
    String? code;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) code = err['code'] as String?;
    }
    return code == 'access_denied' || e.type == DioExceptionType.cancel;
  }
  return false;
}
