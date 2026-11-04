import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/token_storage.dart';
import '../../../shared/models/models.dart';

class AuthRepository {
  AuthRepository({required this.api, required this.tokens});

  final ApiClient api;
  final TokenStorage tokens;

  Future<UserProfile?> restoreSession() async {
    final access = await tokens.readAccess();
    final refresh = await tokens.readRefresh();
    // Keep session if either token exists; interceptor renews via refresh on 401.
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      return null;
    }
    // Retry through deploy / network blips so a short outage doesn't force re-login.
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final res = await api.dio.get<Map<String, dynamic>>('/api/v1/auth/me');
        return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
      } on DioException catch (e) {
        lastError = e;
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          await tokens.clear();
          return null;
        }
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }
      }
    }
    // Tokens still present — surface as error so cubit can retry, not as guest.
    if (lastError != null) throw lastError;
    return null;
  }

  Future<UserProfile> login({required String email, required String password}) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'email': email.trim(), 'password': password},
    );
    await _persistTokens(res.data!);
    return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<void> sendRegisterCode({
    required String name,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    await api.dio.post(
      '/api/v1/auth/register/send-code',
      data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
  }

  Future<UserProfile> confirmRegister({
    required String email,
    required String code,
  }) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register/confirm',
      data: {'email': email.trim(), 'code': code.trim()},
    );
    await _persistTokens(res.data!);
    return UserProfile.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<void> deleteAccount() async {
    await api.dio.delete('/api/v1/users/me');
    await tokens.clear();
  }

  Future<void> logout() async {
    try {
      await api.dio.post('/api/v1/auth/logout');
    } on DioException {
      /* ignore network on logout */
    }
    await tokens.clear();
  }

  Future<void> sendChangePasswordCode({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await api.dio.post(
      '/api/v1/auth/change-password/send-code',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
    );
  }

  Future<void> confirmChangePassword({required String code}) async {
    await api.dio.post(
      '/api/v1/auth/change-password/confirm',
      data: {'code': code.trim()},
    );
    await tokens.clear();
  }

  Future<String?> sendForgotPasswordCode({required String email}) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/forgot-password/send-code',
      data: {'email': email.trim()},
    );
    final message = res.data?['message'];
    return message is String && message.trim().isNotEmpty ? message.trim() : null;
  }

  Future<String?> confirmForgotPassword({
    required String email,
    required String code,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final res = await api.dio.post<Map<String, dynamic>>(
      '/api/v1/auth/forgot-password/confirm',
      data: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
    );
    final message = res.data?['message'];
    return message is String && message.trim().isNotEmpty ? message.trim() : null;
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw StateError('Сервер не вернул токены для мобильного клиента');
    }
    await tokens.saveTokens(access: access, refresh: refresh);
  }
}
