import 'dart:math';

import 'package:flutter/material.dart';

/// Shared Kanban palette (aligned with web `frontend/src/lib/column-colors.ts`
/// and `urgency.ts`). Resolve surfaces from API `status.color` accents.
class KanbanColors {
  KanbanColors._();

  /// Board accents in preferred order — first free one wins for new columns.
  static const accentCandidates = <String>[
    '#607FA4',
    '#347FA4',
    '#9062B8',
    '#398A62',
    '#7B8794',
    '#A8895C',
    '#C45C4A',
    '#3D8B7A',
    '#B06A2B',
    '#5B6FCF',
  ];

  /// Next palette accent not already used on the board.
  static String suggestUnusedAccent(Iterable<String?> used) {
    final taken = <String>{
      for (final c in used)
        if (c != null && c.trim().isNotEmpty) c.trim().toLowerCase(),
    };
    for (final p in accentCandidates) {
      if (!taken.contains(p.toLowerCase())) return p;
    }
    final rng = Random();
    for (var i = 0; i < 32; i++) {
      final color = HSVColor.fromAHSV(
        1,
        rng.nextDouble() * 360,
        0.42 + rng.nextDouble() * 0.35,
        0.55 + rng.nextDouble() * 0.25,
      ).toColor();
      final hex =
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      if (!taken.contains(hex.toLowerCase())) return hex;
    }
    return accentCandidates.first;
  }

  static const boardBgLight = Color(0xFFE9EDF2);
  static const boardBgDark = Color(0xFF22272E);
  static const cardBgLight = Color(0xFFFFFFFF);
  static const cardBgDark = Color(0xFF353D47);
  static const cardBorderLight = Color(0xFFD5DDE5);
  static const cardBorderDark = Color(0xFF4A5563);
  static const titleLight = Color(0xFF1A2330);
  static const titleDark = Color(0xFFEDF1F5);
  static const descLight = Color(0xFF5A6878);
  static const descDark = Color(0xFFA8B3BF);
  static const doneTitleLight = Color(0xFF4A5564);
  static const doneTitleDark = Color(0xFFB8C2CC);

  static const _defaultAccent = '#607FA4';

  /// Previous standard accents → current accent (hex only, not by column name).
  static const _legacyAliases = <String, String>{
    '#94a3b8': '#607FA4',
    '#7892b2': '#607FA4',
    '#315f72': '#347FA4',
    '#4b8caf': '#347FA4',
    '#5c7380': '#9062B8',
    '#9774bd': '#9062B8',
    '#2f6b4f': '#398A62',
    '#4b9873': '#398A62',
  };

  /// Softer column shells than raw web fills — same accents, calmer mobile density.
  static const _presets = <String, _ColumnPreset>{
    '#607fa4': _ColumnPreset(
      accent: Color(0xFF607FA4),
      bg: Color(0xFFE4EAF2),
      border: Color(0xFFC5D0DC),
      bgDark: Color(0xFF2A333D),
      borderDark: Color(0xFF445363),
    ),
    '#347fa4': _ColumnPreset(
      accent: Color(0xFF347FA4),
      bg: Color(0xFFE0ECF3),
      border: Color(0xFFB5CBD8),
      bgDark: Color(0xFF26343C),
      borderDark: Color(0xFF3A5564),
    ),
    '#9062b8': _ColumnPreset(
      accent: Color(0xFF9062B8),
      bg: Color(0xFFECE4F4),
      border: Color(0xFFD2C2E0),
      bgDark: Color(0xFF302836),
      borderDark: Color(0xFF4E4258),
    ),
    '#398a62': _ColumnPreset(
      accent: Color(0xFF398A62),
      bg: Color(0xFFE2F0E8),
      border: Color(0xFFBDD4C6),
      bgDark: Color(0xFF28352F),
      borderDark: Color(0xFF3D5448),
    ),
    '#7b8794': _ColumnPreset(
      accent: Color(0xFF7B8794),
      bg: Color(0xFFEEF0F2),
      border: Color(0xFFD8DCE1),
      bgDark: Color(0xFF2C3238),
      borderDark: Color(0xFF404850),
    ),
    '#a8895c': _ColumnPreset(
      accent: Color(0xFFA8895C),
      bg: Color(0xFFF5F1EA),
      border: Color(0xFFE5DCCE),
      bgDark: Color(0xFF322E28),
      borderDark: Color(0xFF464036),
    ),
  };

