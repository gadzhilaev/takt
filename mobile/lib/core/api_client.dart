import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({required this.tokens, String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBase,
            // Симулятор/Wi‑Fi иногда долго устанавливает TLS до prod.
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          ),
        ) {
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint('── HTTP → ${options.method} ${options.uri}');
            final q = options.queryParameters;
            if (q.isNotEmpty) debugPrint('   query: $q');
            final data = options.data;
            if (data != null) debugPrint('   body: ${_preview(data)}');
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
              '── HTTP ← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
            );
            debugPrint('   body: ${_preview(response.data)}');
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '── HTTP ✕ ${error.response?.statusCode ?? '-'} ${error.requestOptions.method} ${error.requestOptions.uri}',
            );
            if (error.response?.data != null) {
              debugPrint('   body: ${_preview(error.response!.data)}');
            } else {
              debugPrint('   error: ${error.message}');
            }
            handler.next(error);
          },
        ),
      );
    }
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

  static String _preview(Object? data) {
    try {
      if (data == null) return 'null';
      if (data is FormData) return '<FormData fields=${data.fields.length} files=${data.files.length}>';
      final raw = data is String ? data : jsonEncode(data);
      const max = 2000;
      if (raw.length <= max) return raw;
      return '${raw.substring(0, max)}…(+${raw.length - max})';
    } catch (_) {
      return data.toString();
    }
  }

  final TokenStorage tokens;
  final Dio dio;
  Future<bool>? _refreshInFlight;

  Future<bool> _tryRefresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<bool> _doRefresh() async {
    try {
      final refresh = await tokens.readRefresh();
      if (refresh == null || refresh.isEmpty) return false;
      final res = await Dio(
        BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 30),
        ),
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
    } on DioException catch (e) {
      // Only drop the session when the server rejects the refresh token.
      // Network blips during deploy must not wipe a valid login.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await tokens.clear();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _localize(String raw) {
    final msg = raw.trim();
    if (msg.isEmpty) return msg;
    final lower = msg.toLowerCase();
    if (lower.contains('invalid email') || lower.contains('not a valid email')) {
      return 'Введите корректный email';
    }
    if (lower.contains('at least 8') || lower.contains('string should have at least')) {
      return 'Пароль не короче 8 символов';
    }
    if (lower.contains('field required') || lower == 'required') {
      return 'Заполните обязательные поля';
    }
    if (RegExp(r'^[a-z][a-z0-9_]+$', caseSensitive: false).hasMatch(msg)) {
      return 'Ошибка запроса';
    }
    return msg;
  }

  /// Текст ошибки с сервера; английские validation-фразы переводим.
  String messageFromError(Object error) {
    if (error is MissingPluginException) {
      return 'Плагин не подключён. Полностью перезапустите приложение (stop + flutter run).';
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          final err = detail['error'];
          if (err is Map) {
            final message = err['message'];
            if (message is String && message.trim().isNotEmpty) {
              return _localize(message);
            }
          }
          final nested = detail['message'];
          if (nested is String && nested.trim().isNotEmpty) return _localize(nested);
        }
        if (detail is String && detail.trim().isNotEmpty) return _localize(detail);
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) {
            final msg = first['msg'];
            if (msg is String && msg.trim().isNotEmpty) return _localize(msg);
          }
        }
        final top = data['error'];
        if (top is Map) {
          final message = top['message'];
          if (message is String && message.trim().isNotEmpty) return _localize(message);
        }
        if (top is String && top.trim().isNotEmpty) return _localize(top);
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Нет соединения с сервером';
      }
      final code = error.response?.statusCode;
      return code != null ? 'Ошибка $code' : 'Ошибка сети';
    }
    return _localize(error.toString());
  }
}
