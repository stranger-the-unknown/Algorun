import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:algorun_content/src/oracles/batch2.dart';
import 'package:algorun_content/src/oracles/oracle.dart';
import 'package:algorun_engine/algorun_engine.dart';

import 'ms14_build.dart';
import 'ms14_catalog.dart';

/// Builds puzzle JSON, reference JSON, worlds.json entries and Turkish copy
/// for the MS14 batch. Run from the repository root:
/// `dart run packages/algorun_content/tool/ms14_emit.dart`
void main() {
  final root = Directory.current.path.endsWith('algorun_content')
      ? Directory.current.parent.parent
      : Directory.current;
  final engine = DefaultEngine();
  final failures = <String>[];
  final byWorld = <String, List<String>>{};

  if (ms14Specs.length != ms14Builders.length) {
    stderr.writeln('spec ${ms14Specs.length} builders ${ms14Builders.length}');
    exit(1);
  }

  for (final spec in ms14Specs) {
    final built = ms14Builders[spec.id]!();
    final oracle = batch2Oracles[spec.id]!;
    final pool = _pool(spec.id, oracle);
    final types = _types(pool);
    final output = _outputType(oracle, pool);
    final allow = {
      for (final g in [built.solution, ...built.rejects.map((r) => r.graph)])
        for (final b in g.blocks.values) b.catalogId,
    };
    final puzzle0 = _shell(spec, types, output, allow, const [], const [], 1000000, 100000, maxBlocks: 500);
    final solution = engine.lower(built.solution, puzzle0);
    if (!solution.ok) {
      failures.add('${spec.id} solution will not lower: ${solution.errors.map((e) => e.message).join(' | ')}');
      continue;
    }
    final programs = <Reject, Program>{};
    var lowerOk = true;
    for (final reject in built.rejects) {
      final lowered = engine.lower(reject.graph, puzzle0);
      if (!lowered.ok) {
        failures.add('${spec.id} reject "${reject.name}" will not lower: ${lowered.errors.map((e) => e.message).join(' | ')}');
        lowerOk = false;
        break;
      }
      programs[reject] = lowered.program!;
    }
    if (!lowerOk) continue;
    final reject = built.rejects.single;
    final rejectProgram = programs[reject]!;

    final judged = <_Case>[];
    for (final raw in pool) {
      final input = {
        for (final e in raw.entries) e.key: valueFromJson(e.value, type: types[e.key]!),
      };
      final want = valueFromJson(oracle.solve(raw), type: output);
      final good = runProgram(solution.program!, input, const RunLimits(maxOps: 5000000, maxDepth: 64, maxAlloc: 500000));
      final bad = runProgram(rejectProgram, input, const RunLimits(maxOps: 5000000, maxDepth: 64, maxAlloc: 500000));
      final got = good.output ?? const NilValue();
      if (good.kind != ResultKind.correct || !valuesEqual(got, want)) {
        continue;
      }
      final badOut = bad.output ?? const NilValue();
      judged.add(_Case(raw, good.metrics.ops, good.metrics.peakAlloc, bad.metrics.ops, bad.metrics.peakAlloc, bad.kind == ResultKind.correct && valuesEqual(badOut, want)));
    }
    if (judged.length < 4) {
      failures.add('${spec.id} only ${judged.length} inputs agree with the oracle');
      continue;
    }

    final probe = _probeSamples(spec.id, oracle, solution.program!, types, output);
    if (probe == null) {
      failures.add('${spec.id} reference disagrees with the oracle on a sample');
      continue;
    }

    final picked = _pick(spec, reject.expect, judged, probe.ops);
    if (picked == null) {
      var best = 0.0;
      for (final c in judged) {
        final ratio = c.ops == 0 ? c.rejectOps.toDouble() : c.rejectOps / c.ops;
        if (ratio > best) best = ratio;
      }
      failures.add('${spec.id} could not separate visible cases from a ${reject.expect} trap '
          '(agree ${judged.where((c) => c.rejectAgrees).length}/${judged.length}, '
          'best reject/solution ${best.toStringAsFixed(2)}x, sample ops ${probe.ops})');
      continue;
    }
    if (probe.alloc > picked.maxAlloc) {
      failures.add('${spec.id} sample alloc ${probe.alloc} over cap ${picked.maxAlloc}');
      continue;
    }

    final blockCount = built.solution.blocks.length;
    final maxBlocks = max(blockCount, built.rejects.map((r) => r.graph.blocks.length).reduce(max)) + 12;
    final puzzle = _shell(spec, types, output, allow, picked.visible, picked.hidden, picked.maxOps, picked.maxAlloc, maxBlocks: maxBlocks);
    final suite = engine.runTests(solution.program!, puzzle);
    if (!suite.ok) {
      failures.add('${spec.id} reference fails the suite: ${suite.kind.name} ${suite.message}');
      continue;
    }
    final visibleRun = const TestRunner().runCases(rejectProgram, puzzle, puzzle.visibleTests);
    if (!visibleRun.ok) {
      failures.add('${spec.id} reject fails a visible case: ${visibleRun.kind.name} ${visibleRun.message}');
      continue;
    }
    final rejectSuite = engine.runTests(rejectProgram, puzzle);
    if (rejectSuite.kind.name != reject.expect) {
      failures.add('${spec.id} reject suite ${rejectSuite.kind.name}, wanted ${reject.expect}');
      continue;
    }
    if (spec.baseline != null) {
      final factor = spec.baseline!;
      var best = 0.0;
      for (final testCase in puzzle.allTests) {
        final budget = puzzle.opsBudgetFor(testCase);
        final run = runProgram(
          rejectProgram,
          testCase.input,
          RunLimits(maxOps: budget * factor, maxDepth: 64, maxAlloc: picked.maxAlloc),
        );
        final ratio = run.metrics.ops / budget;
        if (ratio > best) best = ratio;
      }
      if (best < factor) {
        failures.add('${spec.id} baseline ${best.toStringAsFixed(1)}x < $factor');
        continue;
      }
    }

    _writePuzzle(root, spec, puzzle, picked);
    _writeReference(root, spec, built, suite.metrics);
    byWorld.putIfAbsent(spec.world, () => []).add(spec.id);
    stdout.writeln('${spec.id} ops ${suite.metrics.ops}/${picked.maxOps} alloc ${suite.metrics.peakAlloc}/${picked.maxAlloc} '
        'blocks $blockCount vis ${picked.visible.length} hid ${picked.hidden.length}');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('${failures.length} failed');
    for (final f in failures) {
      stderr.writeln('  $f');
    }
    exit(1);
  }
  _patchWorlds(root, byWorld);
  _patchTurkish(root);
  stdout.writeln('wrote ${ms14Specs.length} puzzles');
}

