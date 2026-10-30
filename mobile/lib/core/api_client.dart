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
