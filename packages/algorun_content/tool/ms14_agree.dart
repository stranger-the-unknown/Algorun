import 'dart:math';

import 'package:algorun_content/src/oracles/batch2.dart';
import 'package:algorun_engine/algorun_engine.dart';

import 'ms14_build.dart';

void main() {
  final engine = DefaultEngine();
  var bad = 0;
  for (final entry in ms14Builders.entries) {
    final id = entry.key;
    final built = entry.value();
    final oracle = batch2Oracles[id]!;
    final sample = oracle.sample(Random(1));
    final answer = oracle.solve(sample);
    final puzzle = _puzzle(id, built.solution, sample, answer);
    final lowered = engine.lower(built.solution, puzzle);
    if (!lowered.ok) {
      bad++;
      print('LOWER $id ${lowered.errors.map((e) => e.message).join(' | ')}');
      continue;
    }
    var mismatches = 0;
    String? first;
    for (var s = 0; s < 12; s++) {
      final raw = oracle.sample(Random(1000 + s));
      final expected = oracle.solve(raw);
      final input = {
        for (final e in raw.entries) e.key: valueFromJson(e.value, type: puzzle.io.inputs.firstWhere((b) => b.name == e.key).type),
      };
      final run = runProgram(
        lowered.program!,
        input,
        const RunLimits(maxOps: 2000000, maxDepth: 64, maxAlloc: 200000),
      );
      final want = valueFromJson(expected, type: puzzle.io.output);
      final got = run.output ?? const NilValue();
      if (run.kind != ResultKind.correct || !valuesEqual(got, want)) {
        mismatches++;
        first ??= 'sample $s kind ${run.kind.name} ${run.message} got ${valueToJson(got)} want ${valueToJson(want)} in $raw';
      }
    }
    final rejects = built.rejects.length;
    if (mismatches != 0) {
      bad++;
      print('DIFF $id $mismatches/12 rejects $rejects :: $first');
    } else {
      print('OK $id rejects $rejects');
    }
  }
  print(bad == 0 ? 'all agree' : '$bad disagree');
}

Puzzle _puzzle(String id, BlockGraph graph, Map<String, Object?> sample, Object? answer) {
  final inputs = [
    for (final e in sample.entries) IoBinding(name: e.key, type: _type(e.key, e.value)),
  ];
  return Puzzle(
    id: id,
    title: id,
    world: 'world_02',
    mode: PuzzleMode.build,
    tier: PuzzleTier.t2,
    story: 'probe',
    io: IoSpec(inputs: inputs, output: answer is bool ? ValueType.boolean : ValueType.number),
    blocks: BlockPolicy(allow: {for (final b in graph.blocks.values) b.catalogId}),
    limits: const PerformanceTarget(maxOps: 2000000, maxDepth: 64, maxAlloc: 200000),
    visibleTests: const [],
    hiddenTests: const [],
    outputValidator: ValidatorId.equal,
    variablePool: [
      for (final e in graph.variables.entries)
        if (!sample.containsKey(e.key)) IoBinding(name: e.key, type: e.value),
    ],
  );
}

ValueType _type(String name, Object? value) {
  if (value is Map && value['type'] == 'listNode') return ValueType.listNode.asNullable;
  if (value == null && name == 'head') return ValueType.listNode.asNullable;
  if (value == null && name == 'root') return ValueType.treeNode.asNullable;
  if (value is Map && value['type'] == 'treeNode') return ValueType.treeNode.asNullable;
  if (value is Map && value['type'] == 'graph') return ValueType.graph;
  if (value is bool) return ValueType.boolean;
  if (value is num) return ValueType.number;
  if (value is List) {
    if (value.isNotEmpty && value.first is List) return ValueType.array(ValueType.array(ValueType.number));
    return ValueType.array(ValueType.number);
  }
  throw StateError('no type for $name $value');
}
