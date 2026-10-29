import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({required this.tokens, String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBase,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await tokens.readAccess();
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final req = error.requestOptions;
              final access = await tokens.readAccess();
              req.headers['Authorization'] = 'Bearer $access';
              try {
                final clone = await dio.fetch(req);
                return handler.resolve(clone);
              } catch (_) {
                /* fall through */
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage tokens;
  final Dio dio;
  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = await tokens.readRefresh();
      if (refresh == null || refresh.isEmpty) return false;
      final res = await Dio(
        BaseOptions(baseUrl: dio.options.baseUrl),
      ).post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data;
      if (data == null) return false;
      final access = data['access_token'] as String?;
      final nextRefresh = data['refresh_token'] as String?;
      if (access == null || nextRefresh == null) return false;
      await tokens.saveTokens(access: access, refresh: nextRefresh);
      return true;
    } catch (_) {
      await tokens.clear();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  static const _codeRu = <String, String>{
    'missing_params': 'Не удалось завершить вход. Попробуйте ещё раз.',
    'invalid_state': 'Сессия входа устарела. Начните вход заново.',
    'state_expired': 'Сессия входа истекла. Начните вход заново.',
    'state_reuse': 'Этот вход уже был использован. Начните заново.',
    'provider_disabled': 'Этот способ входа сейчас недоступен.',
    'method_disabled': 'Этот способ входа отключён.',
    'access_denied': 'Вход отменён.',
    'email_owned': 'Email уже занят. Войдите и привяжите провайдера в профиле.',
    'email_taken': 'Email уже зарегистрирован',
    'invalid_credentials': 'Неверный email или пароль',
    'inactive': 'Учётная запись отключена',
    'blocked': 'Учётная запись временно ограничена',
    'locked': 'Слишком много попыток. Попробуйте позже.',
  };

  String _ru(String? message, [String? code]) {
    final msg = (message ?? '').trim();
    if (msg.isNotEmpty && !RegExp(r'^[a-z][a-z0-9_]+$', caseSensitive: false).hasMatch(msg)) {
      return msg;
    }
    final key = (code ?? msg).trim();
    return _codeRu[key] ?? (msg.isNotEmpty ? msg : 'Не удалось выполнить запрос');
  }

  String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final err = detail['error'];
          if (err is Map) {
            return _ru(err['message'] as String?, err['code'] as String?);
          }
          if (detail['message'] is String) return _ru(detail['message'] as String);
        }
        if (detail is String && detail.trim().isNotEmpty) return _ru(detail);
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) return first['msg'] as String;
        }
        final top = data['error'];
        if (top is String && top.trim().isNotEmpty) {
          if (top.toLowerCase().contains('rate limit')) {
            return 'Слишком много попыток. Попробуйте через минуту';
          }
          return _ru(top);
        }
        if (top is Map && top['message'] is String) {
          return _ru(top['message'] as String, top['code'] as String?);
        }
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Нет соединения с сервером';
      }
      return 'Ошибка запроса (${error.response?.statusCode ?? 'сеть'})';
    }
    return error.toString();
  }
}
