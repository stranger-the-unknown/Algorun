import '../runtime/limits.dart';
import 'result_kind.dart';
import 'run_result.dart';

final class CaseResult {
  const CaseResult({
    required this.id,
    required this.visible,
    required this.run,
  });

  final String id;
  final bool visible;
  final RunResult run;
}

final class HiddenSummary {
  const HiddenSummary({required this.passed, required this.total});
  final int passed;
  final int total;
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
  });

  final ResultKind kind;
  final List<CaseResult> visible;
  final HiddenSummary? hiddenSummary;
  final RunMetrics metrics;
  final String? message;
  final String? firstFailureBlockId;
}
