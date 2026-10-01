import '../ast/ir.dart';
import '../execution/interpreter.dart';
import '../execution/performance.dart';
import '../execution/result_kind.dart';
import '../execution/run_result.dart';
import '../puzzles/puzzle.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import 'validators.dart';

/// One case run against its operation budget, plus — when it ran out — a
/// measurement of how far over it went.
final class CaseMeasurement {
  const CaseMeasurement({
    required this.budget,
    required this.run,
    this.overrun,
  });

  /// The case's operation budget ([Puzzle.opsBudgetFor]).
  final int budget;

  /// The budgeted run. Its kind, message and metrics are exactly what the
  /// interpreter reports under the budget: the verdict is decided here.
  final RunResult run;

  /// Only when [run] hit the operation budget.
  final BudgetOverrun? overrun;
}

/// Run [testCase] the way the test runner does: under the puzzle's memory and
/// depth limits and the case's operation budget. When the budget stops it, run
/// the same program on the same input once more with room up to
/// [overrunCeiling] to measure the real cost and whether the answer would be
/// right. Both runs are deterministic; the second never changes the verdict.
CaseMeasurement measureCase(Program program, Puzzle puzzle, TestCase testCase) {
  final budget = puzzle.opsBudgetFor(testCase);
  final run = runProgram(program, testCase.input, _limits(puzzle, budget));
  if (run.kind != ResultKind.operationLimit) {
    return CaseMeasurement(budget: budget, run: run);
  }
  final ceiling = overrunCeiling(budget);
  final measured = runProgram(program, testCase.input, _limits(puzzle, ceiling));
  final finished = measured.kind != ResultKind.operationLimit;
  return CaseMeasurement(
    budget: budget,
    run: run,
    overrun: BudgetOverrun(
      budget: budget,
      ceiling: ceiling,
      measuredOps: measured.metrics.ops,
      finished: finished,
      outputCorrect: finished
          ? measured.kind == ResultKind.correct &&
              compareOutputs(
                puzzle.outputValidator,
                measured.output ?? const NilValue(),
                testCase.output,
              )
          : null,
    ),
  );
}

RunLimits _limits(Puzzle puzzle, int maxOps) => RunLimits(
      maxOps: maxOps,
      maxDepth: puzzle.limits.maxDepth,
      maxAlloc: puzzle.limits.maxAlloc,
    );

/// A deterministic measurement of one case. Content tooling and analytics
/// only: it names hidden cases, so it must never reach the player UI.
final class PerformanceSample {
  const PerformanceSample({
    required this.caseId,
    required this.visible,
    required this.inputSize,
    required this.ops,
    required this.peakAlloc,
    required this.peakDepth,
    required this.finished,
  });

  final String caseId;
  final bool visible;

  /// [inputSize] of the case's input.
  final int inputSize;

  /// Operations needed: inside the budget, measured past it, or the
  /// measurement ceiling when the run never finished.
  final int ops;
  final int peakAlloc;
  final int peakDepth;

  /// False when the run was still going at the measurement ceiling.
  final bool finished;
}

/// A declared budget checked against a measured case.
final class BudgetCheck {
  const BudgetCheck({
    required this.caseId,
    required this.maxOps,
    required this.ops,
    required this.passed,
  });

  final String caseId;
  final int maxOps;
  final int ops;
  final bool passed;
}

/// Samples and budget checks for one program over a set of cases. It reports
/// counts against declared budgets and nothing more: it never fits a curve or
/// names a complexity class.
final class PerformanceReport {
  const PerformanceReport({required this.samples, required this.checks});

  final List<PerformanceSample> samples;
  final List<BudgetCheck> checks;

  bool get passed => checks.every((c) => c.passed);
}

/// Measure [program] on [cases] (default: every case of [puzzle], visible
/// first) and check each against its operation budget. Deterministic: the
/// same program and cases always give the same report.
PerformanceReport benchmark(
  Program program,
  Puzzle puzzle, {
  List<TestCase>? cases,
}) {
  final samples = <PerformanceSample>[];
  final checks = <BudgetCheck>[];
  for (final testCase in cases ?? puzzle.allTests) {
    final m = measureCase(program, puzzle, testCase);
    final overrun = m.overrun;
    final ops = overrun?.measuredOps ?? m.run.metrics.ops;
    samples.add(PerformanceSample(
      caseId: testCase.id,
      visible: testCase.visible,
      inputSize: inputSize(testCase),
      ops: ops,
      peakAlloc: m.run.metrics.peakAlloc,
      peakDepth: m.run.metrics.peakDepth,
      finished: overrun?.finished ?? true,
    ));
    checks.add(BudgetCheck(
      caseId: testCase.id,
      maxOps: m.budget,
      ops: ops,
      passed: overrun == null,
    ));
  }
  return PerformanceReport(samples: samples, checks: checks);
}

/// How big a case's input is: the total size of its collection-valued inputs
/// (elements of a list, set, stack, queue or deque, entries of a map, nodes of
/// a linked list, tree or graph). Numbers, text and yes/no add nothing. This
/// is a size for plotting samples, not the `n` of a complexity proof.
int inputSize(TestCase testCase) {
  var total = 0;
  for (final value in testCase.input.values) {
    total += _size(value);
  }
  return total;
}

int _size(RuntimeValue value) {
  return switch (value) {
    ArrayValue(:final elements) => elements.length,
    SetValue(:final members) => members.length,
    MapValue(:final entries) => entries.length,
    StackValue(:final items) => items.length,
    QueueValue(:final items) => items.length,
    DequeValue(:final items) => items.length,
    HeapValue(:final items) => items.length,
    GraphValue(:final adjacency) => adjacency.length,
    ListNodeValue() => _chainLength(value),
    TreeNodeValue() => _treeSize(value, <TreeNodeValue>{}),
    NilValue() || NumValue() || BoolValue() || StrValue() => 0,
  };
}

int _chainLength(ListNodeValue head) {
  final seen = <ListNodeValue>{};
  ListNodeValue? cursor = head;
  while (cursor != null && seen.add(cursor)) {
    cursor = cursor.next;
  }
  return seen.length;
}

int _treeSize(TreeNodeValue? node, Set<TreeNodeValue> seen) {
  if (node == null || !seen.add(node)) return 0;
  return 1 + _treeSize(node.left, seen) + _treeSize(node.right, seen);
}
