import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'token_storage.dart';
import '../features/board/cubit/board_cubit.dart';

/// Live board sync via `WS /ws` with `Authorization: Bearer` (cookie on web).
class BoardRealtime {
  BoardRealtime({
    required this.tokens,
    required this.boardCubit,
  });

  final TokenStorage tokens;
  final BoardCubit boardCubit;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _debounce;
  int _attempt = 0;
  bool _wantConnected = false;
  bool _refreshing = false;

  Future<void> start() async {
    _wantConnected = true;
    await _connect();
  }

  Future<void> stop() async {
    _wantConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _debounce?.cancel();
    _debounce = null;
    await _tearDownSocket();
    _attempt = 0;
  }

  void dispose() {
    unawaited(stop());
  }

  Future<void> _tearDownSocket() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {
      /* ignore */
    }
    _socket = null;
  }

  Uri? _wsUri() {
    final base = AppConfig.apiBase.replaceFirst(RegExp(r'/+$'), '');
    final http = Uri.parse(base);
    final scheme = http.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: http.host,
      port: http.hasPort ? http.port : null,
      path: '/ws',
    );
  }

  Future<void> _connect() async {
    if (!_wantConnected) return;
    await _tearDownSocket();
    final access = await tokens.readAccess();
    if (access == null || access.isEmpty) return;
    final uri = _wsUri();
    if (uri == null) return;

    try {
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: {'Authorization': 'Bearer $access'},
      );
      if (!_wantConnected) {
        await socket.close();
        return;
      }
      _socket = socket;
      _sub = socket.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _attempt = 0;
      debugPrint('BoardRealtime: connected');
    } catch (e) {
      debugPrint('BoardRealtime: connect failed $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wantConnected) return;
    _reconnectTimer?.cancel();
    final delayMs = (1000 * (1 << _attempt.clamp(0, 5))).clamp(1000, 30000);
    _attempt += 1;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_connect());
    });
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    String? projectId;
    String? event;
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      event = msg['event'] as String?;
      final data = msg['data'];
      if (data is Map<String, dynamic>) {
        projectId = data['project_id'] as String?;
        final task = data['task'];
        if (projectId == null && task is Map<String, dynamic>) {
          projectId = task['project_id'] as String?;
        }
      }
    } catch (_) {
      return;
    }
    if (event == null || !event.startsWith('task.')) return;

    final openId = boardCubit.state.project?.id;
    if (openId == null) return;
    if (projectId != null && projectId != openId) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_silentRefresh());
    });
  }

  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    if (boardCubit.state.project == null) return;
    _refreshing = true;
    try {
      await boardCubit.refreshBoard(forceLoading: false);
    } finally {
      _refreshing = false;
    }
  }
}
