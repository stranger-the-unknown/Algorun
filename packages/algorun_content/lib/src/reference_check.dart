import 'dart:convert';
import 'dart:math';

import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'content_spec.dart';
import 'editor_replay.dart';
import 'oracles/oracle.dart';
import 'oracles/registry.dart';

/// Fields a reference file may carry.
const referenceFields = {'puzzle', 'notes', 'solution', 'rejects', 'metrics', 'spec'};

/// Fields of the recorded reference metrics.
const referenceMetricFields = {'ops', 'peakAlloc', 'peakDepth', 'blocks'};

/// Fields of one entry in `rejects`.
const rejectFields = {'name', 'expect', 'graph'};

/// Share of a budget above which a passing reference is flagged as fragile.
const budgetWarningShare = 0.8;

/// What a checked reference file gave the corpus checks.
final class CheckedReference {
  const CheckedReference({this.spec, this.solution});

  final ContentSpec? spec;

  /// The solution graph, when it proved the puzzle.
  final BlockGraph? solution;
}

/// Proves a puzzle is solvable as shipped, from a reference file of the form:
///
/// ```json
/// {
///   "puzzle": "<puzzle id>",
///   "notes": "<why this is the intended approach>",
///   "spec": { "family": …, "pattern": …, "oracle": …, … },
///   "metrics": {"ops": …, "peakAlloc": …, "peakDepth": …, "blocks": …},
///   "solution": { <BlockGraph JSON> },
///   "rejects": [
///     { "name": "every pair", "expect": "operationLimit", "graph": { <BlockGraph JSON> } }
///   ]
/// }
/// ```
///
/// Levels (see [Level]): the file's shape (1); the solution inside the
/// allowlist, the block budget and the language capabilities (2); rebuilt in
/// the editor and lowered (3); every visible and hidden case through the real
/// `TestRunner`, every reject ending in its declared verdict, and the
/// independent oracle agreeing with every fixture and with the reference on
/// sampled inputs (4); budgets, recorded metrics and declared performance
/// (5).
///
/// Each reject is a buildable program that passes every *visible* case and
/// then ends the full suite in exactly the declared [ResultKind] — a tempting
/// mistake the hidden cases catch, or a correct-but-slow approach the budget
/// turns away.
///
/// A campaign puzzle must carry a `spec` naming its [Oracle]; the fixtures'
/// expected outputs must match the oracle, and the reference must match the
/// oracle on [Oracle.samples] random inputs. A disagreement fails the puzzle —
/// the checker never "fixes" an expected answer to match the reference.
///
/// Reference graphs are data. They run only inside the sandboxed interpreter.
final class ReferenceChecker {
  const ReferenceChecker({this.engine = const DefaultEngine(), this.oracles = oracleRegistry});

  final AlgorunEngine engine;
  final Map<String, Oracle> oracles;

  CheckedReference? check(
    Puzzle puzzle,
    String source,
    String file,
    List<ContentIssue> issues, {
    bool campaign = false,
    Capabilities? capabilities,
  }) {
    void add(Severity severity, int level, String path, String message) =>
        issues.add(ContentIssue(severity, file, path, message, level: level, puzzle: puzzle.id));
    void error(int level, String path, String message) => add(Severity.error, level, path, message);
    void warn(int level, String path, String message) => add(Severity.warning, level, path, message);
    void info(int level, String path, String message) => add(Severity.info, level, path, message);

    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      error(Level.schema, '', 'Not valid JSON: ${e.message}');
      return null;
    }
    if (json is! Map<String, Object?>) {
      error(Level.schema, '', 'A reference is a JSON object.');
      return null;
    }
    for (final key in json.keys) {
      if (!referenceFields.contains(key)) {
        error(Level.schema, key, 'Unknown field "$key". Allowed here: ${referenceFields.join(', ')}.');
      }
    }
    final named = json['puzzle'];
    if (named != puzzle.id) {
      error(Level.schema, 'puzzle', 'Names ${jsonEncode(named)}, but this file belongs to "${puzzle.id}".');
    }
    if (json.containsKey('notes') && json['notes'] is! String) {
      error(Level.schema, 'notes', 'Must be text.');
    }