final class _Case {
  _Case(this.raw, this.ops, this.alloc, this.rejectOps, this.rejectAlloc, this.rejectAgrees);
  final Map<String, Object?> raw;
  final int ops;
  final int alloc;
  final int rejectOps;
  final int rejectAlloc;
  final bool rejectAgrees;
}

final class _Picked {
  _Picked(this.visible, this.hidden, this.maxOps, this.maxAlloc);
  final List<Map<String, Object?>> visible;
  final List<Map<String, Object?>> hidden;
  final int maxOps;
  final int maxAlloc;
}

_Picked? _pick(Spec spec, String expect, List<_Case> judged, int sampleOps) {
  final agrees = judged.where((c) => c.rejectAgrees).toList()
    ..sort((a, b) => a.ops.compareTo(b.ops));
  final disagrees = judged.where((c) => !c.rejectAgrees).toList();
  if (agrees.length < 2) return null;

  if (expect == 'wrongAnswer') {
    if (disagrees.isEmpty) return null;
    final visible = (agrees.toList()..sort((a, b) => a.rejectOps.compareTo(b.rejectOps))).take(2).toList();
    final hidden = <_Case>[];
    final seen = visible.map((c) => jsonEncode(c.raw)).toSet();
    final ordered = [
      ...disagrees.toList()..sort((a, b) => a.rejectOps.compareTo(b.rejectOps)),
      ...agrees.where((c) => !visible.contains(c)).toList()..sort((a, b) => a.rejectOps.compareTo(b.rejectOps)),
    ];
    final floorOps = [sampleOps, ...judged.map((c) => c.ops)].reduce(max);
    for (final c in ordered) {
      if (c.rejectOps >= 5000000) continue;
      final key = jsonEncode(c.raw);
      if (!seen.add(key)) continue;
      final trial = [...visible, ...hidden, c];
      final budget = _opsBudget([floorOps, ...trial.map((x) => x.ops)].reduce(max));
      if (trial.any((x) => x.rejectOps >= budget)) continue;
      hidden.add(c);
      if (hidden.length == 6) break;
    }
    if (!hidden.any((c) => !c.rejectAgrees)) return null;
    final ops = [floorOps, ...visible.map((c) => c.ops), ...hidden.map((c) => c.ops)].reduce(max);
    return _Picked(visible.map((c) => c.raw).toList(), hidden.map((c) => c.raw).toList(), _opsBudget(ops), 100000);
  }

  if (expect == 'operationLimit') {
    final heavy = agrees.where((c) => c.rejectOps > _opsBudget(c.ops)).toList()
      ..sort((a, b) => b.rejectOps.compareTo(a.rejectOps));
    _Case? slowCase;
    for (final c in heavy) {
      final needed = _opsBudget(max(c.ops, sampleOps));
      final factor = spec.baseline ?? 1;
      if (c.rejectOps > needed && (spec.baseline == null || c.rejectOps >= needed * factor)) {
        slowCase = c;
        break;
      }
    }
    if (slowCase == null) return null;
    final light = agrees.where((c) => c != slowCase && c.rejectOps <= _opsBudget(c.ops)).toList()
      ..sort((a, b) => a.ops.compareTo(b.ops));
    if (light.length < 2) return null;
    final visibleCases = light.take(2).toList();
    final hiddenCases = <_Case>[slowCase];
    for (final c in [...heavy.where((c) => c != slowCase), ...light.skip(2)]) {
      if (hiddenCases.length == 5) break;
      if (c.ops > slowCase.ops) continue;
      if (visibleCases.contains(c) || hiddenCases.contains(c)) continue;
      hiddenCases.add(c);
    }
    final solOps = [sampleOps, slowCase.ops, ...visibleCases.map((c) => c.ops)].reduce(max);
    var budget = _opsBudget(solOps);
    final slow = slowCase.rejectOps;
    if (visibleCases.any((c) => c.rejectOps >= budget)) return null;
    if (slow <= budget) return null;
    if (spec.baseline != null && slow < budget * spec.baseline!) return null;
    return _Picked(visibleCases.map((c) => c.raw).toList(), hiddenCases.map((c) => c.raw).toList(), budget, 200000);
  }

  if (expect == 'memoryLimit') {
    final byAlloc = agrees.toList()..sort((a, b) => a.rejectAlloc.compareTo(b.rejectAlloc));
    if (byAlloc.last.rejectAlloc <= byAlloc.first.rejectAlloc) return null;
    final visibleCases = byAlloc.take(2).toList();
    final cap = visibleCases.map((c) => c.rejectAlloc).reduce(max);
    final hiddenCases = byAlloc.where((c) => c.rejectAlloc > cap).toList();
    if (hiddenCases.isEmpty) return null;
    final solAlloc = [...visibleCases, ...hiddenCases.take(4)].map((c) => c.alloc).reduce(max);
    if (solAlloc > cap) return null;
    final ops = [sampleOps, ...visibleCases.map((c) => c.ops), ...hiddenCases.take(4).map((c) => c.ops)].reduce(max);
    return _Picked(
      visibleCases.map((c) => c.raw).toList(),
      hiddenCases.take(4).map((c) => c.raw).toList(),
      _opsBudget(ops),
      cap,
    );
  }
  return null;
}

