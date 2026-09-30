import 'package:algorun/app.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/shared/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';

/// The web version on a computer: readable widths on a wide window, and an
/// address the browser opens without the screen's arguments goes home.
final _campaign = shippedCampaign();

Future<void> _launch(WidgetTester tester, ProgressStore store, {double width = 1400, double height = 850}) async {
  usePhone(tester, width, height, dpr: 1, top: 0, bottom: 0);
  await tester.pumpWidget(
    ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
  );
  await tester.pumpAndSettle();
}

Rect _button(WidgetTester tester, String label) =>
    tester.getRect(find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

MemoryProgressStore _inWarmReadings() {
  final warm = _campaign.puzzles['warm_readings']!;
  return MemoryProgressStore(encodeSave(openPuzzle(PlayerSave.fresh, _campaign, warm).$1));
}

void main() {
  testWidgets('on a 1400 px window the lists keep a readable width, centred', (tester) async {
    await _launch(tester, MemoryProgressStore());
    for (final (label, screen) in [('ENTER', 'Foundations'), ('Settings', 'APPEARANCE')]) {
      if (label == 'Settings') await _tap(tester, find.byType(BackButton));
      final home = _button(tester, label);
      expect(home.width, lessThanOrEqualTo(ContentWidth.readable));
      expect(home.width, greaterThan(ContentWidth.readable - 2 * 32), reason: 'buttons still span the column');
      expect(home.center.dx, closeTo(700, 1), reason: '$label is centred');
      await _tap(tester, find.text(label));
      final row = tester.getRect(find.text(screen));
      expect(row.left, greaterThanOrEqualTo((1400 - ContentWidth.readable) / 2));
      expect(row.right, lessThanOrEqualTo((1400 + ContentWidth.readable) / 2));
    }
  });

  testWidgets('a phone is unaffected', (tester) async {
    await _launch(tester, MemoryProgressStore(), width: 390, height: 844);
    expect(_button(tester, 'ENTER').width, greaterThanOrEqualTo(390 - 2 * 24));
  });

  testWidgets('the puzzle editor keeps its side palette within 1200 px on a 1920 px window', (tester) async {
    await _launch(tester, _inWarmReadings(), width: 1920, height: 1080);
    await _tap(tester, find.text('CONTINUE'));
    final script = tester.getRect(find.byType(ScriptView));
    expect(script.left, greaterThanOrEqualTo((1920 - ContentWidth.editor) / 2 + 280), reason: 'palette rail on its left');
    expect(script.right, lessThanOrEqualTo((1920 + ContentWidth.editor) / 2));
    expect(find.text('RUN'), findsOneWidget);
    expect(tester.getRect(find.text('RUN')).right, lessThanOrEqualTo((1920 + ContentWidth.editor) / 2));
  });

  testWidgets('a reload on a puzzle address opens home, and CONTINUE leads back', (tester) async {
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/puzzle';
    await _launch(tester, _inWarmReadings());
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Editor Probe'), findsNothing);
    await _tap(tester, find.text('CONTINUE'));
    expect(find.text('Warm Readings'), findsWidgets);
  });

  testWidgets('a screen opened without its arguments goes home instead of guessing', (tester) async {
    await _launch(tester, MemoryProgressStore());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    for (final route in ['/puzzle', '/puzzles', '/results']) {
      navigator.pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.text('ENTER'), findsOneWidget, reason: route);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });
}
