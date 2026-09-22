import 'dart:convert';

import '../runtime/limits.dart';
import '../types/parse_type.dart';
import 'puzzle.dart';
import 'world.dart';

export '../types/parse_type.dart' show parseValueType;

Puzzle parsePuzzleJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Puzzle JSON must be an object.');
  }
  return parsePuzzleMap(decoded);
}

Puzzle parsePuzzleMap(Map<String, dynamic> m) {
  final id = _reqString(m, 'id');
  final title = _reqString(m, 'title');
  final world = _reqString(m, 'world');
  final story = _reqString(m, 'story');
  final mode = _mode(_reqString(m, 'mode'));
  final tier = _tier(m['tier'] ?? 1);

  final blocksRaw = _reqMap(m, 'blocks');
  final allow = _stringSet(blocksRaw['allow']);
  if (allow.isEmpty) {
    throw FormatException('Puzzle $id must declare a non-empty blocks.allow list.');
  }
  final policy = BlockPolicy(
    allow: allow,
    forbid: _stringSet(blocksRaw['forbid']),
    maxBlocks: blocksRaw['maxBlocks'] as int?,
  );

  final limitsRaw = _reqMap(m, 'limits');
  final maxOps = limitsRaw['maxOps'];
  if (maxOps is! int) {
    throw FormatException('Puzzle $id must declare integer limits.maxOps.');
  }
  final limits = PerformanceTarget(
    maxOps: maxOps,
    maxDepth: (limitsRaw['maxDepth'] as int?) ?? 256,
    maxAlloc: (limitsRaw['maxAlloc'] as int?) ?? 10000,
    notes: limitsRaw['notes'] as String?,
  );

  final ioRaw = _reqMap(m, 'io');
  final inputs = <IoBinding>[];
  final inList = ioRaw['inputs'];
  if (inList is! List) {
    throw FormatException('Puzzle $id io.inputs must be a list.');
  }
  for (final item in inList) {
    final im = item as Map<String, dynamic>;
    inputs.add(IoBinding(
      name: _reqString(im, 'name'),
      type: parseValueType(_reqString(im, 'type')),
    ));
  }
  final outRaw = ioRaw['output'] as Map<String, dynamic>;
  final io = IoSpec(
    inputs: inputs,
    output: parseValueType(_reqString(outRaw, 'type')),
    outputOrderMatters: (outRaw['order'] as String?) != 'any',
  );

  final fixtures = _reqMap(m, 'fixtures');
  final visible = _cases(fixtures['visible'], visible: true);
  final hidden = _cases(fixtures['hidden'], visible: false);
  if (visible.isEmpty) {
    throw FormatException('Puzzle $id needs at least one visible test.');
  }
  if (hidden.isEmpty) {
    throw FormatException('Puzzle $id needs at least one hidden test.');
  }

  final validators = m['validators'];
  var outputValidator = 'equal';
  if (validators is Map<String, dynamic>) {
    outputValidator = validators['output'] as String? ?? 'equal';
  }

  final constraintsRaw = m['constraints'];
  ConstraintSpec constraints = const ConstraintSpec();
  if (constraintsRaw is Map<String, dynamic>) {
    final n = constraintsRaw['n'];
    constraints = ConstraintSpec(
      nMin: n is Map ? n['min'] as int? : null,
      nMax: n is Map ? n['max'] as int? : null,
      notes: _stringList(constraintsRaw['notes']),
    );
  }

  final scoringRaw = m['scoring'];
  ScoringSpec scoring = const ScoringSpec();
  if (scoringRaw is Map<String, dynamic>) {
    scoring = ScoringSpec(
      blockBudget: scoringRaw['blockBudget'] as int?,
      hintPenalty: scoringRaw['hintPenalty'] as bool? ?? true,
    );
  }

  final verdict = m['verdictSource'] == 'remote'
      ? VerdictSource.remote
      : VerdictSource.local;

  final pool = <IoBinding>[];
  final varsRaw = m['variables'];
  if (varsRaw is Map<String, dynamic>) {
    final poolRaw = varsRaw['pool'];
    if (poolRaw is List) {
      for (final item in poolRaw) {
        final im = item as Map<String, dynamic>;
        pool.add(IoBinding(
          name: _reqString(im, 'name'),
          type: parseValueType(_reqString(im, 'type')),
        ));
      }
    }
  }

  return Puzzle(
    id: id,
    version: m['version'] as int? ?? 1,
    title: title,
    world: world,
    chapter: m['chapter'] as String? ?? '',
    tier: tier,
    mode: mode,
    concepts: _stringList(m['concepts']),
    prerequisites: _stringList(m['prerequisites']),
    story: story,
    io: io,
    constraints: constraints,
    blocks: policy,
    limits: limits,
    scoring: scoring,
    hints: _stringList(m['hints']),
    outputValidator: outputValidator,
    visibleTests: visible,
    hiddenTests: hidden,
    edgeCases: _stringList(m['edgeCases']),
    verdictSource: verdict,
    variablePool: pool,
  );
}

WorldsManifest parseWorldsJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Worlds JSON must be an object.');
  }
  final list = decoded['worlds'];
  if (list is! List) {
    throw const FormatException('worlds must be a list.');
  }
  final worlds = <WorldDef>[];
  for (final item in list) {
    final m = item as Map<String, dynamic>;
    worlds.add(WorldDef(
      id: _reqString(m, 'id'),
      title: _reqString(m, 'title'),
      index: m['index'] as int? ?? worlds.length + 1,
      puzzleIds: _stringList(m['puzzles']),
      concepts: _stringList(m['concepts']),
      prerequisites: _stringList(m['prerequisites']),
    ));
  }
  return WorldsManifest(worlds);
}

List<TestCase> _cases(Object? raw, {required bool visible}) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const FormatException('fixtures must be lists.');
  }
  final out = <TestCase>[];
  for (final item in raw) {
    final m = item as Map<String, dynamic>;
    final inputRaw = m['in'];
    if (inputRaw is! Map) {
      throw const FormatException('Test case needs in: {}.');
    }
    out.add(TestCase(
      id: _reqString(m, 'id'),
      input: Map<String, Object?>.from(inputRaw),
      output: m['out'],
      visible: visible,
    ));
  }
  return out;
}

PuzzleMode _mode(String raw) {
  return PuzzleMode.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => throw FormatException('Unknown mode: $raw'),
  );
}

PuzzleTier _tier(Object raw) {
  final n = raw is int ? raw : int.tryParse('$raw') ?? 1;
  return switch (n) {
    1 => PuzzleTier.t1,
    2 => PuzzleTier.t2,
    3 => PuzzleTier.t3,
    4 => PuzzleTier.t4,
    5 => PuzzleTier.t5,
    _ => throw FormatException('tier must be 1–5, got $n'),
  };
}

String _reqString(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is! String || v.isEmpty) {
    throw FormatException('Missing string "$key".');
  }
  return v;
}

Map<String, dynamic> _reqMap(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is! Map<String, dynamic>) {
    throw FormatException('Missing object "$key".');
  }
  return v;
}

Set<String> _stringSet(Object? raw) {
  if (raw == null) return {};
  if (raw is! List) throw const FormatException('Expected string list.');
  return {for (final e in raw) e as String};
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) throw const FormatException('Expected string list.');
  return [for (final e in raw) e as String];
}