int _opsBudget(int used) {
  final budget = (used / 0.7).ceil();
  return budget < used + 20 ? used + 20 : budget;
}

/// Max operation and allocation cost of the reference on the same sample
/// stream the validator will replay. Null when a sample disagrees.
({int ops, int alloc})? _probeSamples(
  String id,
  Oracle oracle,
  Program program,
  Map<String, ValueType> types,
  ValueType output,
) {
  var seed = 17;
  for (final unit in id.codeUnits) {
    seed = (seed * 31 + unit) & 0x3fffffff;
  }
  final random = Random(seed);
  var ops = 0;
  var alloc = 0;
  for (var i = 0; i < oracle.samples; i++) {
    final raw = oracle.sample(random);
    final Map<String, RuntimeValue> input;
    try {
      input = {for (final e in types.entries) e.key: valueFromJson(raw[e.key], type: e.value)};
    } on Object {
      return null;
    }
    final want = valueFromJson(oracle.solve(raw), type: output);
    final run = runProgram(program, input, const RunLimits(maxOps: 5000000, maxDepth: 64, maxAlloc: 500000));
    final got = run.output ?? const NilValue();
    if (run.kind != ResultKind.correct || !valuesEqual(got, want)) return null;
    if (run.metrics.ops > ops) ops = run.metrics.ops;
    if (run.metrics.peakAlloc > alloc) alloc = run.metrics.peakAlloc;
  }
  return (ops: ops, alloc: alloc);
}

List<Map<String, Object?>> _pool(String id, Oracle oracle) {
  final out = <Map<String, Object?>>[];
  final seen = <String>{};
  void add(Map<String, Object?> raw) {
    if (seen.add(jsonEncode(raw))) out.add(raw);
  }

  for (final raw in _edges[id] ?? const []) {
    add(raw);
  }
  for (var s = 0; s < 24; s++) {
    add(oracle.sample(Random(s * 17 + id.hashCode.abs() + 3)));
  }
  if (out.isNotEmpty) {
    final grown = _grow(id, out.first);
    for (final raw in grown) {
      add(raw);
    }
  }
  return out;
}

