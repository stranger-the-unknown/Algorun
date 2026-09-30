import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The colour tokens of one theme, reached with `context.palette`.
///
/// Dark: one accent family (steel), near-black surfaces, no neon, no purple.
/// Light (2026-09-30): the same roles on zinc greys; the accent is the app
/// icon's graphite and the ground is the icon's `#F4F4F5`.
///
/// Contrast (MS13, WCAG), in both palettes and checked by
/// `test/theme_test.dart`: every text colour is at least 4.5:1 on `bg`,
/// `elevated` and `subtle`; a hole's outline is at least 3:1 against the
/// surface it sits on; a block's category strip is at least 3:1. Colour never
/// carries meaning alone: every status also has an icon or words.
@immutable
final class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.elevated,
    required this.subtle,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.border,
    required this.borderStrong,
    required this.holeOutline,
    required this.accent,
    required this.accentFg,
    required this.danger,
    required this.warn,
    required this.ok,
    required this.stripControl,
    required this.stripValue,
    required this.stripLogic,
    required this.stripMath,
    required this.stripCollection,
    required this.stripStructure,
  });

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0A0A0B),
    elevated: Color(0xFF121214),
    subtle: Color(0xFF1A1A1E),
    fg: Color(0xFFF4F4F5),
    muted: Color(0xFFA1A1AA),
    faint: Color(0xFF8B8B94),
    border: Color(0x1FF4F4F5),
    borderStrong: Color(0x38F4F4F5),
    holeOutline: Color(0x70F4F4F5),
    accent: Color(0xFFC8CCD4),
    accentFg: Color(0xFF0A0A0B),
    danger: Color(0xFFD46A6A),
    warn: Color(0xFFC4A15C),
    ok: Color(0xFF6A9A72),
    stripControl: Color(0xFF6B8AA8),
    stripValue: Color(0xFF8A8A92),
    stripLogic: Color(0xFF5E8A84),
    stripMath: Color(0xFF9A9AA3),
    stripCollection: Color(0xFF8A8070),
    stripStructure: Color(0xFF7A7E8A),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF4F4F5),
    elevated: Color(0xFFFFFFFF),
    subtle: Color(0xFFE9E9EC),
    fg: Color(0xFF18181B),
    muted: Color(0xFF4F4F57),
    faint: Color(0xFF5E5E67),
    border: Color(0x2418181B),
    borderStrong: Color(0x4518181B),
    holeOutline: Color(0x8C18181B),
    accent: Color(0xFF373B44),
    accentFg: Color(0xFFFFFFFF),
    danger: Color(0xFFAE3434),
    warn: Color(0xFF80600F),
    ok: Color(0xFF3B6F44),
    stripControl: Color(0xFF4F7394),
    stripValue: Color(0xFF6E6E77),
    stripLogic: Color(0xFF3F726B),
    stripMath: Color(0xFF7A7A84),
    stripCollection: Color(0xFF7A6D58),
    stripStructure: Color(0xFF5F6472),
  );

  final Brightness brightness;
  final Color bg;
  final Color elevated;
  final Color subtle;
  final Color fg;
  final Color muted;
  final Color faint;
  final Color border;
  final Color borderStrong;
  final Color holeOutline;
  final Color accent;
  final Color accentFg;
  final Color danger;
  final Color warn;
  final Color ok;

  /// Block category strips (`EditorTheme.strip`).
  final Color stripControl;
  final Color stripValue;
  final Color stripLogic;
  final Color stripMath;
  final Color stripCollection;
  final Color stripStructure;

  /// Text colours, each held to 4.5:1 on every surface.
  Map<String, Color> get textColors =>
      {'fg': fg, 'muted': muted, 'faint': faint, 'accent': accent, 'danger': danger, 'warn': warn, 'ok': ok};

  List<Color> get strips => [stripControl, stripValue, stripLogic, stripMath, stripCollection, stripStructure];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      elevated: mix(elevated, other.elevated),
      subtle: mix(subtle, other.subtle),
      fg: mix(fg, other.fg),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      holeOutline: mix(holeOutline, other.holeOutline),
      accent: mix(accent, other.accent),
      accentFg: mix(accentFg, other.accentFg),
      danger: mix(danger, other.danger),
      warn: mix(warn, other.warn),
      ok: mix(ok, other.ok),
      stripControl: mix(stripControl, other.stripControl),
      stripValue: mix(stripValue, other.stripValue),
      stripLogic: mix(stripLogic, other.stripLogic),
      stripMath: mix(stripMath, other.stripMath),
      stripCollection: mix(stripCollection, other.stripCollection),
      stripStructure: mix(stripStructure, other.stripStructure),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The current theme's colour tokens. A bare theme (a widget test's plain
  /// `MaterialApp`) gets the palette of its brightness.
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
  }
}

/// Type sizes. Small caps labels never go below 11.
abstract final class AppText {
  static TextStyle label(BuildContext context) => TextStyle(
        color: context.palette.faint,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w600,
      );
}

/// The system font size is honoured up to this factor; beyond it the block
/// editor would no longer fit a phone. (MS13)
const maxTextScale = 1.6;

/// Status and navigation bar icons that read on the theme's surfaces, edge
/// to edge.
SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    // No scrim behind three-button navigation: the app's own background
    // shows there, and every screen keeps clear of it.
    systemNavigationBarContrastEnforced: false,
  );
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

/// The app theme for one palette; [AppPalette] rides along as an extension.
ThemeData buildAppTheme(AppPalette p) {
  final dark = p.brightness == Brightness.dark;
  final scheme = (dark ? ColorScheme.dark : ColorScheme.light)(
    surface: p.bg,
    primary: p.accent,
    onPrimary: p.accentFg,
    onSurface: p.fg,
    secondary: p.subtle,
    onSecondary: p.fg,
    error: p.danger,
    onError: dark ? p.fg : Colors.white,
    outline: p.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    colorScheme: scheme,
    extensions: [p],
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlayStyleFor(p.brightness),
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: p.fg,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: p.fg,
      displayColor: p.fg,
    ),
    dividerColor: p.border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Never an infinite minimum width: in a Row that fails layout and the
        // whole sheet disappears (the number pad did, MS13). Full-width
        // buttons stretch in their Column instead.
        minimumSize: const Size(64, 48),
        backgroundColor: p.accent,
        foregroundColor: p.accentFg,
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
        foregroundColor: p.fg,
        side: BorderSide(color: p.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: p.muted,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: p.fg,
        disabledForegroundColor: p.faint.withValues(alpha: 0.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.subtle,
      side: BorderSide(color: p.borderStrong),
      labelStyle: TextStyle(color: p.fg, fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.subtle,
      contentTextStyle: TextStyle(color: p.fg),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.subtle,
    ),
  );
}
