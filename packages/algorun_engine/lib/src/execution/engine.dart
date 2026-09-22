import '../ast/ir.dart';
import '../ast/lower.dart';
import '../blocks/block_graph.dart';
import '../puzzles/puzzle.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../validation/validation_report.dart';
import 'run_result.dart';
import 'suite_result.dart';

/// Optional step trace. Full visual debugger is a later milestone; the VM
/// must be able to emit these events.
typedef TraceSink = void Function(TraceEvent event);

final class TraceEvent {
  const TraceEvent({
    required this.opIndex,
    required this.kind,
    this.blockId,
    this.locals = const {},
  });

  final int opIndex;
  final String kind;
  final String? blockId;
  final Map<String, String> locals;
}

/// Thrown when a capability is specified but not yet implemented.
final class MilestoneNotImplemented implements Exception {
  const MilestoneNotImplemented(this.milestone, this.capability);
  final int milestone;
  final String capability;

  @override
  String toString() => '$capability is Milestone $milestone.';
}

/// Pipeline: BlockGraph → validate → lower → run / runTests.
///
/// Implementations must not eval Dart, JS, or generated source.
abstract interface class AlgorunEngine {
  ValidationReport validate(BlockGraph graph, Puzzle puzzle);

  /// Structural + semantic checks, then a typed [Program]. Never throws.
  LowerResult lower(BlockGraph graph, Puzzle puzzle);

  RunResult run(
    Program program,
    Map<String, RuntimeValue> input,
    RunLimits limits, {
    TraceSink? trace,
  });

  SuiteResult runTests(Program program, Puzzle puzzle);
}
