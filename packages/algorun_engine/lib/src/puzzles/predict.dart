import '../ast/ir.dart';
import '../execution/interpreter.dart';
import '../execution/result_kind.dart';
import '../execution/run_result.dart';
import '../execution/suite_result.dart';
import '../runner/test_runner.dart' show countBlocks;
import '../runner/validators.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../runtime/value_json.dart';
import 'puzzle.dart';

/// Grades a `predict` puzzle (M1): the player says what the puzzle's program
/// returns for each visible case, and every answer is compared with what the
/// interpreter really returns — not with a stored answer.
///
/// [program] is the puzzle's starter program, lowered; [answers] holds the
/// player's answer per visible case id. A case without an answer is wrong.
///
/// The result has the shape of a test run so the same progress rules apply
/// (`ResultKind.correct` completes the puzzle): one [CaseResult] per visible
/// case, `actual` being the player's answer. `expected` is set only when the
/// answer was right, so a wrong answer never carries the real one out of the
/// engine. Hidden cases take no part: they are never shown, so they cannot be
/// asked; the content pipeline uses them to prove the program.
SuiteResult gradePredictions(
  Program program,
  Puzzle puzzle,
  Map<String, RuntimeValue> answers,
) {
  final results = <CaseResult>[];
  var worstOps = 0;
  var worstAlloc = 0;
  var worstDepth = 0;
  ResultKind? failure;
  String? message;
  String? failureCase;

  for (final testCase in puzzle.visibleTests) {
    final run = runProgram(
      program,
      testCase.input,
      RunLimits(
        maxOps: puzzle.opsBudgetFor(testCase),
        maxDepth: puzzle.limits.maxDepth,
        maxAlloc: puzzle.limits.maxAlloc,
      ),
    );
    final m = run.metrics;
    if (m.ops > worstOps) worstOps = m.ops;
    if (m.peakAlloc > worstAlloc) worstAlloc = m.peakAlloc;
    if (m.peakDepth > worstDepth) worstDepth = m.peakDepth;

    final answer = answers[testCase.id];
    final RunResult graded;
    if (run.kind != ResultKind.correct) {
      // The puzzle's own program failed: content the pipeline should have
      // refused. Reported as it is, never as the player's mistake.
      graded = run;
    } else if (answer != null &&
        compareOutputs(puzzle.outputValidator, answer, run.output ?? const NilValue())) {
      graded = RunResult(kind: ResultKind.correct, metrics: m);
    } else {
      graded = RunResult(
        kind: ResultKind.wrongAnswer,
        metrics: m,
        message: 'That is not what the program returns for this input.',
      );
    }
    results.add(CaseResult(
      id: testCase.id,
      visible: true,
      run: graded,
      input: {
        for (final entry in testCase.input.entries) entry.key: valueToJson(entry.value),
      },
      expected: graded.ok && answer != null ? valueToJson(answer) : null,
      actual: answer == null ? null : valueToJson(answer),
    ));
    if (!graded.ok && failure == null) {
      failure = graded.kind;
      failureCase = testCase.id;
      message = graded.message ?? graded.kind.label;
    }
  }

  return SuiteResult(
    kind: failure ?? ResultKind.correct,
    visible: results,
    metrics: RunMetrics(
      ops: worstOps,
      peakAlloc: worstAlloc,
      peakDepth: worstDepth,
      blocks: countBlocks(program),
    ),
    message: message ?? 'Every answer is what the program returns.',
    firstFailureCaseId: failureCase,
  );
}