List<Map<String, Object?>> _grow(String id, Map<String, Object?> sample) {
  List<int> seq(int n, int Function(int) f) => [for (var i = 0; i < n; i++) f(i)];
  if (id == 'peak_windows') {
    return [
      {'values': seq(72, (i) => i % 7), 'width': 24},
    ];
  }
  if (id == 'source_radius' || id == 'last_layer') {
    return [
      {'roads': _undirectedPath(12), 'start': 0},
    ];
  }
  if (id == 'ticket_minutes') {
    return [
      {'tickets': seq(25, (i) => 8), 'person': 24},
    ];
  }
  if (sample.containsKey('values') && sample['values'] is List && (sample['values'] as List).every((v) => v is num)) {
    if (sample.length == 1) {
      return [
        {'values': seq(50, (i) => i % 5)},
        {'values': seq(40, (i) => (i.isEven ? 1 : -2))},
      ];
    }
    if (sample.containsKey('width')) {
      return [
        {'values': seq(64, (i) => (i * 3) % 11), 'width': 16, if (sample.containsKey('goal')) 'goal': 8},
      ];
    }
    if (sample.containsKey('target')) {
      return [
        {'values': seq(80, (i) => i % 6), 'target': 5},
      ];
    }
    if (sample.containsKey('gap')) {
      return [
        {'values': seq(24, (i) => i * 2), 'gap': 4},
      ];
    }
    if (sample.containsKey('limit')) {
      return [
        {'values': seq(24, (i) => i), 'limit': 20},
      ];
    }
  }
  if (sample.containsKey('tickets') && sample.containsKey('person')) {
    return [
      {'tickets': seq(30, (i) => (i % 4) + 1), 'person': 7},
    ];
  }
  if (sample.containsKey('weights') && sample.containsKey('cap')) {
    return [
      {
        'weights': seq(12, (i) => (i % 4) + 1),
        'values': seq(12, (i) => (i * 3) % 6),
        'cap': 14,
      },
    ];
  }
  if (sample.containsKey('roads') && !sample.containsKey('start') && id == 'biggest_patch') {
    return [_twoPatches()];
  }
  if (sample.containsKey('grid')) {
    return [
      {
        'grid': [
          [1, 9, 1],
          [1, 9, 1],
          [1, 1, 1],
        ],
      },
    ];
  }
  return const [];
}

Map<String, Object?> _twoPatches() => {
      'roads': {
        'type': 'graph',
        'nodes': [
          {'id': 0, 'neighbors': [1]},
          {'id': 1, 'neighbors': [0]},
          {'id': 2, 'neighbors': <int>[]},
        ],
      },
    };

Map<String, ValueType> _types(List<Map<String, Object?>> pool) {
  final types = <String, ValueType>{};
  for (final raw in pool) {
    for (final e in raw.entries) {
      types.putIfAbsent(e.key, () => _typeOf(e.key, e.value));
      if (e.value == null && (e.key == 'head' || e.key == 'root')) {
        types[e.key] = _typeOf(e.key, null);
      }
    }
  }
  return types;
}

ValueType _outputType(Oracle oracle, List<Map<String, Object?>> pool) {
  for (final raw in pool.take(8)) {
    if (oracle.solve(raw) is bool) return ValueType.boolean;
  }
  return ValueType.number;
}

ValueType _typeOf(String name, Object? value) {
  if (name == 'head') return ValueType.listNode.asNullable;
  if (name == 'root') return ValueType.treeNode.asNullable;
  if (value is Map && value['type'] == 'graph') return ValueType.graph;
  if (value is Map && value['type'] == 'listNode') return ValueType.listNode.asNullable;
  if (value is Map && value['type'] == 'treeNode') return ValueType.treeNode.asNullable;
  if (value is bool) return ValueType.boolean;
  if (value is num) return ValueType.number;
  if (value is List) {
    if (value.isNotEmpty && value.first is List) return ValueType.array(ValueType.array(ValueType.number));
    return ValueType.array(ValueType.number);
  }
  if (value == null) return ValueType.number;
  throw StateError('no type for $name $value');
}

Puzzle _shell(
  Spec spec,
  Map<String, ValueType> types,
  ValueType output,
  Set<String> allow,
  List<Map<String, Object?>> visible,
  List<Map<String, Object?>> hidden,
  int maxOps,
  int maxAlloc, {
  int maxBlocks = 80,
}) {
  TestCase one(String id, Map<String, Object?> raw, bool isVisible) => TestCase(
        id: id,
        visible: isVisible,
        input: {for (final e in raw.entries) e.key: valueFromJson(e.value, type: types[e.key]!)},
        output: valueFromJson(batch2Oracles[spec.id]!.solve(raw), type: output),
      );
  final inputs = [for (final e in types.entries) IoBinding(name: e.key, type: e.value)];
  return Puzzle(
    id: spec.id,
    title: spec.title,
    world: spec.world,
    chapter: spec.pattern,
    mode: PuzzleMode.values.byName(spec.mode),
    tier: PuzzleTier.values[spec.tier - 1],
    story: spec.story,
    concepts: spec.concepts,
    io: IoSpec(inputs: inputs, output: output),
    blocks: BlockPolicy(allow: allow, maxBlocks: maxBlocks),
    limits: PerformanceTarget(maxOps: maxOps, maxDepth: 64, maxAlloc: maxAlloc),
    hints: spec.hints,
    visibleTests: [for (var i = 0; i < visible.length; i++) one('v${i + 1}', visible[i], true)],
    hiddenTests: [for (var i = 0; i < hidden.length; i++) one('h${(i + 1).toString().padLeft(2, '0')}', hidden[i], false)],
    outputValidator: ValidatorId.equal,
    edgeCases: spec.traps,
    reference: PuzzleReference(strategy: spec.pattern),
    performance: PerformanceSpec(
      required: spec.performance == 'budget' || spec.performance == 'optimization',
      baselineFactor: spec.performance == 'optimization' ? spec.baseline : null,
    ),
    variablePool: const [],
  );
}

