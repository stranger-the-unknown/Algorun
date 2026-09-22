import '../ast/ir.dart';
import '../execution/interpreter.dart';
import '../execution/result_kind.dart';
import '../execution/run_result.dart';
import '../execution/suite_result.dart';
import '../puzzles/puzzle.dart';
import '../runtime/limits.dart';
import '../runtime/runtime_value.dart';
import 'validators.dart';

/// Runs a lowered [Program] against a puzzle's fixtures and grades it.
///
/// Pipeline: `Program → interpreter → test cases → named validator →
/// SuiteResult`.
///
/// Every case gets a fresh interpreter and freshly decoded input, so one case
/// can never see another's state. Failures are the interpreter's own
/// structured results; the runner adds only `wrongAnswer`.
///
/// Hidden fixtures never leave the engine: they are counted, never listed.
final class TestRunner {
  const TestRunner();

  /// Grade every fixture of [puzzle], visible first.
  SuiteResult run(Program program, Puzzle puzzle) {
    return runCases(program, puzzle, puzzle.allTests);
  }

  /// Grade a given list of cases. This is the seam a future generator plugs
  /// into: it hands over plain [TestCase] data, never executable content.
  SuiteResult runCases(Program program, Puzzle puzzle, List<TestCase> cases) {
    final ValidatorId validator;
    try {
      validator = parseValidatorId(puzzle.outputValidator);
    } on FormatException {
      return SuiteResult(
        kind: ResultKind.invalidProgram,
        visible: const [],
        metrics: RunMetrics(blocks: countBlocks(program)),
        message: 'This puzzle does not have a checker the game knows.',
      );
    }

    final limits = puzzle.limits.asLimits;
    final visible = <CaseResult>[];
    var hiddenPassed = 0;
    var hiddenTotal = 0;
    var worstOps = 0;
    var worstAlloc = 0;
    var worstDepth = 0;

    ResultKind? failureKind;
    String? failureMessage;
    String? failureBlockId;
    int? failureOpIndex;
    String? failureCaseId;

    for (final testCase in cases) {
      final result = _runCase(program, puzzle, testCase, validator, limits);
      final metrics = result.run.metrics;
      if (metrics.ops > worstOps) worstOps = metrics.ops;
      if (metrics.peakAlloc > worstAlloc) worstAlloc = metrics.peakAlloc;
      if (metrics.peakDepth > worstDepth) worstDepth = metrics.peakDepth;

      if (testCase.visible) {
        visible.add(result);
      } else {
        hiddenTotal++;
        if (result.ok) hiddenPassed++;
      }

      if (!result.ok && failureKind == null) {
        failureKind = result.run.kind;
        failureBlockId = result.run.blockId;
        failureOpIndex = metrics.ops;
        // A hidden case never names itself, and never explains what it fed in.
        failureCaseId = testCase.visible ? testCase.id : null;
        failureMessage = _failureMessage(result.run, testCase);
      }
    }

    return SuiteResult(
      kind: failureKind ?? ResultKind.correct,
      visible: visible,
      hiddenSummary: hiddenTotal == 0
          ? null
          : HiddenSummary(passed: hiddenPassed, total: hiddenTotal),
      metrics: RunMetrics(
        ops: worstOps,
        peakAlloc: worstAlloc,
        peakDepth: worstDepth,
        blocks: countBlocks(program),
      ),
      message: failureMessage ??
          (cases.isEmpty
              ? 'This puzzle has no test cases.'
              : 'Every case passed.'),
      firstFailureBlockId: failureBlockId,
      firstFailureOpIndex: failureOpIndex,
      firstFailureCaseId: failureCaseId,
    );
  }

