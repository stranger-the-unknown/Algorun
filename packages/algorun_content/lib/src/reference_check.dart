import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'editor_replay.dart';

/// Fields a reference file may carry.
const referenceFields = {'puzzle', 'notes', 'solution', 'rejects'};

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
      if (graph != null) _solution(puzzle, graph, error, warn);
    }

    final rejects = json['rejects'];
    if (rejects == null) return;
    if (rejects is! List<Object?>) {
      error('rejects', 'Must be a list.');
      return;
    }
    for (final (i, item) in rejects.indexed) {
      _reject(puzzle, item, 'rejects[$i]', error);
    }
  }

  void _solution(
    Puzzle puzzle,
    BlockGraph graph,
    void Function(String, String) error,
    void Function(String, String) warn,
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
  }

  void _reject(
    Puzzle puzzle,
    Object? item,
    String path,
    void Function(String, String) error,
  ) {
    if (item is! Map<String, Object?>) {
      error(path, 'A reject is {"name": …, "expect": …, "graph": {…}}.');
      return;
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
      return;
    }
    final graph = _graph(item['graph'], '$path.graph', error);
    if (graph == null || expect == null) return;
    final program = _buildable(puzzle, graph, '$path.graph', error);
    if (program == null) return;

    // A reject has to look right: it passes everything the player can see.
    final visible = const TestRunner().runCases(program, puzzle, puzzle.visibleTests);
    if (!visible.ok) {
      error(
        path,
        'A reject must pass every visible case, but it fails: '
        '${_firstFailure(program, puzzle, cases: puzzle.visibleTests)}',
      );
      return;
    }
    final suite = engine.runTests(program, puzzle);
    if (suite.kind != expect) {
      error(
        '$path.expect',
        'Expected the suite to end in ${expect.label}, but it ended in ${suite.kind.label}.',
      );
    }
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
