import 'dart:convert';
import 'dart:io';

import 'package:algorun/puzzles/asset_repository.dart';
import 'package:algorun/state/hint_session.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _real = {
  'world_02': 'smallest_cart',
  'world_03': 'twin_beacons',
  'world_05': 'quota_hours',
  'world_06': 'relay_towers',
  'world_10': 'fewest_rides',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HintSession', () {
    test('a puzzle with no hints has nothing to reveal', () {
      final session = HintSession(const []);
      expect(session.total, 0);
      expect(session.used, 0);
      expect(session.hasMore, isFalse);
      expect(session.revealed, isEmpty);
      expect(session.revealNext(), isNull);
      expect(session.used, 0);
    });

    test('three hints come out one at a time, in order', () {
      final session = HintSession(const ['idea', 'approach', 'nearly there']);
      expect(session.total, 3);
      expect(session.revealed, isEmpty, reason: 'nothing is shown up front');

      expect(session.revealNext(), 'idea');
      expect(session.used, 1);
      expect(session.revealed, ['idea']);

      expect(session.revealNext(), 'approach');
      expect(session.used, 2);
      expect(session.revealed, ['idea', 'approach']);

      expect(session.revealNext(), 'nearly there');
      expect(session.used, 3);
      expect(session.hasMore, isFalse);
    });

    test('asking past the last hint changes nothing', () {
      final session = HintSession(const ['a', 'b', 'c']);
      for (var i = 0; i < 3; i++) {
        session.revealNext();
      }
      expect(session.revealNext(), isNull);
      expect(session.revealNext(), isNull);
      expect(session.used, 3);
      expect(session.revealed, ['a', 'b', 'c']);
    });

    test('looking at revealed hints never counts', () {
      final session = HintSession(const ['a', 'b', 'c'])..revealNext();
      for (var i = 0; i < 10; i++) {
        expect(session.revealed, ['a']);
      }
      expect(session.used, 1);
    });

    test('the hint list cannot be changed from outside', () {
      final source = ['a', 'b'];
      final session = HintSession(source);
      source.add('c');
      expect(session.total, 2);
      expect(() => session.hints.add('d'), throwsUnsupportedError);
    });
  });

  group('the five real puzzles', () {
    test('each exposes its three authored hints, in order', () async {
      const repo = AssetPuzzleRepository();
      for (final MapEntry(key: world, value: id) in _real.entries) {
        final puzzle = await repo.loadPuzzle(world, id);
        expect(puzzle.hints, hasLength(3), reason: id);
        final session = HintSession(puzzle.hints);
        final shown = [for (var i = 0; i < 3; i++) session.revealNext()];
        expect(shown, puzzle.hints, reason: id);
        expect(session.hasMore, isFalse, reason: id);
      }
    });

    test('no hint leaks an internal block id, a hidden case, or the reference', () async {
      const repo = AssetPuzzleRepository();
      for (final MapEntry(key: world, value: id) in _real.entries) {
        final puzzle = await repo.loadPuzzle(world, id);
        for (final hint in puzzle.hints) {
          for (final block in BlockIds.all) {
            expect(hint, isNot(contains(block)), reason: '$id mentions $block');
          }
          for (final hidden in puzzle.hiddenTests) {
            expect(hint, isNot(contains(hidden.id)), reason: '$id mentions ${hidden.id}');
          }
          expect(hint.toLowerCase(), isNot(contains('reference')), reason: id);
        }
      }
    });
  });

  group('hintsUsed reaches the result', () {
    test('an unfinished program still carries the count', () async {
      final puzzle = await const AssetPuzzleRepository().loadPuzzle('world_03', 'twin_beacons');
      final outcome = runPuzzle(
        const DefaultEngine(),
        BlockGraph(blocks: const {}, variables: const {}),
        puzzle,
        hintsUsed: 2,
      );
      expect(outcome.suite.kind, ResultKind.invalidProgram);
      expect(outcome.suite.metrics.hintsUsed, 2);
    });

    test('a solved puzzle carries the count, and grading ignores it', () async {
      final puzzle = await const AssetPuzzleRepository().loadPuzzle('world_05', 'quota_hours');
      final reference = jsonDecode(
        File('content/references/world_05/quota_hours.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final solution = BlockGraph.fromJson(Map<String, dynamic>.from(reference['solution']! as Map));
      final plain = runPuzzle(const DefaultEngine(), solution, puzzle);
      final hinted = runPuzzle(const DefaultEngine(), solution, puzzle, hintsUsed: 3);
      expect(plain.suite.metrics.hintsUsed, 0);
      expect(hinted.suite.metrics.hintsUsed, 3);
      expect(hinted.suite.kind, ResultKind.correct);
      expect(hinted.suite.kind, plain.suite.kind);
      expect(hinted.suite.metrics.ops, plain.suite.metrics.ops);
      expect(hinted.suite.hiddenSummary!.passed, plain.suite.hiddenSummary!.passed);
    });
  });
}
