import 'package:algorun/app.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';

/// Light mode (2026-09-30): two palettes held to the same contrast rules, and
/// a Light / Dark / System setting that defaults to the device's choice.
final _campaign = shippedCampaign();

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _launch(WidgetTester tester, ProgressStore store) async {
  usePhone(tester, 390, 844);
  await tester.pumpWidget(
    ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
  );
  await tester.pumpAndSettle();
}

Brightness _shown(WidgetTester tester) => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

String _stored(MemoryProgressStore store) => decodeSave(store.text!).save.settings.theme;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, p) in [('dark', AppPalette.dark), ('light', AppPalette.light)]) {
    group('$name palette', () {
      final surfaces = {'bg': p.bg, 'elevated': p.elevated, 'subtle': p.subtle};

      test('every text colour is at least 4.5:1 on every surface', () {
        for (final text in p.textColors.entries) {
          for (final surface in surfaces.entries) {
            expect(_contrast(text.value, surface.value), greaterThanOrEqualTo(4.5),
                reason: '${text.key} on ${surface.key}');
          }
        }
        expect(_contrast(p.accentFg, p.accent), greaterThanOrEqualTo(4.5), reason: 'button text');
      });

      test('a hole outline and a category strip are at least 3:1 on the blocks they sit on', () {
        for (final surface in [p.elevated, p.subtle]) {
          expect(_contrast(Color.alphaBlend(p.holeOutline, surface), surface), greaterThanOrEqualTo(3));
          for (final strip in p.strips) {
            expect(_contrast(strip, surface), greaterThanOrEqualTo(3));
          }
        }
      });

      test('the theme carries the palette and its brightness', () {
        final theme = buildAppTheme(p);
        expect(theme.brightness, p.brightness);
        expect(theme.colorScheme.brightness, p.brightness);
        expect(theme.extension<AppPalette>(), same(p));
        expect(theme.scaffoldBackgroundColor, p.bg);
      });
    });
  }

  testWidgets('a fresh install follows the device: light, then dark when the device switches', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _launch(tester, MemoryProgressStore());
    expect(_shown(tester), Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.dark);
  });

  testWidgets('Light, Dark and System in Settings change the app at once and are saved', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = MemoryProgressStore();
    await _launch(tester, store);
    expect(_shown(tester), Brightness.dark);

    await _tap(tester, find.text('Settings'));
    expect(find.text('APPEARANCE'), findsOneWidget);
    final said = find.descendant(of: find.byKey(const Key('settings-theme-system')), matching: find.text('selected'));
    expect(said, findsOneWidget, reason: 'the default is System, said in words');

    await _tap(tester, find.byKey(const Key('settings-theme-light')));
    expect(_shown(tester), Brightness.light, reason: 'Light wins over a dark device');
    expect(_stored(store), 'light');
    expect(tester.getSemantics(find.byKey(const Key('settings-theme-light'))), isSemantics(isSelected: true));

    await _tap(tester, find.byKey(const Key('settings-theme-dark')));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_shown(tester), Brightness.dark, reason: 'Dark wins over a light device');
    expect(_stored(store), 'dark');

    await _tap(tester, find.byKey(const Key('settings-theme-system')));
    expect(_shown(tester), Brightness.light, reason: 'System follows the device again');
    expect(_stored(store), 'system');
  });

  testWidgets('reset progress keeps the theme', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = MemoryProgressStore();
    await _launch(tester, store);
    await _tap(tester, find.text('Settings'));
    await _tap(tester, find.byKey(const Key('settings-theme-light')));
    await _tap(tester, find.byKey(const Key('settings-reset')));
    await _tap(tester, find.byKey(const Key('settings-reset-confirm')));
    expect(_shown(tester), Brightness.light);
    expect(_stored(store), 'light');
  });

  testWidgets('a saved choice is used from the first screen', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    const save = PlayerSave(settings: PlayerSettings(theme: 'dark'));
    await _launch(tester, MemoryProgressStore(encodeSave(save)));
    expect(_shown(tester), Brightness.dark);
    expect(find.text('ENTER'), findsOneWidget);
  });
}
