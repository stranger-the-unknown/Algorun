import 'package:algorun_engine/algorun_engine.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Player-facing wording for operation budgets. Every sentence talks about
/// counted operations against a budget — never about Big-O or a complexity
/// class, which the engine does not and cannot prove.

/// `28008` → `28,008` (English), `28.008` (Turkish).
String formatCount(int n, [String locale = 'en']) => NumberFormat.decimalPattern(locale).format(n);

/// What to tell the player when the suite ran out of operations, or null to
/// keep the suite's own message. Counts only: no hidden case is named.
String? performanceMessage(SuiteResult suite, [AppLocalizations? strings]) {
  final l = strings ?? englishStrings;
  final perf = suite.performance;
  final over = perf?.worstOverrun;
  if (suite.kind != ResultKind.operationLimit || perf == null || over == null) {
    return null;
  }
  String count(int n) => formatCount(n, l.localeName);
  final budget = count(over.budget);
  if (perf.correctButOverBudget) {
    return l.perfCorrectButOver(count(over.measuredOps), budget);
  }
  if (!over.finished && perf.correctWhereFinished) {
    return l.perfStillRunning(count(over.measuredOps), budget);
  }
  return l.perfWrongAndOver(
    over.finished ? count(over.measuredOps) : l.perfMoreThan(count(over.measuredOps)),
    budget,
  );
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
