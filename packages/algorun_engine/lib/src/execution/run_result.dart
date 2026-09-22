import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import 'result_kind.dart';

final class RunResult {
  const RunResult({
    required this.kind,
    required this.metrics,
    this.message,
    this.output,
    this.blockId,
  });

  final ResultKind kind;
  final RunMetrics metrics;
  final String? message;
  final RuntimeValue? output;
  final String? blockId;

  bool get ok => kind == ResultKind.correct;
}
