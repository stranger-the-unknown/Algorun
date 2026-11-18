import '../ast/ir.dart';
import '../execution/trace.dart';
import '../puzzles/puzzle.dart';
import 'benchmark.dart';

/// Record the steps of [program] on one **visible** case of [puzzle], run
/// exactly as the test runner graded it ([caseLimits]).
///
/// Returns null for any id that is not one of the puzzle's visible cases.
/// Hidden cases are looked for nowhere: a trace shows every input and every
/// value on the way to the answer, so tracing one would show the player the
/// fixture the results screen keeps back. This is the only way the app
/// starts a trace.
TraceRecording? traceVisibleCase(
  Program program,
  Puzzle puzzle,
  String caseId, {
  int from = 0,
  TraceLimits traceLimits = TraceLimits.standard,
}) {
  for (final testCase in puzzle.visibleTests) {
    if (testCase.id != caseId || !testCase.visible) continue;
    return recordTrace(
      program,
      testCase.input,
      caseLimits(puzzle, testCase),
      from: from,
      traceLimits: traceLimits,
    );
  }
  return null;
}
