# U2 — Light mode

**U2 COMPLETE.** The game in a light or a dark theme, chosen in Settings:
Light, Dark or System (the default, which follows the device). The user asked
for it on 2026-09-30: they do not like dark screens. No change to any puzzle,
budget, validator rule, engine code or interpreter behaviour, no architecture
change.

Previous commits: U1 (see `git log`), app icon `653a8ac`.

## What changed

| Piece | Where | What |
|---|---|---|
| Palettes | `lib/shared/theme/app_theme.dart` | `AppColors` (fixed dark constants) became `AppPalette`, a `ThemeExtension` with two values: `AppPalette.dark` (the MS13 colours, unchanged) and `AppPalette.light`. Same roles in both: `bg`, `elevated`, `subtle`, `fg`, `muted`, `faint`, `border`, `borderStrong`, `holeOutline`, `accent`, `accentFg`, `danger`, `warn`, `ok`, and the six block category strips (moved here from `EditorTheme`). |
| Access | same file | `context.palette.fg` replaces `AppColors.fg` (229 uses in 17 files); `AppText.label(context)` replaces `AppText.label`; `EditorTheme.strip/surface` take the context; `verdictStyle(kind, palette, [strings])` takes the palette. A bare `MaterialApp` in a widget test gets the palette of its brightness. |
| Theme | `buildAppTheme(AppPalette)` | One builder for both; `ColorScheme.dark` / `.light` from the palette, the palette attached as an extension, the status and navigation bar icons (`overlayStyleFor(brightness)`) dark on light and light on dark. |
| Setting | `PlayerSettings.theme` (`light`, `dark`, `system`; default `system`) | Saved in `settings.theme`. A save from before U2 reads as System without an issue; an unknown value reads as System with an issue. No save version change (an older build losing the field is harmless). **Reset progress keeps the theme**, like the language. |
| App | `lib/app.dart`, `lib/state/theme_providers.dart` | `MaterialApp.theme` light, `darkTheme` dark, `themeMode` from `themeModeProvider`; a switch rebuilds every open screen at once. |
| Settings | `lib/screens/settings/settings_screen.dart` | APPEARANCE / GÖRÜNÜM: Light / Dark / System (Açık / Koyu / Sistem), the same choice rows as the language (`_ChoiceOption`: filled mark and "selected" in words). |
| Android shell | `res/values/` light, `res/values-night/` dark | The launch window and the window behind Flutter follow the device's dark mode until Flutter draws. |
| Web shell | `web/index.html`, `web/manifest.json` | The page background before Flutter draws follows `prefers-color-scheme`; the manifest colours are light. |

## The light palette

Zinc greys; the ground is the app icon's `#F4F4F5`, cards and statements are
white, nested expressions and chips are `#E9E9EC`, the accent is the icon's
graphite `#373B44` with white text on it.

| Rule (MS13, both palettes) | Light, worst case |
|---|---|
| Text colours ≥ 4.5:1 on `bg`, `elevated`, `subtle` | `warn` on `subtle` 4.82 |
| Hole outline ≥ 3:1 on the block it sits in | on `subtle` 3.74 |
| Category strip ≥ 3:1 on `elevated` and `subtle` | `math` on `subtle` 3.51 |

`test/theme_test.dart` checks every one of these for both palettes, so a
colour change that breaks a rule fails the build.

## Tests

`test/theme_test.dart` (new): the contrast rules above for both palettes; the
theme carries its palette; a fresh install follows the device and follows it
again when the device switches; Light, Dark and System in Settings change the
app at once, are saved and win over the device; a saved choice is used from
the first screen; reset progress keeps the theme. `save_codec_test`: the
theme round-trips, old saves and unknown values give System. Every other
widget test now runs in the light theme (the test device is light), and the
sheet tests keep the dark theme (`buildAppTheme(AppPalette.dark)`), so both
palettes build every screen.

`flutter test`: 376 passed. Engine `dart test`: 350 passed.

## Emulator pass

Pixel 7 AVD (1080 × 2400): home, worlds, puzzle with a FOR EACH block,
block picker and hole picker sheets, results (invalid program), settings — in
light; settings with Dark chosen on a light device; System on a dark device;
the puzzle again in dark with its draft restored; the cold-start splash in
both device modes.

## Not done

- The theme loads with the save. A player who chose Light on a dark device
  sees the dark launch window for the moment before Flutter draws.
- `apple-mobile-web-app-status-bar-style` stays `black`.
