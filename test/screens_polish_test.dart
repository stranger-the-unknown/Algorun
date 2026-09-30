import 'package:algorun/app.dart';
import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/progress_fixtures.dart';
import 'support/results_finders.dart';

/// MS13: how the results screen and the progression screens say things —
/// every verdict with an icon and words, the next puzzle, what a world
/// teaches and why something is locked.
final _campaign = shippedCampaign();

Puzzle _tiny() => tinyPuzzle('tiny');

Future<void> _results(WidgetTester tester, SuiteResult suite, {NextPuzzle? next}) async {
  usePhone(tester, 360, 800);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/results',
              arguments: ResultsArgs(
                puzzle: _tiny(),
                validation: const ValidationReport(messages: []),
                suite: suite,
                next: next,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    routes: {'/results': (_) => const ResultsScreen()},
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('every verdict has its own icon and sentence', () {
    final styles = [for (final k in ResultKind.values) verdictStyle(k, AppPalette.light)];
    expect({for (final s in styles) s.icon}.length, ResultKind.values.length);
    expect({for (final s in styles) s.meaning}.length, ResultKind.values.length);
  });

  for (final kind in [
    ResultKind.correct,
    ResultKind.wrongAnswer,
    ResultKind.runtimeError,
    ResultKind.operationLimit,
    ResultKind.memoryLimit,
    ResultKind.depthLimit,
    ResultKind.invalidProgram,
  ]) {
    testWidgets('${kind.label}: headline, icon and meaning, hidden cases as a count only', (tester) async {
      await _results(
        tester,
        SuiteResult(
          kind: kind,
          visible: const [],
          hiddenSummary: const HiddenSummary(passed: 1, total: 2),
          metrics: const RunMetrics(ops: 12, peakAlloc: 3, peakDepth: 1, blocks: 4, hintsUsed: 1),
        ),
      );
      expect(find.text(kind.label.toUpperCase()), findsOneWidget);
      expect(find.byIcon(verdictStyle(kind, AppPalette.light).icon), findsOneWidget);
      expect(find.text(verdictStyle(kind, AppPalette.light).meaning), findsOneWidget);
      expect(find.text('1 of 2 hidden cases passed.'), findsOneWidget);
      expect(find.text('BACK TO PUZZLE'), findsOneWidget);
      expect(find.byKey(const Key('results-next')), findsNothing);
      expect(costRow(tester, 'hints'), ['Hints', '1 hint', '—']);
    });
  }

  testWidgets('a solve offers the next puzzle; a failure never does', (tester) async {
    const next = NextPuzzle(worldId: 'world_01', puzzleId: 'highest_tide', title: 'Highest Tide', worldTitle: 'Foundations');
    await _results(
      tester,
      const SuiteResult(kind: ResultKind.correct, visible: [], metrics: RunMetrics.zero),
      next: next,
    );
    expect(find.text('NEXT: HIGHEST TIDE'), findsOneWidget);
    expect(find.text('BACK TO PUZZLE'), findsOneWidget);
  });

  test('the next puzzle: the first open unsolved one after this, wrapping around', () {
    PlayerSave solved(Iterable<String> ids) => PlayerSave(puzzles: {
          for (final id in ids) id: const PuzzleProgress(puzzleVersion: 1, completed: true),
        });
    final basics = _campaign.manifest.byId('world_01')!.puzzleIds;
    var progress = evaluateCampaign(_campaign, solved(['warm_readings']));
    expect(nextPuzzle(_campaign, progress, 'warm_readings'), 'highest_tide');
    progress = evaluateCampaign(_campaign, solved(['highest_tide']));
    expect(nextPuzzle(_campaign, progress, 'highest_tide'), 'ticket_price');
    progress = evaluateCampaign(_campaign, solved(basics.skip(1)));
    expect(nextPuzzle(_campaign, progress, basics.last), 'warm_readings', reason: 'wraps to an unsolved one');
    progress = evaluateCampaign(_campaign, solved(basics));
    expect(nextPuzzle(_campaign, progress, basics.last), 'lowest_balance', reason: 'Arrays just opened');
    progress = evaluateCampaign(_campaign, solved(_campaign.puzzles.keys));
    expect(nextPuzzle(_campaign, progress, 'many_shortest_routes'), isNull);
  });

  testWidgets('worlds say what they teach; puzzles say their tier, lock and progress', (tester) async {
    usePhone(tester, 390, 844);
    final warm = _campaign.puzzles['warm_readings']!;
    final save = saveDraft(openPuzzle(PlayerSave.fresh, _campaign, warm).$1, _campaign, warm, lengthGraph())
        .copyWith(session: null);
    await tester.pumpWidget(ProviderScope(
      overrides: campaignOverrides(MemoryProgressStore(encodeSave(save)), campaign: _campaign),
      child: const AlgorunApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTER'));
    await tester.pumpAndSettle();
    expect(find.text('Teaches arrays, prefix sum, binary search'), findsOneWidget);
    expect(find.text('Locked — learn variables first'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.lock_outline).first).semanticLabel, 'Locked',
        reason: 'a lock is an icon with a label, not a colour');

    await tester.tap(find.byKey(const Key('world-world_01')));
    await tester.pumpAndSettle();
    expect(find.text('01 · Foundations'), findsOneWidget);
    expect(find.text('0 of 12 solved · teaches variables, control'), findsOneWidget);
    // Twelve puzzles since MS15; the list builds the rows on screen.
    expect(find.text('Tier 1'), findsWidgets);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Not started'), findsWidgets);
  });
}
