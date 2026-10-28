import 'package:flutter/material.dart';

import 'kanban_colors.dart';

class TaktColors {
  static const accent = Color(0xFF315F72);
  static const graphite = Color(0xFF202938);
  static const canvas = KanbanColors.boardBgLight;
  static const urgent = Color(0xFFC63F3F);
  static const important = Color(0xFFC47A12);
  static const normal = Color(0xFF326E8B);
}

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TaktColors.accent,
      primary: TaktColors.accent,
      surface: KanbanColors.cardBgLight,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: KanbanColors.boardBgLight,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: KanbanColors.boardBgLight,
      foregroundColor: TaktColors.graphite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: TaktColors.graphite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: const Color(0xFFE1EDF5),
      checkmarkColor: const Color(0xFF347FA4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TaktColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: TaktColors.graphite.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: TaktColors.graphite.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TaktColors.accent, width: 1.4),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  const surface = KanbanColors.cardBgDark;
  const canvas = KanbanColors.boardBgDark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TaktColors.accent,
      primary: const Color(0xFF6A9AAB),
      surface: surface,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: canvas,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: Color(0xFFE8EEF2),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TaktColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
