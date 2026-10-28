import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';
import '../../../shared/models/models.dart';

class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStorage tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<UserProfile?> restoreSession() async {
    final access = await _tokens.readAccess();
    if (access == null || access.isEmpty) return null;
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
    } catch (_) {
      await _tokens.clear();
      return null;
    }
  }

  Future<UserProfile> login({required String email, required String password}) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    await _persistTokens(res.data!);
    return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
    await _persistTokens(res.data!);
    return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/api/v1/auth/logout');
    } on DioException {
      /* ignore network on logout */
    }
    await _tokens.clear();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await _api.dio.post(
      '/api/v1/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
    );
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw StateError('Сервер не вернул токены для мобильного клиента');
    }
    await _tokens.saveTokens(access: access, refresh: refresh);
  }
}
