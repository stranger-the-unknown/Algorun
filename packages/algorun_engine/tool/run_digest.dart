// Digests of every reference program's run on every case, per puzzle.
//
// T1 (step trace) had to leave untraced runs exactly as they were. This file
// works out a fingerprint of the whole corpus — each puzzle's reference
// solution and its rejects, run on every fixture under the test runner's
// limits: verdict, operations, peak memory, peak depth, output, failing block
// and message. It uses only API the engine already had before T1, so the same
// file runs against the pre-T1 engine:
//
//   dart run tool/run_digest.dart > test/golden/pre_t1_runs.json
//
// `test/golden/pre_t1_runs.json` was written that way by the engine at commit
// 4fbbfed (2026-10-30). `test/trace_parity_test.dart` holds today's engine to
// it, with tracing off and with tracing on.
//
// Run from `packages/algorun_engine`.
import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';

typedef Runner = RunResult Function(Program program, Map<String, RuntimeValue> input, RunLimits limits);

RunResult plainRun(Program program, Map<String, RuntimeValue> input, RunLimits limits) =>
    runProgram(program, input, limits);

/// FNV-1a, 64 bit, over UTF-16 code units. Enough to tell two files or two
/// result lists apart; not a secret.
String fnv(String text) {
  var hash = 0xcbf29ce484222325;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return hash.toRadixString(16);
}

Object? _output(RuntimeValue? value) {
  if (value == null) return null;
  try {
    return valueToJson(value);
  } on FixtureFormatException {
    return value.toJson();
  }
}

/// One run as a line of text: everything a run reports.
String runLine(String program, String caseId, RunResult run) => jsonEncode([
      program,
      caseId,
      run.kind.name,
      run.metrics.ops,
      run.metrics.peakAlloc,
      run.metrics.peakDepth,
      _output(run.output),
      run.blockId,
      run.message,
    ]);

/// `{puzzleId: {source, runs, digest}}` for every reference under
/// [referencesDir] whose puzzle is under [puzzlesDir].
///
/// `source` fingerprints the puzzle file and the reference file, so a reader
/// of an old golden can tell a puzzle that was edited since from an engine
/// that changed.
Map<String, Map<String, Object>> digestCorpus({
  String puzzlesDir = '../../assets/puzzles',
  String referencesDir = '../../content/references',
  Runner run = plainRun,
}) {
  const engine = DefaultEngine();
  final out = <String, Map<String, Object>>{};
  final files = Directory(referencesDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final parts = file.uri.pathSegments;
    final world = parts[parts.length - 2];
    final id = parts.last.substring(0, parts.last.length - '.json'.length);
    final puzzleFile = File('$puzzlesDir/$world/$id.json');
    if (!puzzleFile.existsSync()) continue;
    final referenceText = file.readAsStringSync();
    final puzzleText = puzzleFile.readAsStringSync();
    final reference = jsonDecode(referenceText) as Map<String, Object?>;
    final puzzle = parsePuzzleJson(puzzleText);
    final programs = <String, Object?>{
      'solution': reference['solution'],
      for (final reject in (reference['rejects'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
        'reject:${reject['name']}': reject['graph'],
    };
    final lines = <String>[];
    for (final entry in programs.entries) {
      final json = entry.value;
      if (json is! Map) continue;
      final graph = BlockGraph.fromJson(Map<String, dynamic>.from(json));
      final program = engine.lower(graph, puzzle).program;
      if (program == null) {
        lines.add(jsonEncode([entry.key, 'does not lower']));
        continue;
      }
      for (final testCase in puzzle.allTests) {
        final limits = RunLimits(
          maxOps: puzzle.opsBudgetFor(testCase),
          maxDepth: puzzle.limits.maxDepth,
          maxAlloc: puzzle.limits.maxAlloc,
        );
        lines.add(runLine(entry.key, testCase.id, run(program, testCase.input, limits)));
      }
    }
    out[id] = {
      'source': fnv('$puzzleText\n$referenceText'),
      'runs': lines.length,
      'digest': fnv(lines.join('\n')),
    };
  }
  return out;
}

void main() {
  stdout.writeln(const JsonEncoder.withIndent(' ').convert(digestCorpus()));
}
