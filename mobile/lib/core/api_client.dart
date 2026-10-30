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

  /// Текст ошибки только с сервера (`detail.error.message`). Без локальных словарей.
  String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final err = detail['error'];
          if (err is Map) {
            final message = err['message'];
            if (message is String && message.trim().isNotEmpty) return message.trim();
          }
          final nested = detail['message'];
          if (nested is String && nested.trim().isNotEmpty) return nested.trim();
        }
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) {
            final msg = first['msg'];
            if (msg is String && msg.trim().isNotEmpty) return msg.trim();
          }
        }
        final top = data['error'];
        if (top is Map) {
          final message = top['message'];
          if (message is String && message.trim().isNotEmpty) return message.trim();
        }
        if (top is String && top.trim().isNotEmpty) return top.trim();
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Нет соединения с сервером';
      }
      final code = error.response?.statusCode;
      return code != null ? 'Ошибка $code' : 'Ошибка сети';
    }
    return error.toString();
  }
}
