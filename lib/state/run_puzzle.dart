import 'package:algorun_engine/algorun_engine.dart';

/// What RUN produced: what to fix, and how the fixtures graded.
final class RunOutcome {
  const RunOutcome({required this.validation, required this.suite});

  final ValidationReport validation;
  final SuiteResult suite;
}

/// The RUN path, in one place so the screen stays a button and this stays
/// testable: block graph → validate + lower → test runner → result.
///
/// A graph that cannot be lowered never reaches the runner; the player gets
/// the lowering's own game-facing message instead.
RunOutcome runPuzzle(AlgorunEngine engine, BlockGraph graph, Puzzle puzzle) {
  final lowered = engine.lower(graph, puzzle);
  final validation = ValidationReport(messages: lowered.errors);
  final program = lowered.program;
  if (program == null) {
    final first = lowered.errors.isEmpty ? null : lowered.errors.first;
    return RunOutcome(
      validation: validation,
      suite: SuiteResult(
        kind: ResultKind.invalidProgram,
        visible: const [],
        metrics: RunMetrics.zero,
        message: first?.message ?? 'This program is not ready to run.',
        firstFailureBlockId: first?.blockId,
      ),
    );
  }
  return RunOutcome(
    validation: validation,
    suite: engine.runTests(program, puzzle),
  );
}
