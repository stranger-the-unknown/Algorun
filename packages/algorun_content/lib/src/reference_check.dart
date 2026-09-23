import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'editor_replay.dart';

/// Fields a reference file may carry.
const referenceFields = {'puzzle', 'notes', 'solution', 'rejects', 'metrics'};

/// Fields of the recorded reference metrics.
const referenceMetricFields = {'ops', 'peakAlloc', 'peakDepth', 'blocks'};

/// Fields of one entry in `rejects`.
const rejectFields = {'name', 'expect', 'graph'};

/// Share of a budget above which a passing reference is flagged as fragile.
const budgetWarningShare = 0.8;

/// Proves a puzzle is solvable as shipped, from a reference file of the form:
///
/// ```json
/// {
///   "puzzle": "<puzzle id>",
///   "notes": "<why this is the intended approach>",
///   "solution": { <BlockGraph JSON> },
///   "rejects": [
///     { "name": "every pair", "expect": "operationLimit", "graph": { <BlockGraph JSON> } }
///   ]
/// }
/// ```
///
/// The solution must be a program a player can build — the puzzle's givens and
/// pool, its allowlist and block budget, editor-settable literals, every
/// connection accepted by the editor — and it must pass every visible and
/// hidden case through the real `TestRunner`, inside the puzzle's limits.
///
/// Each reject is a buildable program that passes every *visible* case and
/// then ends the full suite in exactly the declared [ResultKind]. That is how a
/// puzzle proves its budget turns away a correct-but-slow approach, or that a
/// hidden case catches a tempting mistake.
///
/// `metrics` records what the reference costs (worst-case operations, peak
/// memory cells, peak depth, blocks) as content metadata. The checker measures
/// again and refuses a mismatch, so a change to the operation model or to the
/// reference can never slip through unnoticed.
///
/// When the puzzle declares `performance.required`, at least one reject must
/// expect `operationLimit`: the correct-but-slow baseline. With
/// `performance.baselineFactor`, that baseline must need at least that many
/// times a case's operation budget on some case.
///
/// Reference graphs are data. They run only inside the sandboxed interpreter.
final class ReferenceChecker {
  const ReferenceChecker({this.engine = const DefaultEngine()});

  final AlgorunEngine engine;

  void check(
    Puzzle puzzle,
    String source,
    String file,
    List<ContentIssue> issues,
  ) {
    void error(String path, String message) =>
        issues.add(ContentIssue(Severity.error, file, path, message));
    void warn(String path, String message) =>
        issues.add(ContentIssue(Severity.warning, file, path, message));
    void info(String path, String message) =>
        issues.add(ContentIssue(Severity.info, file, path, message));

    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      error('', 'Not valid JSON: ${e.message}');
      return;
    }
    if (json is! Map<String, Object?>) {
      error('', 'A reference is a JSON object.');
      return;
    }
    for (final key in json.keys) {
      if (!referenceFields.contains(key)) {
        error(key, 'Unknown field "$key". Allowed here: ${referenceFields.join(', ')}.');
      }
    }
    final named = json['puzzle'];
    if (named != puzzle.id) {
      error('puzzle', 'Names ${jsonEncode(named)}, but this file belongs to "${puzzle.id}".');
    }
    if (json.containsKey('notes') && json['notes'] is! String) {
      error('notes', 'Must be text.');
    }

    if (!json.containsKey('solution')) {
      error('solution', 'Required: the reference solution as a block graph.');
    } else {
      final graph = _graph(json['solution'], 'solution', error);
      if (graph != null) {
        _solution(puzzle, graph, json['metrics'], error, warn, info);
      }
    }

