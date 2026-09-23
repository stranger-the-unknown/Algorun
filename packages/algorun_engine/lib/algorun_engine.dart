/// Pure Dart engine contracts for Algorun.
///
/// This library has **no Flutter dependency**. The UI may call these APIs;
/// this library must never import `package:flutter`.
library;

export 'src/ast/ir.dart';
export 'src/ast/lower.dart';
export 'src/blocks/block_graph.dart';
export 'src/blocks/catalog.dart';
export 'src/blocks/chrome.dart';
export 'src/blocks/commands.dart';
export 'src/blocks/definition.dart';
export 'src/blocks/ports.dart';
export 'src/blocks/structure.dart';
export 'src/blocks/typing.dart';
export 'src/execution/default_engine.dart';
export 'src/execution/engine.dart';
export 'src/execution/interpreter.dart';
export 'src/execution/performance.dart';
export 'src/execution/result_kind.dart';
export 'src/execution/run_result.dart';
export 'src/execution/suite_result.dart';
export 'src/puzzles/parse.dart';
export 'src/puzzles/puzzle.dart';
export 'src/puzzles/world.dart';
export 'src/runner/benchmark.dart';
export 'src/runner/test_runner.dart';
export 'src/runner/validators.dart';
export 'src/runtime/limits.dart';
export 'src/runtime/runtime_value.dart';
export 'src/runtime/value_json.dart';
export 'src/types/parse_type.dart';
export 'src/types/value_type.dart';
export 'src/validation/validation_report.dart';
