/// Deterministic performance data. Everything here is an operation count from
/// the MS5 interpreter — never wall-clock time, and never a complexity claim.
/// The engine does not prove Big-O; it counts what a run did against a
/// budget the puzzle declares.
library;

/// How much room a measurement run gets past a case's budget.
///
/// The verdict never depends on these: a case that needs more than its budget
/// fails with `ResultKind.operationLimit` exactly as it always has. The extra
/// room only *measures* how far over it went, so a player can watch a correct
/// but slow solution get closer to the budget. The ceiling keeps a RUN on a
/// phone short.
const overrunFactor = 5;

/// Absolute cap on the extra operations a measurement may spend.
const overrunCap = 1000000;

/// The measurement ceiling for a case with operation budget [budget].
int overrunCeiling(int budget) {
  final extra = budget * (overrunFactor - 1);
  return budget + (extra > overrunCap ? overrunCap : extra);
}

/// How far one case went past its operation budget, measured by running the
/// same program on the same input again with room up to [ceiling].
final class BudgetOverrun {
  const BudgetOverrun({
    required this.budget,
    required this.ceiling,
    required this.measuredOps,
    required this.finished,
    this.outputCorrect,
  });

  /// The case's operation budget.
  final int budget;

  /// How far the measurement was allowed to go.
  final int ceiling;

  /// Operations the run needed; equal to [ceiling] when it never finished.
  final int measuredOps;

  /// Whether the run completed within [ceiling].
  final bool finished;

  /// When [finished]: whether the output matches the expected one under the
  /// puzzle's validator. Null when the run never finished.
  final bool? outputCorrect;
}

/// The suite's performance summary. Counts only: it never names a hidden case
/// or shows a hidden input or answer.
final class SuitePerformance {
  const SuitePerformance({
    required this.opsBudget,
    required this.worstOps,
    required this.overBudgetCases,
    required this.overBudgetFinished,
    required this.correctWhereFinished,
    this.worstOverrun,
  });

  /// The puzzle's operation budget, `limits.maxOps`. A case may declare a
  /// tighter budget of its own, never a looser one.
  final int opsBudget;

  /// The most operations any case needed. For a case over its budget this is
  /// the measured count, or the measurement ceiling when it never finished.
  final int worstOps;

  /// Cases, visible and hidden, that needed more than their budget.
  final int overBudgetCases;

  /// Whether every over-budget case finished within its measurement ceiling.
  final bool overBudgetFinished;

  /// Whether every case that finished — inside its budget or inside the
  /// measurement ceiling — produced the expected output.
  final bool correctWhereFinished;

  /// The over-budget case that went furthest past its own budget (largest
  /// measured-to-budget ratio). Numbers only; it never says which case.
  final BudgetOverrun? worstOverrun;

  bool get withinBudget => overBudgetCases == 0;

  /// The result is correct, but the solution uses too many operations.
  bool get correctButOverBudget =>
      overBudgetCases > 0 && overBudgetFinished && correctWhereFinished;
}