    final rejects = json['rejects'];
    final baselines = <({String name, Program program, String path})>[];
    if (rejects != null && rejects is! List<Object?>) {
      error('rejects', 'Must be a list.');
    } else if (rejects is List<Object?>) {
      for (final (i, item) in rejects.indexed) {
        final checked = _reject(puzzle, item, 'rejects[$i]', error);
        if (checked != null && checked.expect == ResultKind.operationLimit) {
          baselines.add((name: checked.name, program: checked.program, path: 'rejects[$i]'));
        }
      }
    }
    _performance(puzzle, baselines, error);
  }

  /// `performance.required`: a correct-but-slow baseline must be proven to
  /// fail the budget; `baselineFactor`: by at least that factor on some case.
  void _performance(
    Puzzle puzzle,
    List<({String name, Program program, String path})> baselines,
    void Function(String, String) error,
  ) {
    final spec = puzzle.performance;
    if (!spec.required) return;
    if (baselines.isEmpty) {
      error(
        'rejects',
        'performance.required: add a correct-but-slow baseline, a reject that '
        'passes the visible cases and expects operationLimit.',
      );
      return;
    }
    final factor = spec.baselineFactor;
    if (factor == null) return;
    for (final baseline in baselines) {
      var best = 0.0;
      for (final testCase in puzzle.allTests) {
        final budget = puzzle.opsBudgetFor(testCase);
        final wanted = budget * factor;
        final ceiling = wanted > maxOpsCeiling ? maxOpsCeiling : wanted;
        final run = runProgram(
          baseline.program,
          testCase.input,
          RunLimits(
            maxOps: ceiling,
            maxDepth: puzzle.limits.maxDepth,
            maxAlloc: puzzle.limits.maxAlloc,
          ),
        );
        final ratio = run.metrics.ops / budget;
        if (ratio > best) best = ratio;
        if (best >= factor) break;
      }
      if (best < factor) {
        error(
          '${baseline.path}.expect',
          'The baseline "${baseline.name}" needs at most ${best.toStringAsFixed(1)}x a '
          'case budget; performance.baselineFactor asks for ${factor}x.',
        );
      }
    }
  }

  void _solution(
    Puzzle puzzle,
    BlockGraph graph,
    Object? recorded,
    void Function(String, String) error,
    void Function(String, String) warn,
    void Function(String, String) info,
  ) {
    final program = _buildable(puzzle, graph, 'solution', error);
    if (program == null) return;
    final suite = engine.runTests(program, puzzle);
    if (!suite.ok) {
      error('solution', 'The reference does not pass: ${_firstFailure(program, puzzle)}');
      return;
    }
    final limits = puzzle.limits;
    void headroom(String what, int used, int limit) {
      if (used > limit * budgetWarningShare) {
        warn('solution', 'Uses $used of $limit $what; a budget this tight is fragile.');
      }
    }

    headroom('operations', suite.metrics.ops, limits.maxOps);
    headroom('memory cells', suite.metrics.peakAlloc, limits.maxAlloc);
    headroom('levels of depth', suite.metrics.peakDepth, limits.maxDepth);

    final m = suite.metrics;
    final share = (m.ops * 100 / limits.maxOps).round();
    final maxBlocks = puzzle.blocks.maxBlocks;
    final blocks = maxBlocks == null ? '${m.blocks}' : '${m.blocks} of $maxBlocks';
    info(
      'solution',
      'Reference needs ${m.ops} of ${limits.maxOps} operations ($share%), '
      '${m.peakAlloc} of ${limits.maxAlloc} memory cells, depth ${m.peakDepth} of '
      '${limits.maxDepth}, $blocks blocks.',
    );

    final measured = {
      'ops': m.ops,
      'peakAlloc': m.peakAlloc,
      'peakDepth': m.peakDepth,
      'blocks': m.blocks,
    };
    if (recorded == null) {
      warn('metrics', 'Reference metrics are not recorded. Measured: ${jsonEncode(measured)}.');
      return;
    }
    if (recorded is! Map<String, Object?>) {
      error('metrics', 'Must be an object such as ${jsonEncode(measured)}.');
      return;
    }
    for (final key in recorded.keys) {
      if (!referenceMetricFields.contains(key)) {
        error('metrics.$key', 'Unknown field "$key". Allowed here: ${referenceMetricFields.join(', ')}.');
      }
    }
    for (final entry in measured.entries) {
      final value = recorded[entry.key];
      if (value != entry.value) {
        error(
          'metrics.${entry.key}',
          'Recorded ${jsonEncode(value)}, measured ${entry.value}. The reference or the '
          'operation model changed; if that is intended, record the new value.',
        );
      }
    }
  }

  ({String name, ResultKind expect, Program program})? _reject(
    Puzzle puzzle,
    Object? item,
    String path,
    void Function(String, String) error,
  ) {
    if (item is! Map<String, Object?>) {
      error(path, 'A reject is {"name": …, "expect": …, "graph": {…}}.');
      return null;
    }
    for (final key in item.keys) {
      if (!rejectFields.contains(key)) {
        error('$path.$key', 'Unknown field "$key". Allowed here: ${rejectFields.join(', ')}.');
      }
    }
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) {
      error('$path.name', 'Required: a short name for this approach.');
    }
    final expectRaw = item['expect'];
    final expect = ResultKind.values
        .where((k) => k != ResultKind.correct && k.name == expectRaw)
        .firstOrNull;
    if (expect == null) {
      final kinds = ResultKind.values.where((k) => k != ResultKind.correct).map((k) => k.name);
      error('$path.expect', 'Must be one of ${kinds.join(', ')}.');
    }
    if (!item.containsKey('graph')) {
      error('$path.graph', 'Required: the rejected program as a block graph.');
      return null;
    }
    final graph = _graph(item['graph'], '$path.graph', error);
    if (graph == null || expect == null) return null;
    final program = _buildable(puzzle, graph, '$path.graph', error);
    if (program == null) return null;

    // A reject has to look right: it passes everything the player can see.
    final visible = const TestRunner().runCases(program, puzzle, puzzle.visibleTests);
    if (!visible.ok) {
      error(
        path,
        'A reject must pass every visible case, but it fails: '
        '${_firstFailure(program, puzzle, cases: puzzle.visibleTests)}',
      );
      return null;
    }
    final suite = engine.runTests(program, puzzle);
    if (suite.kind != expect) {
      error(
        '$path.expect',
        'Expected the suite to end in ${expect.label}, but it ended in ${suite.kind.label}.',
      );
      return null;
    }
    if (name is! String) return null;
    return (name: name, expect: expect, program: program);
  }

  /// Everything a player's program must be before it can run: inside the
  /// allowlist and block budget, buildable in the editor, and lowerable.
  Program? _buildable(
    Puzzle puzzle,
    BlockGraph graph,
    String path,
    void Function(String, String) error,
  ) {
    final report = engine.validate(graph, puzzle);
    for (final m in report.messages) {
      error(m.blockId == null ? path : '$path.blocks.${m.blockId}', m.message);
    }
    if (!report.ok) return null;

    final replay = replayInEditor(graph, puzzle);
    for (final issue in replay) {
      error('$path.${issue.path}', issue.message);
    }
    if (replay.isNotEmpty) return null;

    final lowered = engine.lower(graph, puzzle);
    for (final m in lowered.errors) {
      error(m.blockId == null ? path : '$path.blocks.${m.blockId}', m.message);
    }
    return lowered.program;
  }

  BlockGraph? _graph(Object? raw, String path, void Function(String, String) error) {
    if (raw is! Map<String, Object?>) {
      error(path, 'Must be a block graph object.');
      return null;
    }
    try {
      return BlockGraph.fromJson(Map<String, dynamic>.from(raw));
    } on FormatException catch (e) {
      error(path, 'Not a block graph: ${e.message}');
    } on TypeError {
      error(path, 'Not a block graph: a field has the wrong type.');
    }
    return null;
  }

  /// Content tooling may name a hidden case; the player UI never does.
  String _firstFailure(Program program, Puzzle puzzle, {List<TestCase>? cases}) {
    const runner = TestRunner();
    for (final testCase in cases ?? puzzle.allTests) {
      final suite = runner.runCases(program, puzzle, [testCase]);
      if (!suite.ok) {
        final side = testCase.visible ? 'visible' : 'hidden';
        return '${suite.kind.label} on $side case "${testCase.id}" — ${suite.message}';
      }
    }
    return 'the suite fails, but no single case does.';
  }
}