void _writePuzzle(Directory root, Spec spec, Puzzle puzzle, _Picked picked) {
  final built = ms14Builders[spec.id]!();
  final inputNames = {for (final b in puzzle.io.inputs) b.name};
  final merged = <String, ValueType>{};
  for (final graph in [built.solution, ...built.rejects.map((r) => r.graph)]) {
    for (final e in graph.variables.entries) {
      if (inputNames.contains(e.key)) continue;
      final prev = merged[e.key];
      if (prev != null && prev != e.value) {
        throw StateError('${spec.id} variable ${e.key} is $prev in one graph and ${e.value} in another');
      }
      merged[e.key] = e.value;
    }
  }
  final pool = [
    for (final e in merged.entries) {'name': e.key, 'type': e.value.toString()},
  ];
  Map<String, Object?> fixture(String id, Map<String, Object?> raw) => {
        'id': id,
        'in': raw,
        'out': batch2Oracles[spec.id]!.solve(raw),
      };
  final body = <String, Object?>{
    'id': spec.id,
    'version': 1,
    'title': spec.title,
    'world': spec.world,
    'chapter': spec.pattern,
    'tier': spec.tier,
    'mode': spec.mode,
    'concepts': spec.concepts,
    'prerequisites': <String>[],
    'story': spec.story,
    'io': {
      'inputs': [for (final b in puzzle.io.inputs) {'name': b.name, 'type': b.type.toString()}],
      'output': {'type': puzzle.io.output.toString()},
    },
    'constraints': {
      'n': {'min': 0, 'max': 80},
      'notes': spec.traps,
    },
    'blocks': {
      'allow': (puzzle.blocks.allow.toList()..sort()),
      'maxBlocks': puzzle.blocks.maxBlocks,
    },
    'limits': {'maxOps': puzzle.limits.maxOps, 'maxDepth': puzzle.limits.maxDepth, 'maxAlloc': puzzle.limits.maxAlloc},
    if (puzzle.performance.required)
      'performance': {
        'required': true,
        if (puzzle.performance.baselineFactor != null) 'baselineFactor': puzzle.performance.baselineFactor,
      },
    'hints': spec.hints,
    'validators': {'output': 'equal'},
    'fixtures': {
      'visible': [for (var i = 0; i < picked.visible.length; i++) fixture('v${i + 1}', picked.visible[i])],
      'hidden': [for (var i = 0; i < picked.hidden.length; i++) fixture('h${(i + 1).toString().padLeft(2, '0')}', picked.hidden[i])],
    },
    'edgeCases': spec.traps,
    'variables': {'pool': pool},
    'reference': {'strategy': spec.pattern},
  };
  final dir = Directory('${root.path}/assets/puzzles/${spec.world}')..createSync(recursive: true);
  File('${dir.path}/${spec.id}.json').writeAsStringSync('${_pretty(body)}\n');
}

void _writeReference(Directory root, Spec spec, Built built, RunMetrics metrics) {
  final body = <String, Object?>{
    'puzzle': spec.id,
    'notes': spec.notes.isEmpty ? spec.traps.join('; ') : spec.notes,
    'spec': {
      'family': spec.family,
      'pattern': spec.pattern,
      'structure': spec.structure,
      'secondary': spec.secondary,
      'performance': spec.performance,
      'traps': spec.traps,
      'oracle': spec.id,
    },
    'metrics': {
      'blocks': metrics.blocks,
      'ops': metrics.ops,
      'peakAlloc': metrics.peakAlloc,
      'peakDepth': metrics.peakDepth,
    },
    'solution': built.solution.toJson(),
    'rejects': [
      for (final reject in built.rejects)
        {'name': reject.name, 'expect': reject.expect, 'graph': reject.graph.toJson()},
    ],
  };
  final dir = Directory('${root.path}/content/references/${spec.world}')..createSync(recursive: true);
  File('${dir.path}/${spec.id}.json').writeAsStringSync('${_pretty(body)}\n');
}

