import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kanban_colors.dart';

/// Design tokens mirrored from `frontend/src/app/globals.css`.
class TaktColors {
  static const accent = Color(0xFF315F72);
  static const accentDark = Color(0xFF6A9AAB);
  static const accentSoft = Color(0xFFE8EEF1);
  static const accentSoftDark = Color(0xFF2A3840);
  static const graphite = Color(0xFF202938);
  static const foregroundDark = Color(0xFFE7EBEF);
  static const muted = Color(0xFF667485);
  static const mutedDark = Color(0xFFAEB8C3);
  static const border = Color(0xFFDCE2E7);
  static const borderDark = Color(0xFF46505B);
  static const borderStrong = Color(0xFFC5CED6);
  static const borderStrongDark = Color(0xFF556170);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF353D47);
  static const surface2 = Color(0xFFF1F3F5);
  static const surface2Dark = Color(0xFF2D343D);
  static const success = Color(0xFF2F6B4F);
  static const successDark = Color(0xFF6FA88A);
  static const danger = Color(0xFFB42318);
  static const canvas = KanbanColors.boardBgLight;
  static const urgent = Color(0xFFC63F3F);
  static const important = Color(0xFFC47A12);
  static const normal = Color(0xFF326E8B);

  static const avatarPalette = <Color>[
    Color(0xFF4B8CAF),
    Color(0xFF7892B2),
    Color(0xFF4B9873),
    Color(0xFF9774BD),
    Color(0xFFA8895C),
  ];
}

class TaktRadii {
  static const sm = 6.0; // 0.375rem
  static const md = 8.0; // 0.5rem
  static const lg = 8.0;
  static const pill = 999.0;
}

class TaktSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const page = 20.0;
}

TextStyle taktTitleStyle({required bool dark, bool done = false}) => TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: -0.12,
      color: done
          ? (dark ? KanbanColors.doneTitleDark : KanbanColors.doneTitleLight)
          : (dark ? KanbanColors.titleDark : KanbanColors.titleLight),
    );

TextStyle taktDescStyle({required bool dark, bool done = false}) => TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: done
          ? (dark ? const Color(0xFF8E99A6) : const Color(0xFF6B7787))
          : (dark ? KanbanColors.descDark : KanbanColors.descLight),
    );

ThemeData buildLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: null,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TaktColors.accent,
      primary: TaktColors.accent,
      surface: TaktColors.surface,
      onSurface: TaktColors.graphite,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: KanbanColors.boardBgLight,
  );
  return base.copyWith(
    dividerColor: TaktColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: TaktColors.surface,
      foregroundColor: TaktColors.graphite,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: TaktColors.graphite,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: TaktColors.graphite, size: 22),
      actionsIconTheme: IconThemeData(color: TaktColors.graphite, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      toolbarHeight: 52,
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: TaktColors.accentSoft,
      checkmarkColor: TaktColors.accent,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.pill)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TaktColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TaktColors.graphite,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: TaktColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TaktColors.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TaktColors.surface,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.accent, width: 1.4),
      ),
      hintStyle: const TextStyle(fontSize: 14, color: TaktColors.muted),
      labelStyle: const TextStyle(fontSize: 14, color: TaktColors.muted),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: TaktColors.graphite,
      ),
      subtitleTextStyle: TextStyle(fontSize: 13, color: TaktColors.muted, height: 1.35),
    ),
    cardTheme: CardThemeData(
      color: TaktColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        side: const BorderSide(color: TaktColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
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
      primary: TaktColors.accentDark,
      surface: surface,
      onSurface: TaktColors.foregroundDark,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: canvas,
  );
  return base.copyWith(
    dividerColor: TaktColors.borderDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: TaktColors.surfaceDark,
      foregroundColor: TaktColors.foregroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: TaktColors.foregroundDark,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: TaktColors.foregroundDark, size: 22),
      toolbarHeight: 52,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TaktColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TaktColors.foregroundDark,
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: const BorderSide(color: TaktColors.borderStrongDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TaktRadii.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TaktColors.accentDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TaktRadii.md),
        borderSide: const BorderSide(color: TaktColors.accentDark, width: 1.4),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: TaktColors.foregroundDark,
      ),
      subtitleTextStyle: TextStyle(fontSize: 13, color: TaktColors.mutedDark, height: 1.35),
    ),
  );
}
