import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/progress_fixtures.dart';
import 'support/ui_replay.dart';

/// MS13 content regression: every campaign puzzle still works in the
/// reworked editor — its palette reads as words, its reference program can
/// be built by taps through the typed picker, it saves and restores, and it
/// renders, runs and reports on a 360 × 800 phone.
void main() {
  final campaign = shippedCampaign();
  final entries = [
    for (final world in campaign.manifest.worlds)
      for (final id in world.puzzleIds) (world.id, campaign.puzzles[id]!),
  ];

  test('95 campaign puzzles', () => expect(entries, hasLength(95)));

  for (final (world, puzzle) in entries) {
    final metrics = referenceFile(world, puzzle.id)['metrics']! as Map<String, Object?>;

    test('${puzzle.id}: palette in words, built by taps, runs, saves and restores', () {
      final c = EditorController(puzzle: puzzle);
      expect(c.paletteIds, isNotEmpty);
      for (final id in c.paletteIds) {
        final label = BlockChrome.labelOf(id);
        expect(label, isNot('BLOCK'), reason: '$id has player words');
        expect(label.contains('.'), isFalse, reason: '$id shows no catalog id');
      }

      final built = buildThroughEditor(puzzle, referenceSolution(world, puzzle.id));
      expect(built.blockCount, withoutStrays(built.graph).blockCount, reason: 'nothing left behind');
      final max = puzzle.blocks.maxBlocks;
      if (max != null) expect(built.blockCount, lessThanOrEqualTo(max));
      final outcome = runPuzzle(const DefaultEngine(), built.graph, puzzle);
      expect(outcome.suite.kind, ResultKind.correct, reason: '${outcome.suite.message}');
      expect(outcome.suite.metrics.ops, metrics['ops'], reason: 'the same program as the reference');

      final saved = reloaded(PlayerSave.fresh.withPuzzle(
        puzzle.id,
        PuzzleProgress(puzzleVersion: puzzle.version, draft: built.graphForSave),
      ))[puzzle.id]!.draft!;
      final restored = EditorController(puzzle: puzzle, initialGraph: saved);
      expect(graphText(restored.graph), graphText(built.graph));
    });

    testWidgets('${puzzle.id}: renders, runs and reports at 360 × 800', (tester) async {
      usePhone(tester, 360, 800);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: PuzzleEditor(puzzle: puzzle, initialGraph: referenceSolution(world, puzzle.id)),
          routes: {'/results': (_) => const ResultsScreen()},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(puzzle.title), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'RUN'));
      await tester.pumpAndSettle();
      expect(find.text('CORRECT'), findsOneWidget);
      for (final hidden in puzzle.hiddenTests) {
        expect(find.textContaining(hidden.id), findsNothing, reason: 'hidden case names never show');
      }
    });
  }
}
