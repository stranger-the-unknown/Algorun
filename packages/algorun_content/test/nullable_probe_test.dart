import 'dart:convert';
import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// L1 end to end: the two probes are built the way a player builds them
/// (every drop through GraphTyping), lowered, and run on their fixtures.

const _mayBeEmpty = 'This value may be empty here. Check that it is not empty first.';

Puzzle _puzzle(String id) =>
    parsePuzzleJson(File('../../assets/puzzles/world_01/$id.json').readAsStringSync());

String _referenceSource(String id) =>
    File('../../content/references/world_01/$id.json').readAsStringSync();

Map<String, Object?> _reference(String id) =>
    jsonDecode(_referenceSource(id)) as Map<String, Object?>;

BlockGraph _solution(Map<String, Object?> reference) =>
    BlockGraph.fromJson(reference['solution']! as Map<String, Object?>);

/// [reference] with block [blockId] switched to [catalogId].
Map<String, Object?> _swap(Map<String, Object?> reference, String blockId, String catalogId) {
  final copy = jsonDecode(jsonEncode(reference)) as Map<String, Object?>;
  final blocks = (copy['solution']! as Map<String, Object?>)['blocks']! as Map<String, Object?>;
  (blocks[blockId]! as Map<String, Object?>)['catalogId'] = catalogId;
  return copy;
}

void main() {
  for (final id in ['l1_list_probe', 'l1_tree_probe']) {
    group(id, () {
      test('a player can build the reference, and it solves every case', () {
        final puzzle = _puzzle(id);
        final graph = _solution(_reference(id));
        expect(replayInEditor(graph, puzzle).map((i) => '${i.path}: ${i.message}'), isEmpty);
        expect(const DefaultEngine().validate(graph, puzzle).ok, isTrue);
        final lowered = lower(graph, puzzle);
        expect(lowered.ok, isTrue, reason: '${lowered.errors.map((e) => e.message)}');
        final suite = const TestRunner().run(lowered.program!, puzzle);
        expect(suite.kind, ResultKind.correct, reason: suite.message);
        expect(suite.visible.every((c) => c.run.kind == ResultKind.correct), isTrue);
        expect(suite.hiddenSummary!.allPassed, isTrue);
      });

      test('the reference checker passes it with its recorded cost', () {
        final issues = <ContentIssue>[];
        const ReferenceChecker().check(_puzzle(id), _referenceSource(id), 'world_01/$id.json', issues);
        expect(issues.where((i) => i.severity != Severity.info), isEmpty, reason: issues.join('\n'));
      });

      test('it is a probe: no world lists it', () {
        final worlds = readWorldsJson(File('../../assets/worlds.json').readAsStringSync()).manifest!;
        expect(worlds.worlds.expand((w) => w.puzzleIds), isNot(contains(id)));
      });
    });
  }

  test('the chain probe walks an empty chain and a long one', () {
    final puzzle = _puzzle('l1_list_probe');
    final program = lower(_solution(_reference('l1_list_probe')), puzzle).program!;
    final cases = puzzle.allTests;
    final byId = {for (final c in cases) c.id: c};
    expect(byId['empty_chain']!.input['head'], isA<NilValue>());
    final suite = const TestRunner().runCases(program, puzzle, cases);
    expect(suite.kind, ResultKind.correct);
    // 9 + 10 operations per link; the ten-link case is the most expensive.
    expect(suite.metrics.ops, 109);
  });

  test('a loop that checks the wrong way cannot step to the next link', () {
    // WHILE node IS NOTHING { … NEXT NODE node … }: node may be empty there.
    final unsafe = _swap(_reference('l1_list_probe'), 'check_6', BlockIds.logicIsNothing);
    final puzzle = _puzzle('l1_list_probe');
    final graph = _solution(unsafe);
    final replay = replayInEditor(graph, puzzle);
    expect(replay, hasLength(1));
    expect(replay.single.path, 'blocks.get_node_11');
    expect(replay.single.message, _mayBeEmpty);
    final lowered = lower(graph, puzzle);
    expect(lowered.ok, isFalse);
    expect(lowered.errors.map((e) => e.message), contains(_mayBeEmpty));
  });

  test('reading the branch in the wrong arm is refused, and the checker says so', () {
    // IF child IS NOT NOTHING { RETURN 0 } ELSE { RETURN NODE VALUE child }.
    final unsafe = _swap(_reference('l1_tree_probe'), 'check_5', BlockIds.logicIsNotNothing);
    final puzzle = _puzzle('l1_tree_probe');
    final replay = replayInEditor(_solution(unsafe), puzzle);
    expect(replay.single.path, 'blocks.get_child_8');
    expect(replay.single.message, _mayBeEmpty);

    final issues = <ContentIssue>[];
    const ReferenceChecker().check(puzzle, jsonEncode(unsafe), 'world_01/l1_tree_probe.json', issues);
    expect(issues.where((i) => i.severity == Severity.error).map((i) => i.message), contains(_mayBeEmpty));
  });
}
