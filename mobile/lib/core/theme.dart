import 'package:flutter/material.dart';

class TaktColors {
  static const accent = Color(0xFF315F72);
  static const graphite = Color(0xFF202938);
  static const canvas = Color(0xFFF7F8FA);
  static const urgent = Color(0xFFC2413B);
  static const important = Color(0xFFB7791F);
  static const normal = Color(0xFF315F72);
}

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TaktColors.accent,
      primary: TaktColors.accent,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: TaktColors.canvas,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: TaktColors.canvas,
      foregroundColor: TaktColors.graphite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: TaktColors.graphite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
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
  const surface = Color(0xFF1A222C);
  const canvas = Color(0xFF141A22);
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