    ContentSpec? spec;
    if (json.containsKey('spec')) {
      spec = readSpec(json['spec'], (path, message) => error(Level.schema, path, message));
    } else if (campaign) {
      error(Level.schema, 'spec',
          'A campaign puzzle needs a spec: family, pattern, structure, performance, traps and its oracle.');
    }
    Oracle? oracle;
    if (spec != null) {
      _capabilities(puzzle, spec, capabilities, error);
      for (final problem in performanceMismatch(spec, puzzle)) {
        error(Level.performance, 'spec.performance', problem);
      }
      oracle = oracles[spec.oracle];
      if (oracle == null) {
        error(Level.schema, 'spec.oracle', 'No oracle "${spec.oracle}" in the content tooling.');
      }
    }
    if (campaign) _fixtureQuality(puzzle, error, warn);

    // The fixtures answer to the oracle whether or not the reference passes
    // them: a wrong expected output is named, never blamed on the program.
    if (oracle != null) _oracleFixtures(puzzle, oracle, error);

    BlockGraph? solution;
    if (!json.containsKey('solution')) {
      error(Level.schema, 'solution', 'Required: the reference solution as a block graph.');
    } else {
      final graph = _graph(json['solution'], 'solution', error);
      if (graph != null) {
        final (:program, :passed) = _solution(puzzle, graph, json['metrics'], error, warn, info);
        if (passed) solution = graph;
        if (program != null && oracle != null) _oracleSamples(puzzle, program, oracle, error);
      }
    }

