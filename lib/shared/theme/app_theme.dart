import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tokens. One accent family (steel), near-black surfaces, no neon, no purple.
///
/// Contrast (MS13, WCAG): every text colour is at least 4.5:1 on `bg`,
/// `elevated` and `subtle` (`faint` 5.1:1 at worst); a hole's outline is at
/// least 3:1 against the surface it sits on. Colour never carries meaning
/// alone: every status also has an icon or words.
abstract final class AppColors {
  static const bg = Color(0xFF0A0A0B);
  static const elevated = Color(0xFF121214);
  static const subtle = Color(0xFF1A1A1E);
  static const fg = Color(0xFFF4F4F5);
  static const muted = Color(0xFFA1A1AA);
  static const faint = Color(0xFF8B8B94);
  static const border = Color(0x1FF4F4F5);
  static const borderStrong = Color(0x38F4F4F5);
  static const holeOutline = Color(0x70F4F4F5);
  static const accent = Color(0xFFC8CCD4);
  static const accentFg = Color(0xFF0A0A0B);
  static const danger = Color(0xFFD46A6A);
  static const warn = Color(0xFFC4A15C);
  static const ok = Color(0xFF6A9A72);
}

/// Type sizes. Small caps labels never go below 11.
abstract final class AppText {
  static const label = TextStyle(
    color: AppColors.faint,
    fontSize: 11,
    letterSpacing: 1.3,
    fontWeight: FontWeight.w600,
  );
}

/// The system font size is honoured up to this factor; beyond it the block
/// editor would no longer fit a phone. (MS13)
const maxTextScale = 1.6;

/// Light status and navigation bar icons on the dark surfaces, edge to edge.
const appOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  // No light scrim behind three-button navigation: the app's own dark
  // background shows there, and every screen keeps clear of it.
  systemNavigationBarContrastEnforced: false,
);

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
      scrolledUnderElevation: 0,
      systemOverlayStyle: appOverlayStyle,
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
        // Never an infinite minimum width: in a Row that fails layout and the
        // whole sheet disappears (the number pad did, MS13). Full-width
        // buttons stretch in their Column instead.
        minimumSize: const Size(64, 48),
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
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.muted,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.fg,
        disabledForegroundColor: AppColors.faint.withValues(alpha: 0.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.subtle,
      side: const BorderSide(color: AppColors.borderStrong),
      labelStyle: const TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.subtle,
      contentTextStyle: TextStyle(color: AppColors.fg),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.subtle,
    ),
  );
}