  static String canonicalizeAccent(String? hex) {
    final raw = (hex == null || hex.isEmpty) ? _defaultAccent : hex.trim();
    final key = raw.toLowerCase();
    return _legacyAliases[key] ?? raw;
  }

  static Color parseHex(String? hex, {Color fallback = const Color(0xFF607FA4)}) {
    if (hex == null || hex.isEmpty) return fallback;
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return fallback;
  }

  static _ColumnPreset _resolveColumn(String? accentHex, {required bool dark}) {
    final canonical = canonicalizeAccent(accentHex);
    final key = canonical.toLowerCase();
    final preset = _presets[key];
    if (preset != null) return preset;
    final accent = parseHex(canonical);
    if (dark) {
      return _ColumnPreset(
        accent: accent,
        bg: Color.lerp(const Color(0xFF2A3038), accent, 0.28)!,
        border: Color.lerp(const Color(0xFF3F4752), accent, 0.40)!,
        bgDark: Color.lerp(const Color(0xFF2A3038), accent, 0.28)!,
        borderDark: Color.lerp(const Color(0xFF3F4752), accent, 0.40)!,
      );
    }
    return _ColumnPreset(
      accent: accent,
      bg: Color.lerp(const Color(0xFFF0F2F5), accent, 0.28)!,
      border: Color.lerp(const Color(0xFFD5DBE3), accent, 0.42)!,
      bgDark: Color.lerp(const Color(0xFF2A3038), accent, 0.28)!,
      borderDark: Color.lerp(const Color(0xFF3F4752), accent, 0.40)!,
    );
  }

  static Color columnBackground(String? accentHex, {required bool dark}) {
    final p = _resolveColumn(accentHex, dark: dark);
    return dark ? p.bgDark : p.bg;
  }

  static Color columnBorder(String? accentHex, {required bool dark}) {
    final p = _resolveColumn(accentHex, dark: dark);
    return dark ? p.borderDark : p.border;
  }

  static Color columnAccent(String? accentHex) =>
      _resolveColumn(accentHex, dark: false).accent;

  static UrgencyStyle urgency(String priority, {required bool dark}) {
    switch (priority) {
      case 'urgent':
        return UrgencyStyle(
          label: 'Срочно',
          fg: dark ? const Color(0xFFE88A8A) : const Color(0xFFC63F3F),
          bg: dark ? const Color(0xFF3A2828) : const Color(0xFFFCE8E8),
        );
      case 'high':
        return UrgencyStyle(
          label: 'Важно',
          fg: dark ? const Color(0xFFD4A45A) : const Color(0xFFC47A12),
          bg: dark ? const Color(0xFF3A3224) : const Color(0xFFFFF0D4),
        );
      default:
        return UrgencyStyle(
          label: 'Обычная',
          fg: dark ? const Color(0xFF7AADC4) : const Color(0xFF326E8B),
          bg: dark ? const Color(0xFF263540) : const Color(0xFFE4F0F6),
        );
    }
  }
}

class _ColumnPreset {
  const _ColumnPreset({
    required this.accent,
    required this.bg,
    required this.border,
    required this.bgDark,
    required this.borderDark,
  });

  final Color accent;
  final Color bg;
  final Color border;
  final Color bgDark;
  final Color borderDark;
}

class UrgencyStyle {
  const UrgencyStyle({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;
}
