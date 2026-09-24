import 'dart:convert';

import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/progress_fixtures.dart';

/// U1: CREATE VARIABLE is gone from the editor. A puzzle's names were never
/// free: only its `variables.pool` could be created, and declaring a name
/// only tells lowering its type (no block, no step, no memory). So the
/// editor now declares the whole pool when it opens. These tests pin that
/// down: nothing about any program changes.
final _campaign = shippedCampaign();

Iterable<(String world, Puzzle puzzle)> _puzzles() sync* {
  for (final world in _campaign.manifest.worlds) {
    for (final id in world.puzzleIds) {
      yield (world.id, _campaign.puzzles[id]!);
    }
  }
}

String _ir(BlockGraph graph, Puzzle puzzle) => jsonEncode(lower(graph, puzzle).program!.toJson());

void main() {
  test('every puzzle opens with its variables and givens declared, and nothing placed', () {
    for (final (_, puzzle) in _puzzles()) {
      final c = EditorController(puzzle: puzzle);
      expect(c.graph.blocks, isEmpty, reason: puzzle.id);
      for (final v in puzzle.variablePool) {
        expect(c.graph.variables[v.name], v.type, reason: '${puzzle.id}: ${v.name}');
      }
      for (final input in puzzle.io.inputs) {
        expect(c.graph.variables[input.name], input.type, reason: '${puzzle.id}: ${input.name}');
      }
      expect(c.graph.variables.length, puzzle.variablePool.length + puzzle.io.inputs.length);
      expect(c.unusedPool, isEmpty);
      expect(c.canUndo, isFalse, reason: 'declaring is not an edit the player could undo');
    }
  });

  test('declaring a name that is already there changes nothing', () {
    final puzzle = _campaign.puzzles['warm_readings']!;
    final c = EditorController(puzzle: puzzle);
    final before = c.graph;
    c.declareVariable('count', ValueType.number);
    expect(identical(c.graph, before), isTrue);
    expect(c.canUndo, isFalse);
  });

  test('every reference solution restores into the editor and lowers and runs exactly as before', () {
    const engine = DefaultEngine();
    for (final (world, puzzle) in _puzzles()) {
      final solution = referenceSolution(world, puzzle.id);
      final c = EditorController(puzzle: puzzle, initialGraph: solution);
      expect(_ir(c.graph, puzzle), _ir(solution, puzzle), reason: '${puzzle.id}: same program');
      final before = runPuzzle(engine, solution, puzzle).suite;
      final after = runPuzzle(engine, c.graph, puzzle).suite;
      expect(after.kind, ResultKind.correct, reason: puzzle.id);
      expect(after.metrics.ops, before.metrics.ops, reason: '${puzzle.id}: same steps');
      expect(after.metrics.peakAlloc, before.metrics.peakAlloc, reason: '${puzzle.id}: same memory');
      expect(after.metrics.peakDepth, before.metrics.peakDepth, reason: '${puzzle.id}: same depth');
      expect(c.blockCount, solution.blocks.length, reason: '${puzzle.id}: same block count');
    }
  });

  test('a draft saved before U1, with only some names created, opens with the whole pool and survives a save', () {
    final puzzle = _campaign.puzzles['warm_readings']!;
    final solution = referenceSolution('world_01', 'warm_readings');
    // Before U1 a name existed only once the player created it; a draft may
    // lack the pool names it does not use yet.
    final unused = puzzle.variablePool.map((v) => v.name).where((n) => !_uses(solution, n)).toList();
    expect(unused, isNotEmpty);
    final old = solution.copyWith(variables: {
      for (final e in solution.variables.entries)
        if (!unused.contains(e.key)) e.key: e.value,
    });
    final c = EditorController(puzzle: puzzle, initialGraph: old);
    for (final v in puzzle.variablePool) {
      expect(c.graph.variables[v.name], v.type);
    }
    expect(_ir(c.graph, puzzle), _ir(solution, puzzle));

    // Save and load: what an app restart sees.
    final opened = openPuzzle(PlayerSave.fresh, _campaign, puzzle).$1;
    final saved = saveDraft(opened, _campaign, puzzle, c.graph);
    final restored = decodeSave(encodeSave(saved)).save['warm_readings']!.draft!;
    final again = EditorController(puzzle: puzzle, initialGraph: restored);
    expect(again.graph.variables, c.graph.variables);
    expect(_ir(again.graph, puzzle), _ir(solution, puzzle));
  });
}

bool _uses(BlockGraph graph, String name) =>
    graph.blocks.values.any((b) => b.literals['name'] == name);
