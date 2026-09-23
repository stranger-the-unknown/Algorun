import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// The five MS8 puzzles, run through the engine's own pipeline:
/// puzzle JSON → reference BlockGraph → validate → lower → TestRunner.
///
/// Reference files are offline content (`content/references`); they are read
/// here only to prove the shipped puzzles are solvable.
const _shipped = {
  'twin_beacons': 'world_03',
  'quota_hours': 'world_05',
  'relay_towers': 'world_06',
  'smallest_cart': 'world_02',
  'fewest_rides': 'world_10',
};

const _engine = DefaultEngine();

Puzzle _puzzle(String id) => parsePuzzleJson(
      File('../../assets/puzzles/${_shipped[id]}/$id.json').readAsStringSync(),
    );

Map<String, Object?> _reference(String id) => jsonDecode(
      File('../../content/references/${_shipped[id]}/$id.json').readAsStringSync(),
    ) as Map<String, Object?>;

BlockGraph _graph(Object? json) =>
    BlockGraph.fromJson(Map<String, dynamic>.from(json as Map));

Program _lowered(BlockGraph graph, Puzzle puzzle) {
  final report = _engine.validate(graph, puzzle);
  expect(report.ok, isTrue, reason: report.messages.map((m) => m.message).join('\n'));
  final lowered = _engine.lower(graph, puzzle);
  expect(lowered.ok, isTrue, reason: lowered.errors.map((m) => m.message).join('\n'));
  return lowered.program!;
}

/// The reject named [name] in the reference file.
BlockGraph _reject(String id, String name) {
  final rejects = _reference(id)['rejects']! as List<Object?>;
  final match = rejects.cast<Map<String, Object?>>().singleWhere((r) => r['name'] == name);
  return _graph(match['graph']);
}

