import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campaign_files.dart';
import '../support/progress_fixtures.dart';

final _campaign = ms11Campaign();

Puzzle _puzzle(String id) => _campaign.puzzles[id]!;

/// A save in which [ids] are solved (as a real RUN would record it).
PlayerSave _solved(Iterable<String> ids) => PlayerSave(puzzles: {
      for (final id in ids)
        id: const PuzzleProgress(
          puzzleVersion: 1,
          completed: true,
          best: RunNumbers(ops: 1, peakAlloc: 0, peakDepth: 1, blocks: 1, hintsUsed: 0),
        ),
    });

(PlayerSave, RunRecordOutcome) _run(PlayerSave save, String id, BlockGraph graph) {
  final outcome = runPuzzle(const DefaultEngine(), graph, _puzzle(id));
  return recordRun(save, _campaign, _puzzle(id), graph, outcome.suite);
}

void main() {
  group('the shipped campaign', () {
    test('16. a fresh install opens Arrays and its first puzzle, nothing past it', () {
      final p = evaluateCampaign(_campaign, PlayerSave.fresh);
      expect(p.worldStatus('world_01'), WorldStatus.empty);
      expect(p.worldStatus('world_02'), WorldStatus.open);
      expect(p.puzzleStatus('smallest_cart'), PuzzleStatus.open);
      for (final id in ['twin_beacons', 'quota_hours', 'relay_towers', 'fewest_rides']) {
        expect(p.puzzleStatus(id), PuzzleStatus.locked, reason: id);
      }
      expect(p.missingFor('world_03'), ['arrays']);
      expect(p.missingFor('world_05'), ['two_pointers']);
      expect(p.missingFor('world_10'), ['tree']);
      expect(p.missingFor('world_12'), ['recursion']);
      expect(p.mastered, {'variables', 'control'});
      expect(p.solvedCount, 0);
      expect(p.puzzleCount, 5);
      expect(p.currentPuzzleId, isNull);
    });

    test('17. solving a real puzzle completes it and masters what its world teaches', () {
      final (save, outcome) = _run(PlayerSave.fresh, 'smallest_cart', referenceSolution('world_02', 'smallest_cart'));
      final cart = save['smallest_cart']!;
      expect(cart.completed, isTrue);
      expect(cart.best!.ops, 65204);
      expect(cart.best!.blocks, 55);
      expect(cart.lastRun!.result, ResultKind.correct);
      expect(outcome.firstCompletion, isTrue);
      expect(outcome.newSolution, isTrue);
      final p = evaluateCampaign(_campaign, save);
      expect(p.worldStatus('world_02'), WorldStatus.completed);
      expect(p.mastered, containsAll(['arrays', 'prefix_sum', 'binary_search']));
      expect(p.solvedCount, 1);
    });

    test('18. prerequisites open the next worlds — through chapters that have no puzzles yet', () {
      final (save, outcome) = _run(PlayerSave.fresh, 'smallest_cart', referenceSolution('world_02', 'smallest_cart'));
      expect(outcome.opened.map((w) => w.title), ['Hash Maps', 'Sliding Window', 'Stack & Queue']);
      final p = evaluateCampaign(_campaign, save);
      // Two Pointers has no puzzles, so it completes as it opens and passes
      // two_pointers on to Sliding Window.
      expect(p.worldStatus('world_04'), WorldStatus.empty);
      expect(p.puzzleStatus('quota_hours'), PuzzleStatus.open);
      expect(p.puzzleStatus('twin_beacons'), PuzzleStatus.open);
      expect(p.puzzleStatus('relay_towers'), PuzzleStatus.open);
      expect(p.puzzleStatus('fewest_rides'), PuzzleStatus.locked);
      expect(p.missingFor('world_07'), ['stack']);

      final after = evaluateCampaign(_campaign, _solved(['smallest_cart', 'relay_towers']));
      // Stack & Queue → Linked Lists → Trees (both empty) → Graphs.
      expect(after.worldStatus('world_07'), WorldStatus.empty);
      expect(after.worldStatus('world_08'), WorldStatus.empty);
      expect(after.puzzleStatus('fewest_rides'), PuzzleStatus.open);
      expect(after.worldStatus('world_12'), WorldStatus.locked, reason: 'no world teaches recursion');
      expect(after.worldStatus('world_14'), WorldStatus.locked);
    });

    test('19. a locked puzzle stays locked: it cannot be opened or recorded', () {
      final twin = _puzzle('twin_beacons');
      final (opened, _) = openPuzzle(PlayerSave.fresh, _campaign, twin);
      expect(opened.session, isNull);
      final (recorded, outcome) =
          recordRun(PlayerSave.fresh, _campaign, twin, lengthGraph(), suite(ResultKind.correct));
      expect(identical(recorded, PlayerSave.fresh), isTrue);
      expect(outcome.firstCompletion, isFalse);
      expect(evaluateCampaign(_campaign, recorded).puzzleStatus('twin_beacons'), PuzzleStatus.locked);
    });

    test('20. the dev probes are never recorded and never move progression', () {
      final probe = shippedPuzzle('world_01', 'l1_list_probe');
      final graph = referenceSolution('world_01', 'l1_list_probe');
      final result = runPuzzle(const DefaultEngine(), graph, probe).suite;
      expect(result.kind, ResultKind.correct);
      final (afterRun, outcome) = recordRun(PlayerSave.fresh, _campaign, probe, graph, result);
      final (afterOpen, opened) = openPuzzle(PlayerSave.fresh, _campaign, probe);
      final afterDraft = saveDraft(PlayerSave.fresh, _campaign, probe, graph);
      expect(identical(afterRun, PlayerSave.fresh), isTrue);
      expect(identical(afterOpen, PlayerSave.fresh), isTrue);
      expect(identical(afterDraft, PlayerSave.fresh), isTrue);
      expect(outcome.firstCompletion, isFalse);
      expect(opened.graph, isNull);
      // Even a hand-edited save that claims a probe changes nothing.
      final claimed = PlayerSave(puzzles: {
        for (final id in ['ms1_contract_probe', 'ms3_editor_probe', 'l1_list_probe', 'l1_tree_probe'])
          id: const PuzzleProgress(puzzleVersion: 1, completed: true),
      });
      final p = evaluateCampaign(_campaign, claimed);
      expect(p.solvedCount, 0);
      expect(p.mastered, evaluateCampaign(_campaign, PlayerSave.fresh).mastered);
    });

    test('21. correct but over the operation budget does not complete a puzzle', () {
      final start = _solved(['smallest_cart']);
      final (save, outcome) = _run(start, 'twin_beacons', referenceReject('world_03', 'twin_beacons', 'compare every pair'));
      final twin = save['twin_beacons']!;
      expect(twin.lastRun!.result, ResultKind.operationLimit);
      expect(twin.completed, isFalse);
      expect(twin.best, isNull);
      expect(twin.solution, isNull);
      expect(outcome.firstCompletion, isFalse);
      expect(evaluateCampaign(_campaign, save).puzzleStatus('twin_beacons'), PuzzleStatus.inProgress);
    });

    test('22. a wrong answer does not complete a puzzle', () {
      final start = _solved(['smallest_cart']);
      final (save, _) = _run(start, 'twin_beacons', referenceReject('world_03', 'twin_beacons', 'add before asking'));
      expect(save['twin_beacons']!.lastRun!.result, ResultKind.wrongAnswer);
      expect(save['twin_beacons']!.completed, isFalse);
      final (solved, _) = _run(save, 'twin_beacons', referenceSolution('world_03', 'twin_beacons'));
      expect(solved['twin_beacons']!.completed, isTrue);
    });

    test('hints never stand in the way of completion', () {
      final (save, outcome) = recordRun(
          PlayerSave.fresh, _campaign, _puzzle('smallest_cart'), lengthGraph(), suite(ResultKind.correct, hintsUsed: 3));
      expect(save['smallest_cart']!.completed, isTrue);
      expect(save['smallest_cart']!.best!.hintsUsed, 3);
      expect(outcome.firstCompletion, isTrue);
    });
  });

  group('best results', () {
    final cart = _puzzle('smallest_cart');

    PlayerSave run(PlayerSave save, SuiteResult result, BlockGraph graph) =>
        recordRun(save, _campaign, cart, graph, result).$1;

    test('23. the first success is the best, and its program the solution', () {
      final save = run(PlayerSave.fresh, suite(ResultKind.correct, ops: 100, blocks: 30, hintsUsed: 1), lengthGraph());
      final best = save['smallest_cart']!.best!;
      expect([best.ops, best.blocks, best.hintsUsed], [100, 30, 1]);
      expect(graphText(save['smallest_cart']!.solution!), graphText(lengthGraph()));
    });

    test('24. a failed run never overwrites the best', () {
      var save = run(PlayerSave.fresh, suite(ResultKind.correct, ops: 100), lengthGraph());
      for (final kind in [ResultKind.wrongAnswer, ResultKind.operationLimit, ResultKind.runtimeError, ResultKind.invalidProgram]) {
        save = run(save, suite(kind, ops: 5, blocks: 1), lengthGraph(retId: 'broken'));
        final p = save['smallest_cart']!;
        expect(p.completed, isTrue, reason: '$kind');
        expect(p.best!.ops, 100, reason: '$kind');
        expect(p.lastRun!.result, kind);
        expect(graphText(p.solution!), graphText(lengthGraph()), reason: '$kind');
        expect(graphText(p.draft!), graphText(lengthGraph(retId: 'broken')));
      }
    });

    test('25. fewer operations replace the best and the solution', () {
      var save = run(PlayerSave.fresh, suite(ResultKind.correct, ops: 100), lengthGraph());
      final (next, outcome) =
          recordRun(save, _campaign, cart, lengthGraph(retId: 'faster'), suite(ResultKind.correct, ops: 80));
      save = next;
      expect(save['smallest_cart']!.best!.ops, 80);
      expect(graphText(save['smallest_cart']!.solution!), graphText(lengthGraph(retId: 'faster')));
      expect(outcome.improved, {BestMetric.ops});
      expect(outcome.newSolution, isTrue);
      expect(outcome.firstCompletion, isFalse);
    });

    test('26. more operations change nothing; a tie keeps the first solution', () {
      final save = run(PlayerSave.fresh, suite(ResultKind.correct, ops: 100), lengthGraph());
      for (final ops in [120, 100]) {
        final (next, outcome) =
            recordRun(save, _campaign, cart, lengthGraph(retId: 'other'), suite(ResultKind.correct, ops: ops));
        expect(next['smallest_cart']!.best!.ops, 100);
        expect(graphText(next['smallest_cart']!.solution!), graphText(lengthGraph()));
        expect(outcome.improved, isEmpty);
        expect(outcome.newSolution, isFalse);
      }
    });

    test('27. every metric keeps its own best', () {
      var save = run(PlayerSave.fresh,
          suite(ResultKind.correct, ops: 100, peakAlloc: 50, peakDepth: 1, blocks: 30, hintsUsed: 2), lengthGraph());
      final (next, outcome) = recordRun(save, _campaign, cart, lengthGraph(retId: 'small'),
          suite(ResultKind.correct, ops: 120, peakAlloc: 10, peakDepth: 1, blocks: 20, hintsUsed: 0));
      save = next;
      final best = save['smallest_cart']!.best!;
      expect(best.ops, 100);
      expect(best.peakAlloc, 10);
      expect(best.peakDepth, 1);
      expect(best.blocks, 20);
      expect(best.hintsUsed, 0);
      expect(outcome.improved, {BestMetric.peakAlloc, BestMetric.blocks, BestMetric.hintsUsed});
      expect(graphText(save['smallest_cart']!.solution!), graphText(lengthGraph()), reason: 'the fewest-operations program');
    });

    test('best results survive a restart', () {
      final save = run(PlayerSave.fresh, suite(ResultKind.correct, ops: 77, blocks: 9), lengthGraph());
      final back = reloaded(save);
      expect(back['smallest_cart']!.best!.ops, 77);
      expect(back['smallest_cart']!.completed, isTrue);
      expect(evaluateCampaign(_campaign, back).puzzleStatus('twin_beacons'), PuzzleStatus.open);
    });
  });

  group('rules on small campaigns', () {
    test('a puzzle waits for its own prerequisites, unless its world teaches them', () {
      final campaign = tinyCampaign(
        [
          ('world_a', ['arrays'], [], ['a1', 'a2']),
          ('world_b', ['queue'], ['arrays'], ['b1']),
        ],
        puzzlePrerequisites: {
          'a1': ['arrays'],
          'a2': ['queue'],
        },
      );
      var p = evaluateCampaign(campaign, PlayerSave.fresh);
      expect(p.puzzleStatus('a1'), PuzzleStatus.open, reason: 'its world teaches arrays');
      expect(p.puzzleStatus('a2'), PuzzleStatus.locked);
      expect(p.missingFor('a2'), ['queue']);
      // world_a cannot complete while a2 is locked, so queue never comes: a
      // content bug the rules make visible instead of hiding.
      p = evaluateCampaign(campaign, _solvedIn(['a1']));
      expect(p.puzzleStatus('a2'), PuzzleStatus.locked);
      expect(p.worldStatus('world_b'), WorldStatus.locked);
    });

    test('a world the player has solved a puzzle in never locks again', () {
      final before = tinyCampaign([
        ('world_a', ['arrays'], [], ['a1']),
        ('world_b', ['two_pointers'], ['arrays'], []),
        ('world_c', ['window'], ['two_pointers'], ['c1']),
      ]);
      final save = _solvedIn(['a1', 'c1']);
      expect(evaluateCampaign(before, save).worldStatus('world_c'), WorldStatus.completed);
      // An update ships a first puzzle for world_b: its concept is no longer
      // mastered, but world_c stays open because the player already played it.
      final after = tinyCampaign([
        ('world_a', ['arrays'], [], ['a1']),
        ('world_b', ['two_pointers'], ['arrays'], ['b1']),
        ('world_c', ['window'], ['two_pointers'], ['c1']),
      ]);
      final p = evaluateCampaign(after, save);
      expect(p.mastered, isNot(contains('two_pointers')));
      expect(p.worldStatus('world_c'), WorldStatus.completed);
      expect(p.puzzleStatus('b1'), PuzzleStatus.open);
    });

    test('worlds may be listed in any order; the rules settle', () {
      final campaign = tinyCampaign([
        ('world_c', ['c'], ['b'], ['c1']),
        ('world_b', ['b'], ['a'], ['b1']),
        ('world_a', ['a'], [], ['a1']),
      ]);
      final p = evaluateCampaign(campaign, _solvedIn(['a1', 'b1']));
      expect(p.worldStatus('world_c'), WorldStatus.open);
      expect(p.mastered, {'a', 'b'});
    });

    test('a different puzzle version keeps completion and the draft, not the old numbers', () {
      final campaign = tinyCampaign([('world_a', ['arrays'], [], ['a1'])]);
      final v1 = campaign.puzzles['a1']!;
      final solved = recordRun(PlayerSave.fresh, campaign, v1, lengthGraph(), suite(ResultKind.correct, ops: 5)).$1;
      final v2Campaign = Campaign(campaign.manifest, {'a1': tinyPuzzle('a1', world: 'world_a', version: 2)});
      final (opened, result) = openPuzzle(solved, v2Campaign, v2Campaign.puzzles['a1']!);
      final a1 = opened['a1']!;
      expect(result.puzzleChanged, isTrue);
      expect(a1.puzzleVersion, 2);
      expect(a1.completed, isTrue);
      expect(a1.best, isNull);
      expect(a1.solution, isNull);
      expect(a1.lastRun, isNull);
      expect(graphText(a1.draft!), graphText(lengthGraph()));
      expect(graphText(result.graph!), graphText(lengthGraph()));
      expect(evaluateCampaign(v2Campaign, opened).puzzleStatus('a1'), PuzzleStatus.completed);
    });
  });
}

PlayerSave _solvedIn(List<String> ids) => PlayerSave(puzzles: {
      for (final id in ids) id: const PuzzleProgress(puzzleVersion: 1, completed: true),
    });