  CaseResult _runCase(
    Program program,
    Puzzle puzzle,
    TestCase testCase,
    ValidatorId validator,
    RunLimits limits,
  ) {
    // Fresh values per case. The interpreter also copies what it is given, so
    // neither the fixture data nor another case can be reached from here.
    final input = <String, RuntimeValue>{};
    for (final binding in puzzle.io.inputs) {
      if (testCase.input.containsKey(binding.name)) {
        input[binding.name] = valueFromJson(testCase.input[binding.name]);
      }
    }

    final run = runProgram(program, input, limits);
    final graded = run.kind == ResultKind.correct
        ? _grade(run, testCase, validator)
        : run;
    return CaseResult(
      id: testCase.id,
      visible: testCase.visible,
      run: graded,
      input: testCase.visible ? Map<String, Object?>.from(testCase.input) : null,
      expected: testCase.visible ? testCase.output : null,
      actual: testCase.visible ? run.output?.toJson() : null,
    );
  }

  RunResult _grade(RunResult run, TestCase testCase, ValidatorId validator) {
    final expected = valueFromJson(testCase.output);
    final actual = run.output ?? const NilValue();
    if (compareOutputs(validator, actual, expected)) return run;
    return RunResult(
      kind: ResultKind.wrongAnswer,
      metrics: run.metrics,
      output: run.output,
      message: 'This case did not come out the way the puzzle expects.',
    );
  }

  String _failureMessage(RunResult run, TestCase testCase) {
    if (run.kind == ResultKind.wrongAnswer) {
      return testCase.visible
          ? 'Case ${testCase.id} did not come out the way the puzzle expects.'
          : 'A hidden case did not come out the way the puzzle expects.';
    }
    // Every other failure is the interpreter's own game-facing message.
    return run.message ?? run.kind.label;
  }
}

/// How many blocks the program is made of: distinct `srcBlockId`s in the IR.
/// Blocks that lowering folded away (an `else` clause joins its `if`) are not
/// counted twice.
int countBlocks(Program program) {
  final ids = <String>{};
  void addId(String? id) {
    if (id != null) ids.add(id);
  }

  void walkExpr(Expr expr) {
    addId(expr.srcBlockId);
    switch (expr) {
      case LitExpr() || VarExpr() || NullExpr():
        break;
      case final BinaryExpr e:
        walkExpr(e.left);
        walkExpr(e.right);
      case final UnaryExpr e:
        walkExpr(e.arg);
      case final CallExpr e:
        for (final arg in e.args) {
          walkExpr(arg);
        }
      case final IndexExpr e:
        walkExpr(e.collection);
        walkExpr(e.index);
      case final FieldExpr e:
        walkExpr(e.object);
      case final NewExpr e:
        for (final arg in e.args) {
          walkExpr(arg);
        }
    }
  }

  void walkTarget(LValue target) {
    addId(target.srcBlockId);
    switch (target) {
      case VarLValue():
        break;
      case final IndexLValue t:
        walkExpr(t.collection);
        walkExpr(t.index);
      case final FieldLValue t:
        walkExpr(t.object);
    }
  }

  void walkStmts(List<Stmt> body) {
    for (final stmt in body) {
      addId(stmt.srcBlockId);
      switch (stmt) {
        case final SeqStmt s:
          walkStmts(s.stmts);
        case final IfStmt s:
          walkExpr(s.cond);
          walkStmts(s.thenBody);
          walkStmts(s.elseBody ?? const []);
        case final WhileStmt s:
          walkExpr(s.cond);
          walkStmts(s.body);
        case final ForRangeStmt s:
          walkExpr(s.start);
          walkExpr(s.end);
          final step = s.step;
          if (step != null) walkExpr(step);
          walkStmts(s.body);
        case final ForEachStmt s:
          walkExpr(s.collection);
          walkStmts(s.body);
        case BreakStmt() || ContinueStmt():
          break;
        case final ReturnStmt s:
          final value = s.value;
          if (value != null) walkExpr(value);
        case final AssignStmt s:
          walkTarget(s.target);
          walkExpr(s.value);
        case final IncStmt s:
          walkTarget(s.target);
        case final DecStmt s:
          walkTarget(s.target);
        case final ExprStmt s:
          walkExpr(s.expr);
      }
    }
  }

  for (final fn in program.functions) {
    addId(fn.srcBlockId);
    walkStmts(fn.body);
  }
  return ids.length;
}
