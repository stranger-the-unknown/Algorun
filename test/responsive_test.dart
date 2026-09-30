import 'package:algorun/app.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/progress_fixtures.dart';

/// The whole flow on the MS13 target phones, portrait and landscape, at the
/// default and a large system font: nothing overflows (an overflow fails the
/// test), and RUN / NEXT stay clear of the system bars.
final _campaign = shippedCampaign();
final _warm = _campaign.puzzles['warm_readings']!;

/// A device that left Warm Readings with its solution in the editor.
MemoryProgressStore _device() {
  final opened = openPuzzle(PlayerSave.fresh, _campaign, _warm).$1;
  return MemoryProgressStore(encodeSave(
    saveDraft(opened, _campaign, _warm, referenceSolution('world_01', 'warm_readings')),
  ));
}

/// Scrolls the screen's main list until [finder] is built and on screen
/// (long briefs and large fonts push things below the fold).
Future<void> _see(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final script = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable));
    final list = script.evaluate().isNotEmpty ? script.first : find.byType(Scrollable).first;
    await tester.scrollUntilVisible(finder, 120, scrollable: list);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _see(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  const phones = [
    (360.0, 800.0, 'portrait 360 × 800'),
    (390.0, 844.0, 'portrait 390 × 844'),
    (412.0, 915.0, 'portrait 412 × 915'),
    (800.0, 360.0, 'landscape 800 × 360'),
    (915.0, 412.0, 'landscape 915 × 412'),
  ];
  for (final (width, height, name) in phones) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('$name, font ×$scale: home → worlds → continue → hint → RUN → next → back', (tester) async {
        final landscape = width > height;
        usePhone(tester, width, height, textScale: scale, bottom: landscape ? 24 : 48);
        final store = _device();
        await tester.pumpWidget(
          ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Last played: Warm Readings · Foundations'), findsOneWidget);
        await _tap(tester, find.text('WORLDS'));
        expect(find.text('Foundations'), findsOneWidget);
        await _see(tester, find.text('Teaches variables, control'));
        await _tap(tester, find.byType(BackButton));

        await _tap(tester, find.byKey(const Key('home-continue')));
        expect(find.text('Warm Readings'), findsOneWidget);
        final run = find.widgetWithText(FilledButton, 'RUN');
        expect(clearOfSystemBars(tester, run), isTrue, reason: 'RUN is above the navigation bar');
        expect(run.hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('block-count')), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(EditableText), findsNothing, reason: 'no keyboard ever opens for programming');

        await _tap(tester, find.byKey(const Key('hints-reveal')));
        await _see(tester, find.text('1. ${_warm.hints.first}'));

        await _tap(tester, run);
        expect(find.text('CORRECT'), findsOneWidget);
        await _see(tester, find.text('Puzzle solved.'));
        final next = find.byKey(const Key('results-next'));
        expect(clearOfSystemBars(tester, next), isTrue);
        expect(find.text('NEXT: HIGHEST TIDE'), findsOneWidget);

        await _tap(tester, next);
        expect(find.text('Highest Tide'), findsOneWidget, reason: 'the next puzzle replaced the solved one');
        await _tap(tester, find.byType(BackButton));
        expect(find.text('CONTINUE'), findsOneWidget);
        expect(find.text('Last played: Highest Tide · Foundations'), findsOneWidget);
        expect(find.text('1 of 95 puzzles solved'), findsOneWidget);
        expect(decodeSave(store.text!).save['warm_readings']!.completed, isTrue);
      });
    }
  }

  testWidgets('a system font at ×2 is capped and still lays out', (tester) async {
    usePhone(tester, 360, 800, textScale: 2);
    await tester.pumpWidget(
      ProviderScope(overrides: campaignOverrides(_device(), campaign: _campaign), child: const AlgorunApp()),
    );
    await tester.pumpAndSettle();
    final scaler = MediaQuery.textScalerOf(tester.element(find.text('CONTINUE')));
    expect(scaler.scale(10), closeTo(16, 0.01), reason: 'capped at ×1.6');
    await _tap(tester, find.byKey(const Key('home-continue')));
    expect(find.widgetWithText(FilledButton, 'RUN').hitTestable(), findsOneWidget);
  });
}
