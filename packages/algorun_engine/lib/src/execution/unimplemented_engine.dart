import '../ast/ir.dart';
import '../ast/lower.dart';
import '../blocks/block_graph.dart';
import '../blocks/catalog.dart';
import '../blocks/structure.dart';
import '../puzzles/puzzle.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import '../validation/validation_report.dart';
import 'engine.dart';
import 'result_kind.dart';
import 'run_result.dart';
import 'suite_result.dart';

/// Validates and lowers. Interpreting and test execution are later milestones.
final class UnimplementedEngine implements AlgorunEngine {
  const UnimplementedEngine();

  @override
  ValidationReport validate(BlockGraph graph, Puzzle puzzle) {
    final messages = <ValidationMessage>[];
    if (graph.isEmpty) {
      messages.add(const ValidationMessage(
        code: 'empty_program',
        message: 'The canvas is empty.',
      ));
    }
    if (puzzle.blocks.allow.isEmpty) {
      messages.add(const ValidationMessage(
        code: 'empty_allowlist',
        message: 'This puzzle does not expose any blocks.',
      ));
    }
    for (final block in graph.blocks.values) {
      if (!BlockIds.exists(block.catalogId)) {
        messages.add(ValidationMessage(
          code: 'unknown_block',
          message: 'Unknown block.',
          blockId: block.id,
        ));
        continue;
      }
      if (!puzzle.blocks.allows(block.catalogId)) {
        messages.add(ValidationMessage(
          code: 'block_not_allowed',
          message: 'This puzzle does not include that block.',
          blockId: block.id,
        ));
      }
    }
    final maxBlocks = puzzle.blocks.maxBlocks;
    if (maxBlocks != null && graph.blockCount > maxBlocks) {
      messages.add(ValidationMessage(
        code: 'block_budget',
        message: 'This puzzle allows at most $maxBlocks blocks.',
      ));
    }
    messages.addAll(GraphStructure.validate(graph).messages);
    return ValidationReport(messages: messages);
  }

  @override
  LowerResult lower(BlockGraph graph, Puzzle puzzle) {
    final report = validate(graph, puzzle);
    if (!report.ok) return LowerResult.fail(report.messages);
    return const Lowerer().lower(graph, puzzle);
  }

  @override
  RunResult run(
    Program program,
    Map<String, RuntimeValue> input,
    RunLimits limits, {
    TraceSink? trace,
  }) {
    return const RunResult(
      kind: ResultKind.invalidProgram,
      metrics: RunMetrics.zero,
      message: 'The interpreter is not implemented yet (Milestone 5).',
    );
  }

  @override
  SuiteResult runTests(Program program, Puzzle puzzle) {
    return const SuiteResult(
      kind: ResultKind.invalidProgram,
      visible: [],
      metrics: RunMetrics.zero,
      message: 'The test runner is not implemented yet (Milestone 6).',
    );
  }
}
