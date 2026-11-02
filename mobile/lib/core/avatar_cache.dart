import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../shared/widgets/user_avatar.dart';

/// Disk cache for assignee/profile avatars so UI does not flash initials after splash.
class AvatarCache {
  AvatarCache._();
  static final AvatarCache instance = AvatarCache._();

  Directory? _dir;
  final _inflight = <String, Future<File?>>{};

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/avatar_cache_v1');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// Warm directory so [lookupSync] works after splash.
  Future<void> warm() async {
    await _ensureDir();
  }

  String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : null;
    if (last != null && last.isNotEmpty && last != 'avatars') {
      return last;
    }
    return url.hashCode.toUnsigned(32).toRadixString(16);
  }

  File _fileFor(Directory dir, String url) => File('${dir.path}/${_fileName(url)}');

  /// Sync hit only after [warm] / first async ensure.
  File? lookupSync(String url) {
    final dir = _dir;
    if (dir == null) return null;
    final f = _fileFor(dir, url);
    return f.existsSync() ? f : null;
  }

  Future<File?> ensure(String rawUrl) async {
    final url = resolveAvatarUrl(rawUrl);
    if (url == null) return null;
    return _inflight.putIfAbsent(url, () async {
      try {
        final dir = await _ensureDir();
        final file = _fileFor(dir, url);
        if (await file.exists() && await file.length() > 0) {
          return file;
        }
        final dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            responseType: ResponseType.bytes,
            validateStatus: (c) => c != null && c >= 200 && c < 300,
          ),
        );
        final res = await dio.get<List<int>>(url);
        final bytes = res.data;
        if (bytes == null || bytes.isEmpty) return null;
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (e) {
        debugPrint('── AvatarCache ✕ $url: $e');
        return null;
      } finally {
        unawaited(Future<void>.microtask(() => _inflight.remove(url)));
      }
    });
  }

  Future<void> prefetch(Iterable<String?> urls) async {
    await _ensureDir();
    final unique = <String>{};
    for (final raw in urls) {
      final u = resolveAvatarUrl(raw);
      if (u != null) unique.add(u);
    }
    if (unique.isEmpty) return;
    await Future.wait(unique.map(ensure));
  }
}