void _patchWorlds(Directory root, Map<String, List<String>> byWorld) {
  final file = File('${root.path}/assets/worlds.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final worlds = (json['worlds']! as List).cast<Map<String, Object?>>();
  for (final world in worlds) {
    final id = world['id']! as String;
    final add = byWorld[id];
    if (add == null) continue;
    final puzzles = (world['puzzles']! as List).cast<String>();
    for (final puzzle in add) {
      if (!puzzles.contains(puzzle)) puzzles.add(puzzle);
    }
    world['puzzles'] = puzzles;
  }
  file.writeAsStringSync('${_pretty(json)}\n');
}

void _patchTurkish(Directory root) {
  final file = File('${root.path}/assets/l10n/content_tr.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final puzzles = (json['puzzles']! as Map).cast<String, Object?>();
  for (final spec in ms14Specs) {
    puzzles[spec.id] = {
      'title': spec.titleTr,
      'story': spec.storyTr,
      'hints': spec.hintsTr,
    };
  }
  json['puzzles'] = puzzles;
  file.writeAsStringSync('${_pretty(json)}\n');
}

String _pretty(Object? value) => const JsonEncoder.withIndent('  ').convert(value);

final _edges = <String, List<Map<String, Object?>>>{
  'first_descent': [
    {'values': <int>[]},
    {'values': [1, 2, 3, 4]},
    {'values': [4, 4, 3]},
    {'values': [5, 1]},
    {'values': [3, 3, 3]},
    {'values': [1, 0, 2]},
  ],
  'second_highest': [
    {'values': <int>[]},
    {'values': [4]},
    {'values': [9, 9, 9]},
    {'values': [1, 4]},
    {'values': [8, 8, 3, 8]},
    {'values': [-2, -5, -2]},
    {'values': [1, 9, 8]},
  ],
  'even_prefixes': [
    {'values': <int>[]},
    {'values': [1]},
    {'values': [2, 2]},
    {'values': [1, 1, 1]},
    {'values': [-1, 1, -1]},
  ],
  'nested_distinct': [
    {'values': <int>[]},
    {'values': [1, 1, 1]},
    {'values': [1, 2]},
    {'values': [3, 1, 3, 2, 1]},
    {'values': [for (var i = 0; i < 20; i++) i]},
  ],
  'max_product_two': [
    {'values': <int>[]},
    {'values': [7]},
    {'values': [4, -1, -4]},
    {'values': [-8, -3, 1]},
    {'values': [2, 3, 4]},
    {'values': [-2, 5, -6]},
  ],
  'pair_sum_count': [
    {'values': <int>[], 'target': 0},
    {'values': [1], 'target': 2},
    {'values': [1, 1], 'target': 2},
    {'values': [1, 2, 3], 'target': 4},
    {'values': [5, 5, 5], 'target': 10},
    {'values': [0, 0, 0, 1], 'target': 0},
  ],
  'same_value_span': [
    {'values': <int>[]},
    {'values': [4]},
    {'values': [1, 2, 3]},
    {'values': [2, 1, 2]},
    {'values': [7, 1, 7, 1, 7]},
    {'values': [3, 3]},
  ],
  'shared_values': [
    {'left': <int>[], 'right': <int>[]},
    {'left': [1, 1], 'right': <int>[]},
    {'left': [1, 2, 2], 'right': [2, 2, 3, 2]},
    {'left': [4], 'right': [4, 4]},
    {'left': [1, 2], 'right': [3]},
  ],
  'exact_gaps': [
    {'values': <int>[], 'gap': 2},
    {'values': [1, 2, 3], 'gap': 2},
    {'values': [1, 2, 3, 4], 'gap': 3},
    {'values': [5], 'gap': 1},
    {'values': [0, 2, 4, 7], 'gap': 1},
    {'values': [for (var i = 0; i < 18; i++) i], 'gap': 5},
  ],
  'pairs_under': [
    {'values': <int>[], 'limit': 5},
    {'values': [1, 2], 'limit': 0},
    {'values': [1, 2, 3], 'limit': 4},
    {'values': [1, 1, 1, 1], 'limit': 2},
    {'values': [5, 6, 7], 'limit': 20},
  ],
  'sorted_union': [
    {'left': <int>[], 'right': <int>[]},
    {'left': [1, 1, 1], 'right': <int>[]},
    {'left': [1, 3], 'right': [2, 3, 3]},
    {'left': [1, 2], 'right': [1, 2]},
    {'left': <int>[], 'right': [4, 4, 5]},
  ],
  'closest_gap': [
    {'values': [1, 4], 'target': 5},
    {'values': [1, 2, 9], 'target': 6},
    {'values': [-2, 0, 4], 'target': 1},
    {'values': [1, 2, 3, 8], 'target': 4},
    {'values': [5, 5, 5], 'target': 100},
  ],
  'windows_at_least': [
    {'values': <int>[], 'width': 1, 'goal': 1},
    {'values': [1, 2], 'width': 3, 'goal': 1},
    {'values': [1, 2, 3], 'width': 2, 'goal': 5},
    {'values': [1, 1, 1], 'width': 2, 'goal': 2},
    {'values': [4, 0, 4], 'width': 1, 'goal': 4},
  ],
  'one_dropout': [
    {'values': <int>[]},
    {'values': [1, 1, 1]},
    {'values': [0, 0]},
    {'values': [1, 0, 1, 0, 1]},
    {'values': [0, 1, 1, 0]},
    {'values': [1, 0, 0, 1]},
  ],
  'peak_windows': [
    {'values': <int>[], 'width': 1},
    {'values': [1, 2], 'width': 3},
    {'values': [1, 3, 2], 'width': 2},
    {'values': [5], 'width': 1},
    {'values': [1, 4, 2, 6, 3], 'width': 3},
  ],
  'counter_sum': [
    {'actions': <int>[]},
    {'actions': [0, 0]},
    {'actions': [4, 0]},
    {'actions': [2, 5, 0, 0]},
    {'actions': [3, 0, 0]},
    {'actions': [1, 2, 3]},
  ],
  'josephus_line': [
    {'people': 1, 'count': 1},
    {'people': 5, 'count': 1},
    {'people': 5, 'count': 2},
    {'people': 4, 'count': 3},
    {'people': 6, 'count': 2},
    {'people': 2, 'count': 2},
  ],
  'ticket_minutes': [
    {'tickets': [1], 'person': 0},
    {'tickets': [2, 3], 'person': 0},
    {'tickets': [5, 1, 1], 'person': 0},
    {'tickets': [2, 2, 2], 'person': 2},
    {'tickets': [3, 1, 4], 'person': 1},
  ],
  'stack_sorted': [
    {'want': <int>[]},
    {'want': [1, 2, 3]},
    {'want': [3, 2, 1]},
    {'want': [2, 1, 3]},
    {'want': [3, 1, 2]},
    {'want': [1]},
  ],
  'tail_lamp': [
    {'head': null},
    {'head': _chain([4])},
    {'head': _chain([1, 2, 9])},
    {'head': _chain([8, 8])},
  ],
  'cold_cars': [
    {'head': null, 'limit': 0},
    {'head': _chain([3]), 'limit': 3},
    {'head': _chain([1, 5, 2]), 'limit': 4},
    {'head': _chain([-2, 0, 2]), 'limit': 0},
    {'head': _chain([1, 2]), 'limit': 9},
  ],
  'named_car': [
    {'head': null, 'target': 1},
    {'head': _chain([2, 3]), 'target': 3},
    {'head': _chain([4]), 'target': 4},
    {'head': _chain([1, 1, 1]), 'target': 2},
    {'head': _chain([9, 8, 7]), 'target': 9},
  ],
  'end_gap': [
    {'head': null},
    {'head': _chain([6])},
    {'head': _chain([2, 5])},
    {'head': _chain([9, 1, 3])},
    {'head': _chain([4, 4, 4])},
  ],
  'rising_links': [
    {'head': null},
    {'head': _chain([3])},
    {'head': _chain([1, 1, 1])},
    {'head': _chain([1, 3, 2, 4])},
    {'head': _chain([5, 4, 3])},
  ],
  'left_vine': [
    {'root': null},
    {'root': _tree(1, null, _tree(2, null, null))},
    {'root': _tree(1, _tree(2, _tree(3, null, null), null), _tree(9, null, null))},
    {'root': _tree(4, null, null)},
    {'root': _vine([1, 2, 3, 4, 5, 6, 7, 8])},
  ],
  'right_marks': [
    {'root': null},
    {'root': _tree(3, _tree(100, null, null), null)},
    {'root': _tree(1, null, _tree(2, null, _tree(-4, null, null)))},
    {'root': _tree(5, null, null)},
  ],
  'lone_tree': [
    {'root': null},
    {'root': _tree(1, null, null)},
    {'root': _tree(1, _tree(2, null, null), null)},
    {'root': _tree(1, null, _tree(3, null, null))},
  ],
  'node_census': [
    {'root': null},
    {'root': _tree(1, null, null)},
    {'root': _tree(1, _tree(2, null, null), _tree(3, null, null))},
    {'root': _tree(1, _tree(2, _tree(3, null, null), null), null)},
  ],
  'leaf_census': [
    {'root': null},
    {'root': _tree(8, null, null)},
    {'root': _tree(1, _tree(2, null, null), _tree(3, null, null))},
    {'root': _tree(1, _tree(2, null, null), null)},
  ],
  'lowest_leaf': [
    {'root': null},
    {'root': _tree(4, null, null)},
    {'root': _tree(0, _tree(5, null, null), _tree(-2, null, null))},
    {'root': _tree(-9, _tree(3, null, null), null)},
  ],
  'platform_doors': [
    {'roads': _path(1), 'station': 0},
    {'roads': _path(3), 'station': 1},
    {'roads': _path(3), 'station': 0},
    {'roads': _digraph([[], [], []]), 'station': 2},
  ],
  'direct_hop': [
    {'roads': _path(2), 'start': 0, 'goal': 1},
    {'roads': _path(2), 'start': 1, 'goal': 0},
    {'roads': _digraph([[1, 2], [], []]), 'start': 0, 'goal': 2},
    {'roads': _path(1), 'start': 0, 'goal': 0},
  ],
  'silent_stops': [
    {'roads': _path(1)},
    {'roads': _path(3)},
    {'roads': _digraph([[], [], []])},
    {'roads': _digraph([[1], [0], []])},
  ],
  'scout_reach': [
    {'roads': _path(1), 'start': 0},
    {'roads': _path(4), 'start': 0},
    {'roads': _path(4), 'start': 2},
    {'roads': _digraph([[1], [], []]), 'start': 0},
    {'roads': _loop(), 'start': 0},
  ],
  'scout_last': [
    {'roads': _path(1), 'start': 0},
    {'roads': _digraph([[1, 2], [], []]), 'start': 0},
    {'roads': _path(3), 'start': 0},
    {'roads': _digraph([[2, 1], [0], [0]]), 'start': 0},
  ],
  'biggest_patch': [
    {'roads': _path(1)},
    {'roads': _undirectedPath(4)},
    {'roads': _twoComponents()},
    {'roads': _digraph([[], [], []])},
  ],
  'source_radius': [
    {'roads': _path(1), 'start': 0},
    {'roads': _undirectedPath(4), 'start': 0},
    {'roads': _undirectedPath(4), 'start': 2},
    {'roads': _twoComponents(), 'start': 0},
    {'roads': _digraph([[1], [2], []]), 'start': 0},
  ],
  'last_layer': [
    {'roads': _path(1), 'start': 0},
    {'roads': _undirectedPath(4), 'start': 0},
    {'roads': _digraph([[1, 2], [], []]), 'start': 0},
    {'roads': _twoComponents(), 'start': 0},
  ],
  'cookie_gifts': [
    {'children': <int>[], 'cookies': <int>[]},
    {'children': [1, 2], 'cookies': <int>[]},
    {'children': [1, 2, 3], 'cookies': [1, 1]},
    {'children': [1, 2], 'cookies': [2, 3]},
    {'children': [5], 'cookies': [1, 2, 3]},
  ],
  'dock_overlap': [
    {'starts': <int>[], 'ends': <int>[]},
    {'starts': [1], 'ends': [2]},
    {'starts': [1, 2], 'ends': [2, 3]},
    {'starts': [1, 2, 3], 'ends': [10, 10, 10]},
    {'starts': [0, 5], 'ends': [4, 6]},
  ],
  'leap_reach': [
    {'jumps': [0]},
    {'jumps': [1, 0]},
    {'jumps': [2, 0, 0]},
    {'jumps': [1, 1, 1]},
    {'jumps': [0, 1]},
    {'jumps': [1, 0, 1]},
  ],
  'plank_ways': [
    {'length': 0},
    {'length': 1},
    {'length': 2},
    {'length': 3},
    {'length': 5},
    {'length': 8},
  ],
  'step_toll': [
    {'costs': <int>[]},
    {'costs': [4]},
    {'costs': [1, 100, 1]},
    {'costs': [10, 1, 1]},
    {'costs': [2, 2, 2, 2]},
  ],
  'aisle_cost': [
    {'grid': [[4]]},
    {'grid': [[1, 2, 3]]},
    {'grid': [[1, 100], [1, 1]]},
    {'grid': [[1, 3, 1], [1, 5, 1], [4, 2, 1]]},
  ],
  'open_lanes': [
    {'grid': [[0]]},
    {'grid': [[0, 0], [0, 0]]},
    {'grid': [[0, 1], [0, 0]]},
    {'grid': [[0, 0, 0], [1, 1, 0], [0, 0, 0]]},
    {'grid': [[0, 1, 0], [0, 1, 0], [0, 0, 0]]},
  ],
  'diagonal_haul': [
    {'grid': [[6]]},
    {'grid': [[1, 2, 3]]},
    {'grid': [[1, 1], [5, 1]]},
    {'grid': [[1, -2], [3, 1]]},
    {'grid': [[0, 0, 5], [2, -1, 0]]},
  ],
  'pack_bins': [
    {'weights': <int>[], 'values': <int>[], 'cap': 5},
    {'weights': [4], 'values': [7], 'cap': 3},
    {'weights': [2, 3], 'values': [4, 5], 'cap': 4},
    {'weights': [1, 1], 'values': [1, 2], 'cap': 1},
    {'weights': [2, 2, 3], 'values': [3, 4, 5], 'cap': 5},
  ],
};

Object? _chain(List<int> values) => values.isEmpty ? null : {'type': 'listNode', 'values': values};

Object? _tree(int value, Object? left, Object? right) => {'type': 'treeNode', 'value': value, 'left': left, 'right': right};

Object? _vine(List<int> values) {
  Object? node;
  for (final value in values.reversed) {
    node = _tree(value, node, null);
  }
  return node;
}

Map<String, Object?> _digraph(List<List<int>> adj) => {
      'type': 'graph',
      'nodes': [for (var i = 0; i < adj.length; i++) {'id': i, 'neighbors': adj[i]}],
    };

Map<String, Object?> _path(int n) => _digraph([for (var i = 0; i < n; i++) if (i + 1 < n) [i + 1] else <int>[]]);

Map<String, Object?> _undirectedPath(int n) => _digraph([
      for (var i = 0; i < n; i++) [if (i > 0) i - 1, if (i + 1 < n) i + 1],
    ]);

Map<String, Object?> _loop() => _digraph([[1], [0, 2], [1]]);

Map<String, Object?> _twoComponents() => _digraph([
      [1],
      [0],
      [3],
      [2],
    ]);
