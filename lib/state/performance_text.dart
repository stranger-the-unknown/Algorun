import 'package:algorun_engine/algorun_engine.dart';

/// Player-facing wording for operation budgets. Every sentence talks about
/// counted operations against a budget — never about Big-O or a complexity
/// class, which the engine does not and cannot prove.

/// `28008` → `28,008`.
String formatCount(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// What to tell the player when the suite ran out of operations, or null to
/// keep the suite's own message. Counts only: no hidden case is named.
String? performanceMessage(SuiteResult suite) {
  final perf = suite.performance;
  final over = perf?.worstOverrun;
  if (suite.kind != ResultKind.operationLimit || perf == null || over == null) {
    return null;
  }
  final budget = formatCount(over.budget);
  if (perf.correctButOverBudget) {
    return 'The result is correct, but this solution uses too many operations: '
        '${formatCount(over.measuredOps)} against a budget of $budget.';
  }
  if (!over.finished && perf.correctWhereFinished) {
    return 'Every case that finished came out right, but this solution uses too '
        'many operations: it was still running after '
        '${formatCount(over.measuredOps)}, and the budget is $budget.';
  }
  return 'This solution uses too many operations '
      '(${over.finished ? formatCount(over.measuredOps) : 'more than ${formatCount(over.measuredOps)}'} '
      'against a budget of $budget), and not every answer is right either.';
}

/// What the run cost. Over budget, operations are the measured count — with a
/// `+` when the run was still going at the measurement ceiling.
String costLine(SuiteResult suite) {
  final m = suite.metrics;
  final perf = suite.performance;
  final ops = perf == null
      ? formatCount(m.ops)
      : '${formatCount(perf.worstOps)}${perf.overBudgetFinished ? '' : '+'}';
  final hints = m.hintsUsed == 1 ? '1 hint' : '${m.hintsUsed} hints';
  return '$ops steps · ${formatCount(m.peakAlloc)} cells · '
      'depth ${m.peakDepth} · ${m.blocks} blocks · $hints';
}

/// What the puzzle allows, in the same order as [costLine].
String budgetLine(Puzzle puzzle) {
  final limits = puzzle.limits;
  final maxBlocks = puzzle.blocks.maxBlocks;
  return 'Budget: ${formatCount(limits.maxOps)} steps · '
      '${formatCount(limits.maxAlloc)} cells · depth ${limits.maxDepth}'
      '${maxBlocks == null ? '' : ' · $maxBlocks blocks'}';
}
