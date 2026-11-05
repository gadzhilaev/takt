import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/avatar_cache.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

/// Одна буква — как на сайте для коротких/одиночных имён.
String taktInitials(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  return t[0].toUpperCase();
}

Color taktAvatarColor(String name) {
  if (name.isEmpty) return TaktColors.avatarPalette.first;
  return TaktColors.avatarPalette[name.codeUnitAt(0) % TaktColors.avatarPalette.length];
}

/// Backend отдаёт `/api/v1/files/avatars/...` — на web это same-origin, в mobile нужен абсолютный URL.
String? resolveAvatarUrl(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  final base = AppConfig.apiBase.replaceFirst(RegExp(r'/+$'), '');
  if (trimmed.startsWith('/')) return '$base$trimmed';
  return '$base/$trimmed';
}

/// Full circular avatar — disk-cached image when possible (no network flash after splash).
class TaktUserAvatar extends StatefulWidget {
  const TaktUserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 28,
    this.fontSize,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final double? fontSize;

  @override
  State<TaktUserAvatar> createState() => _TaktUserAvatarState();
}

class _TaktUserAvatarState extends State<TaktUserAvatar> {
  File? _file;
  String? _resolved;

  @override
  void initState() {
    super.initState();
    _bind(widget.avatarUrl);
  }

  @override
  void didUpdateWidget(covariant TaktUserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _bind(widget.avatarUrl);
    }
  }

  void _bind(String? raw) {
    final url = resolveAvatarUrl(raw);
    _resolved = url;
    if (url == null) {
      _file = null;
      return;
    }
    final hit = AvatarCache.instance.lookupSync(url);
    _file = hit;
    if (hit == null) {
      unawaited(_load(url));
    }
  }

  Future<void> _load(String url) async {
    final file = await AvatarCache.instance.ensure(url);
    if (!mounted || _resolved != url) return;
    if (file != null) {
      setState(() => _file = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.fontSize ?? (widget.size * 0.42).clamp(9.0, 16.0);
    final bg = taktAvatarColor(widget.name);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? TaktColors.borderStrongDark : TaktColors.borderStrong;
    final file = _file;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 1),
        ),
        child: ClipOval(
          child: file != null
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: widget.size,
                  height: widget.size,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _Initials(name: widget.name, fontSize: fs),
                )
              : _Initials(name: widget.name, fontSize: fs),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.fontSize});
  final String name;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        taktInitials(name),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: -0.2,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
  }
}

/// Side-by-side avatars + optional +N (same layout as web task cards).
class TaktAssigneeRow extends StatelessWidget {
  const TaktAssigneeRow({
    super.key,
    required this.names,
    this.avatarUrls = const [],
    this.maxVisible = 4,
    this.size = 22,
    this.gap = 4,
  });

  final List<String> names;
  final List<String?> avatarUrls;
  final int maxVisible;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shown = names.take(maxVisible).toList();
    final more = names.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          TaktUserAvatar(
            name: shown[i],
            avatarUrl: i < avatarUrls.length ? avatarUrls[i] : null,
            size: size,
          ),
        ],
        if (more > 0) ...[
          SizedBox(width: gap),
          Text(
            '+$more',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: dark ? TaktColors.mutedDark : TaktColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}
