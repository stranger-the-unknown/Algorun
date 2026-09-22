import 'package:flutter/material.dart';

/// Tokens. One accent family (steel), near-black surfaces, no neon, no purple.
abstract final class AppColors {
  static const bg = Color(0xFF0A0A0B);
  static const elevated = Color(0xFF121214);
  static const subtle = Color(0xFF1A1A1E);
  static const fg = Color(0xFFF4F4F5);
  static const muted = Color(0xFFA1A1AA);
  static const faint = Color(0xFF71717A);
  static const border = Color(0x1FF4F4F5);
  static const borderStrong = Color(0x38F4F4F5);
  static const accent = Color(0xFFC8CCD4);
  static const accentFg = Color(0xFF0A0A0B);
  static const danger = Color(0xFFC45C5C);
  static const warn = Color(0xFFC4A15C);
  static const ok = Color(0xFF6A9A72);
}

abstract final class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
}

abstract final class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    onPrimary: AppColors.accentFg,
    onSurface: AppColors.fg,
    secondary: AppColors.subtle,
    onSecondary: AppColors.fg,
    error: AppColors.danger,
    onError: AppColors.fg,
    outline: AppColors.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.fg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.fg,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.fg,
      displayColor: AppColors.fg,
    ),
    dividerColor: AppColors.border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentFg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.fg,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.muted,
      ),
    ),
  );
}
