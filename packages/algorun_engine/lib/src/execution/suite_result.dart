import '../runtime/limits.dart';
import 'result_kind.dart';
import 'run_result.dart';

/// One graded fixture. [input], [expected] and [actual] are filled for visible
/// cases only — a hidden case never carries its payload out of the engine.
final class CaseResult {
  const CaseResult({
    required this.id,
    required this.visible,
    required this.run,
    this.input,
    this.expected,
    this.actual,
  });

  final String id;
  final bool visible;
  final RunResult run;

  /// JSON-shaped copies for the results UI. Null for hidden cases.
  final Map<String, Object?>? input;
  final Object? expected;
  final Object? actual;

  bool get ok => run.kind == ResultKind.correct;
}

/// What the player may learn about the hidden fixtures: counts, nothing else.
final class HiddenSummary {
  const HiddenSummary({required this.passed, required this.total});
  final int passed;
  final int total;

  bool get allPassed => passed == total;
}

/// Full suite outcome. Hidden case payloads must not be attached to UI state.
final class SuiteResult {
  const SuiteResult({
    required this.kind,
    required this.visible,
    required this.metrics,
    this.hiddenSummary,
    this.message,
    this.firstFailureBlockId,
    this.firstFailureOpIndex,
    this.firstFailureCaseId,
  });

  final ResultKind kind;

  /// Visible cases in fixture order. Hidden cases are never listed.
  final List<CaseResult> visible;

  final HiddenSummary? hiddenSummary;

  /// Worst run across the suite: `ops`, `peakAlloc` and `peakDepth` are the
  /// maximum any single case needed, `blocks` counts the blocks the program
  /// is made of, and `hintsUsed` is session state the engine does not hold.
  final RunMetrics metrics;

  final String? message;

  /// Where the first failure happened. The block id and op index are the
  /// player's own program, so they are safe to show for a hidden failure;
  /// [firstFailureCaseId] is filled only when that case is visible.
  final String? firstFailureBlockId;
  final int? firstFailureOpIndex;
  final String? firstFailureCaseId;

  bool get ok => kind == ResultKind.correct;
}
