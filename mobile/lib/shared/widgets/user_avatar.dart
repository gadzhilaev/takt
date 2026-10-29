import 'package:flutter/material.dart';

import '../../core/theme.dart';

String taktInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

Color taktAvatarColor(String name) {
  if (name.isEmpty) return TaktColors.avatarPalette.first;
  return TaktColors.avatarPalette[name.codeUnitAt(0) % TaktColors.avatarPalette.length];
}

/// Full circular avatar — solid fill, centered initials, no grey half-rings.
class TaktUserAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fs = fontSize ?? (size * 0.36).clamp(8.0, 14.0);
    final bg = taktAvatarColor(name);

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => _Initials(name: name, fontSize: fs),
              )
            : _Initials(name: name, fontSize: fs),
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