    final rejects = json['rejects'];
    final baselines = <({String name, Program program, String path})>[];
    if (rejects != null && rejects is! List<Object?>) {
      error(Level.schema, 'rejects', 'Must be a list.');
    } else if (rejects is List<Object?>) {
      for (final (i, item) in rejects.indexed) {
        final checked = _reject(puzzle, item, 'rejects[$i]', error);
        if (checked != null && checked.expect == ResultKind.operationLimit) {
          baselines.add((name: checked.name, program: checked.program, path: 'rejects[$i]'));
        }
      }
    }
    _performance(puzzle, baselines, error);
    return CheckedReference(spec: spec, solution: solution);
  }

  /// Level 2: the family and the mode must be something the language (and the
  /// product) can express today.
  void _capabilities(
    Puzzle puzzle,
    ContentSpec spec,
    Capabilities? capabilities,
    void Function(int, String, String) error,
  ) {
    if (capabilities == null) return;
    final family = capabilities.families[spec.family];
    if (family == null) {
      error(Level.blocks, 'spec.family', 'Unknown family "${spec.family}"; add it to the capability audit first.');
    } else if (family.status == CapabilityStatus.blocked) {
      error(Level.blocks, 'spec.family', 'The language cannot express "${spec.family}" yet: ${family.note}');
    }
    final mode = capabilities.modes[puzzle.mode.name];
    if (mode != null && mode.status == CapabilityStatus.blocked) {
      error(Level.blocks, 'spec', 'Mode "${puzzle.mode.name}" is not playable yet: ${mode.note}');
    }
  }

  /// Level 4: hidden cases are not copies of visible ones, and there are
  /// enough of them to discriminate.
  void _fixtureQuality(
    Puzzle puzzle,
    void Function(int, String, String) error,
    void Function(int, String, String) warn,
  ) {
    String key(TestCase c) => jsonEncode({for (final b in puzzle.io.inputs) b.name: valueToJson(c.input[b.name]!)});
    final visible = {for (final c in puzzle.visibleTests) key(c): c.id};
    for (final c in puzzle.hiddenTests) {
      final same = visible[key(c)];
      if (same != null) {
        error(Level.execution, 'fixtures', 'Hidden case "${c.id}" repeats visible case "$same".');
      }
    }
    if (puzzle.hiddenTests.length < 4) {
      warn(Level.execution, 'fixtures.hidden',
          'Only ${puzzle.hiddenTests.length} hidden case(s); hidden cases should cover the edges and the traps.');
    }
    // MS14 review: fixtures whose answers never change let a constant pass.
    final cases = [...puzzle.visibleTests, ...puzzle.hiddenTests];
    final answers = {for (final c in cases) jsonEncode(valueToJson(c.output))};
    if (cases.length > 1 && answers.length == 1) {
      error(Level.execution, 'fixtures',
          'Every case expects ${answers.single}: a program that always returns that would pass. Add cases with other answers.');
    }
  }

  RuntimeValue? _answer(
    Puzzle puzzle,
    Oracle oracle,
    Map<String, Object?> input,
    String where,
    void Function(int, String, String) error,
  ) {
    try {
      return valueFromJson(oracle.solve(input), type: puzzle.io.output);
    } on Object catch (e) {
      error(Level.execution, 'spec.oracle', 'The oracle "${oracle.id}" fails on $where: $e');
      return null;
    }
  }

  /// Level 4: every fixture's expected output agrees with the oracle.
  void _oracleFixtures(Puzzle puzzle, Oracle oracle, void Function(int, String, String) error) {
    for (final (i, testCase) in puzzle.allTests.indexed) {
      final input = {for (final b in puzzle.io.inputs) b.name: valueToJson(testCase.input[b.name]!)};
      final expected = _answer(puzzle, oracle, input, 'case "${testCase.id}"', error);
      if (expected == null) continue;
      if (!compareOutputs(puzzle.outputValidator, testCase.output, expected)) {
        final list = testCase.visible ? 'visible' : 'hidden';
        final index = testCase.visible ? i : i - puzzle.visibleTests.length;
        error(
          Level.execution,
          'fixtures.$list[$index].out',
          'Case "${testCase.id}" expects ${jsonEncode(valueToJson(testCase.output))}, but the oracle says '
          '${jsonEncode(valueToJson(expected))}. Check the fixture and the oracle; the reference cannot settle it.',
        );
      }
    }
  }

  /// Level 4: the reference agrees with the oracle on [Oracle.samples]
  /// random inputs the fixtures do not hold.
  void _oracleSamples(Puzzle puzzle, Program program, Oracle oracle, void Function(int, String, String) error) {
    final random = Random(_seed(puzzle.id));
    var disagreements = 0;
    for (var i = 0; i < oracle.samples && disagreements < 3; i++) {
      final raw = oracle.sample(random);
      final Map<String, RuntimeValue> input;
      try {
        input = {for (final b in puzzle.io.inputs) b.name: valueFromJson(raw[b.name], type: b.type)};
      } on Object catch (e) {
        error(Level.execution, 'spec.oracle', 'The oracle "${oracle.id}" sampled an input the puzzle cannot hold: $e');
        return;
      }
      final expected = _answer(puzzle, oracle, raw, 'sample ${jsonEncode(raw)}', error);
      if (expected == null) return;
      final run = runProgram(
        program,
        input,
        RunLimits(maxOps: puzzle.limits.maxOps, maxDepth: puzzle.limits.maxDepth, maxAlloc: puzzle.limits.maxAlloc),
      );
      if (run.kind != ResultKind.correct) {
        disagreements++;
        error(Level.execution, 'solution',
            'On sampled input ${jsonEncode(raw)} the reference ends in ${run.kind.label}: ${run.message}');
      } else if (!compareOutputs(puzzle.outputValidator, run.output ?? const NilValue(), expected)) {
        disagreements++;
        error(
          Level.execution,
          'solution',
          'The reference and the oracle disagree on sampled input ${jsonEncode(raw)}: the reference gives '
          '${jsonEncode(valueToJson(run.output ?? const NilValue()))}, the oracle ${jsonEncode(valueToJson(expected))}.',
        );
      }
    }
  }

  static int _seed(String id) => id.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x3fffffff);

  /// `performance.required`: a correct-but-slow baseline must be proven to
  /// fail the budget; `baselineFactor`: by at least that factor on some case.
  void _performance(
    Puzzle puzzle,
    List<({String name, Program program, String path})> baselines,
    void Function(int, String, String) error,
  ) {
    final spec = puzzle.performance;
    if (!spec.required) return;
    if (baselines.isEmpty) {
      error(
        Level.performance,
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
          Level.performance,
          '${baseline.path}.expect',
          'The baseline "${baseline.name}" needs at most ${best.toStringAsFixed(1)}x a '
          'case budget; performance.baselineFactor asks for ${factor}x.',
        );
      }
    }
  }

  /// The lowered reference (when it builds) and whether it passed.
  ({Program? program, bool passed}) _solution(
    Puzzle puzzle,
    BlockGraph graph,
    Object? recorded,
    void Function(int, String, String) error,
    void Function(int, String, String) warn,
    void Function(int, String, String) info,
  ) {
    final program = _buildable(puzzle, graph, 'solution', error);
    if (program == null) return (program: null, passed: false);
    final suite = engine.runTests(program, puzzle);
    if (!suite.ok) {
      final level = suite.kind == ResultKind.operationLimit ||
              suite.kind == ResultKind.memoryLimit ||
              suite.kind == ResultKind.depthLimit
          ? Level.performance
          : Level.execution;
      error(level, 'solution', 'The reference does not pass: ${_firstFailure(program, puzzle)}');
      return (program: program, passed: false);
    }
    final limits = puzzle.limits;
    void headroom(String what, int used, int limit) {
      if (used > limit * budgetWarningShare) {
        warn(Level.performance, 'solution', 'Uses $used of $limit $what; a budget this tight is fragile.');
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
      Level.performance,
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
      warn(Level.performance, 'metrics', 'Reference metrics are not recorded. Measured: ${jsonEncode(measured)}.');
      return (program: program, passed: true);
    }
    if (recorded is! Map<String, Object?>) {
      error(Level.performance, 'metrics', 'Must be an object such as ${jsonEncode(measured)}.');
      return (program: program, passed: true);
    }
    for (final key in recorded.keys) {
      if (!referenceMetricFields.contains(key)) {
        error(Level.schema, 'metrics.$key', 'Unknown field "$key". Allowed here: ${referenceMetricFields.join(', ')}.');
      }
    }
    for (final entry in measured.entries) {
      final value = recorded[entry.key];
      if (value != entry.value) {
        error(
          Level.performance,
          'metrics.${entry.key}',
          'Recorded ${jsonEncode(value)}, measured ${entry.value}. The reference or the '
          'operation model changed; if that is intended, record the new value.',
        );
      }
    }
    return (program: program, passed: true);
  }

  ({String name, ResultKind expect, Program program})? _reject(
    Puzzle puzzle,
    Object? item,
    String path,
    void Function(int, String, String) error,
  ) {
    if (item is! Map<String, Object?>) {
      error(Level.schema, path, 'A reject is {"name": …, "expect": …, "graph": {…}}.');
      return null;
    }
    for (final key in item.keys) {
      if (!rejectFields.contains(key)) {
        error(Level.schema, '$path.$key', 'Unknown field "$key". Allowed here: ${rejectFields.join(', ')}.');
      }
    }
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) {
      error(Level.schema, '$path.name', 'Required: a short name for this approach.');
    }
    final expectRaw = item['expect'];
    final expect = ResultKind.values
        .where((k) => k != ResultKind.correct && k.name == expectRaw)
        .firstOrNull;
    if (expect == null) {
      final kinds = ResultKind.values.where((k) => k != ResultKind.correct).map((k) => k.name);
      error(Level.schema, '$path.expect', 'Must be one of ${kinds.join(', ')}.');
    }
    if (!item.containsKey('graph')) {
      error(Level.schema, '$path.graph', 'Required: the rejected program as a block graph.');
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
        Level.execution,
        path,
        'A reject must pass every visible case, but it fails: '
        '${_firstFailure(program, puzzle, cases: puzzle.visibleTests)}',
      );
      return null;
    }
    final suite = engine.runTests(program, puzzle);
    if (suite.kind != expect) {
      error(
        Level.execution,
        '$path.expect',
        'Expected the suite to end in ${expect.label}, but it ended in ${suite.kind.label}.',
      );
      return null;
    }
    if (name is! String) return null;
    return (name: name, expect: expect, program: program);
  }

  /// Everything a player's program must be before it can run: inside the
  /// allowlist and block budget (level 2), buildable in the editor and
  /// lowerable (level 3).
  Program? _buildable(
    Puzzle puzzle,
    BlockGraph graph,
    String path,
    void Function(int, String, String) error,
  ) {
    final report = engine.validate(graph, puzzle);
    for (final m in report.messages) {
      error(Level.blocks, m.blockId == null ? path : '$path.blocks.${m.blockId}', m.message);
    }
    if (!report.ok) return null;

    final replay = replayInEditor(graph, puzzle);
    for (final issue in replay) {
      error(Level.replay, '$path.${issue.path}', issue.message);
    }
    if (replay.isNotEmpty) return null;

    final lowered = engine.lower(graph, puzzle);
    for (final m in lowered.errors) {
      error(Level.replay, m.blockId == null ? path : '$path.blocks.${m.blockId}', m.message);
    }
    return lowered.program;
  }

  BlockGraph? _graph(Object? raw, String path, void Function(int, String, String) error) {
    if (raw is! Map<String, Object?>) {
      error(Level.schema, path, 'Must be a block graph object.');
      return null;
    }
    try {
      return BlockGraph.fromJson(Map<String, dynamic>.from(raw));
    } on FormatException catch (e) {
      error(Level.schema, path, 'Not a block graph: ${e.message}');
    } on TypeError {
      error(Level.schema, path, 'Not a block graph: a field has the wrong type.');
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
