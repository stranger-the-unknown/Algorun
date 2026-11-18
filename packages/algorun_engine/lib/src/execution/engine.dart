import '../ast/ir.dart';
import '../ast/lower.dart';
import '../blocks/block_graph.dart';
import '../puzzles/puzzle.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../validation/validation_report.dart';
import 'run_result.dart';
import 'suite_result.dart';

/// Optional step trace: the interpreter calls the sink once per step.
///
/// A sink never changes a run. Results and the `ops` / `alloc` / `depth`
/// counts are the same with and without one (`trace_test.dart` holds the
/// interpreter to that). [recordTrace] is the sink the step-through screen
/// uses.
typedef TraceSink = void Function(TraceEvent event);

/// What a [TraceEvent] reports. One event per instruction that ran, plus the
/// start of a frame and the failure that stopped a run.
abstract final class TraceKinds {
  /// The program is about to run its first instruction.
  static const start = 'start';

  /// A player function was entered; its parameters are bound.
  static const call = 'call';

  /// IF checked its condition ([TraceEvent.value] is the answer).
  static const ifStep = 'if';

  /// WHILE checked its condition ([TraceEvent.value] is the answer).
  static const whileStep = 'while';

  /// FOR set its counter for the next pass.
  static const forRange = 'forRange';

  /// FOR EACH took the next item.
  static const forEach = 'forEach';

  /// FOR or FOR EACH had nothing left and went on past its body.
  static const loopEnd = 'loopEnd';

  static const assign = 'assign';
  static const inc = 'inc';
  static const dec = 'dec';

  /// An instruction that is one block doing its work (APPEND, PUSH, a CALL
  /// on its own line). [TraceEvent.value] is what it gave back, if anything.
  static const expr = 'expr';

  static const breakStep = 'break';
  static const continueStep = 'continue';

  /// RETURN worked out its value ([TraceEvent.value]); the frame is still
  /// there.
  static const returnStep = 'return';

  /// The run stopped on a failure: [TraceEvent.message] says why and
  /// [TraceEvent.blockId] is the block that failed. Always the last event.
  static const halt = 'halt';
}

/// One function frame while a sink is being called: the names in play and
/// their live values.
///
/// [vars] is the interpreter's own table. A sink reads it during the call and
/// copies what it wants to keep; it must not change it or hold on to it.
final class TraceFrame {
  const TraceFrame({
    required this.serial,
    required this.function,
    required this.vars,
    this.blockId,
  });

  /// Counts frames as they are entered, from 1: two events show the same
  /// frame exactly when the serials match.
  final int serial;

  /// `main`, or the player function's name.
  final String function;

  /// The FUNCTION block, for a player function.
  final String? blockId;

  final Map<String, RuntimeValue> vars;
}

final class TraceEvent {
  TraceEvent({
    required this.opIndex,
    required this.kind,
    this.blockId,
    this.frames = const [],
    this.value,
    this.message,
  }) : depth = frames.length;

  /// Operations counted so far, this step's own included.
  final int opIndex;

  /// One of [TraceKinds].
  final String kind;

  /// The block this step belongs to.
  final String? blockId;

  /// The call stack, outermost first. Live: valid only while the sink runs.
  final List<TraceFrame> frames;

  /// The value this step worked out, where it has one (see [TraceKinds]).
  final RuntimeValue? value;

  /// Why the run stopped ([TraceKinds.halt] only).
  final String? message;

  /// How many frames were open at this step, the running one included.
  /// Unlike [frames], still right after the sink has returned.
  final int depth;

  /// The running frame's names with their values as display text. Worked out
  /// the first time it is read, so read it inside the sink.
  late final Map<String, String> locals = {
    if (frames.isNotEmpty)
      for (final entry in frames.last.vars.entries) entry.key: '${entry.value.toJson()}',
  };
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