void main() {
  for (final id in _shipped.keys) {
    group(id, () {
      late Puzzle puzzle;
      late BlockGraph solution;

      setUp(() {
        puzzle = _puzzle(id);
        solution = _graph(_reference(id)['solution']);
      });

      test('is a real puzzle: reference metadata, story, hints, hidden cases', () {
        expect(puzzle.reference, isNotNull);
        expect(puzzle.story.length, greaterThan(150));
        expect(puzzle.hints.length, greaterThanOrEqualTo(3));
        expect(puzzle.visibleTests.length, greaterThanOrEqualTo(2));
        expect(puzzle.hiddenTests.length, greaterThan(puzzle.visibleTests.length));
        expect(puzzle.tier.index + 1, inInclusiveRange(2, 3));
      });

      test('reference: JSON → BlockGraph → validate → lower → TestRunner', () {
        expect(solution.blockCount, lessThanOrEqualTo(puzzle.blocks.maxBlocks!));
        for (final block in solution.blocks.values) {
          expect(puzzle.blocks.allows(block.catalogId), isTrue, reason: block.catalogId);
        }
        final suite = _engine.runTests(_lowered(solution, puzzle), puzzle);
        expect(suite.kind, ResultKind.correct, reason: suite.message);
        expect(suite.visible.every((c) => c.ok), isTrue);
        expect(suite.hiddenSummary!.passed, puzzle.hiddenTests.length);
        expect(suite.metrics.ops, lessThanOrEqualTo(puzzle.limits.maxOps));
        expect(suite.metrics.peakAlloc, lessThanOrEqualTo(puzzle.limits.maxAlloc));
        // Headroom: a reasonable variation of the intended approach still fits.
        expect(suite.metrics.ops, lessThan(puzzle.limits.maxOps * 0.6));
      });

      test('reference survives a JSON round trip unchanged', () {
        final again = BlockGraph.fromJsonString(solution.toJsonString());
        final a = _engine.runTests(_lowered(solution, puzzle), puzzle);
        final b = _engine.runTests(_lowered(again, puzzle), puzzle);
        expect(b.kind, a.kind);
        expect(b.metrics.ops, a.metrics.ops);
      });
    });
  }

  group('what each puzzle turns away', () {
    test('twin_beacons: comparing every pair is correct but over budget', () {
      final puzzle = _puzzle('twin_beacons');
      final program = _lowered(_reject('twin_beacons', 'compare every pair'), puzzle);
      final visible = const TestRunner().runCases(program, puzzle, puzzle.visibleTests);
      expect(visible.kind, ResultKind.correct, reason: 'correct on what the player can see');
      final suite = _engine.runTests(program, puzzle);
      expect(suite.kind, ResultKind.operationLimit);
      expect(suite.message, 'This program took too many steps.');
      // Given unlimited steps it would still be right — it is only too slow.
      final big = puzzle.hiddenTests.last;
      final unlimited = runProgram(program, big.input, const RunLimits(maxOps: 50000000));
      expect(unlimited.kind, ResultKind.correct);
      expect(valuesEqual(unlimited.output!, big.output), isTrue);
      expect(unlimited.metrics.ops, greaterThan(puzzle.limits.maxOps * 100));
    });

    test('twin_beacons: adding before asking pairs a beacon with itself', () {
      final puzzle = _puzzle('twin_beacons');
      final suite = _engine.runTests(_lowered(_reject('twin_beacons', 'add before asking'), puzzle), puzzle);
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible.every((c) => c.ok), isTrue, reason: 'the trap is only in hidden cases');
      expect(suite.firstFailureCaseId, isNull);
    });

    test('quota_hours: trying every run is over budget; the placeholder is wrong', () {
      final puzzle = _puzzle('quota_hours');
      expect(
        _engine.runTests(_lowered(_reject('quota_hours', 'try every run'), puzzle), puzzle).kind,
        ResultKind.operationLimit,
      );
      expect(
        _engine
            .runTests(_lowered(_reject('quota_hours', 'report the placeholder when nothing fits'), puzzle), puzzle)
            .kind,
        ResultKind.wrongAnswer,
      );
    });

    test('relay_towers: looking east is over budget; equal is not taller', () {
      final puzzle = _puzzle('relay_towers');
      expect(
        _engine.runTests(_lowered(_reject('relay_towers', 'look east from every tower'), puzzle), puzzle).kind,
        ResultKind.operationLimit,
      );
      expect(
        _engine.runTests(_lowered(_reject('relay_towers', 'treat equal as taller'), puzzle), puzzle).kind,
        ResultKind.wrongAnswer,
      );
    });

    test('smallest_cart: one unit at a time is over budget', () {
      final puzzle = _puzzle('smallest_cart');
      final program = _lowered(_reject('smallest_cart', 'raise the capacity one unit at a time'), puzzle);
      expect(_engine.runTests(program, puzzle).kind, ResultKind.operationLimit);
    });

    test('smallest_cart: the midpoint needs FLOOR DIVIDE, not DIVIDE', () {
      final puzzle = _puzzle('smallest_cart');
      final solution = _graph(_reference('smallest_cart')['solution']);
      expect(
        solution.blocks.values.where((b) => b.catalogId == BlockIds.arithFloorDiv),
        hasLength(1),
      );
      // Same program with DIVIDE in the midpoint.
      final divide = solution.copyWith(blocks: {
        for (final entry in solution.blocks.entries)
          entry.key: entry.value.catalogId == BlockIds.arithFloorDiv
              ? BlockInstance(
                  id: entry.value.id,
                  catalogId: BlockIds.arithDiv,
                  slots: entry.value.slots,
                )
              : entry.value,
      });
      final suite = _engine.runTests(_lowered(divide, puzzle), puzzle);
      expect(suite.kind, isNot(ResultKind.correct));
    });

    test('fewest_rides: a stack explores deep first and reports a longer route', () {
      final puzzle = _puzzle('fewest_rides');
      final suite = _engine.runTests(_lowered(_reject('fewest_rides', 'depth-first with a stack'), puzzle), puzzle);
      expect(suite.kind, ResultKind.wrongAnswer);
    });
  });

  group('structured fixtures in the shipped set', () {
    test('fewest_rides reads real graphs, with loops and split cities', () {
      final puzzle = _puzzle('fewest_rides');
      final graphs = [for (final c in puzzle.allTests) c.input['metro'] as GraphValue];
      expect(graphs, isNotEmpty);
      expect(graphs.map((g) => g.adjacency.length).reduce((a, b) => a > b ? a : b), 500);
      final outputs = [for (final c in puzzle.allTests) (c.output as NumValue).value];
      expect(outputs, contains(-1), reason: 'an unreachable goal');
      expect(outputs, contains(0), reason: 'start equals goal');
    });

    test('budget cases are large enough to separate the approaches', () {
      for (final id in ['twin_beacons', 'quota_hours', 'relay_towers']) {
        final puzzle = _puzzle(id);
        final largest = puzzle.hiddenTests
            .map((c) => (c.input.values.whereType<ArrayValue>().first).elements.length)
            .reduce((a, b) => a > b ? a : b);
        expect(largest, puzzle.constraints.nMax, reason: id);
      }
    });
  });
}
