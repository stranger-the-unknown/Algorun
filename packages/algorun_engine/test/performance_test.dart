import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

final _nums = ValueType.array(ValueType.number);

Puzzle _puzzle({
  String limits = '{ "maxOps": 1000000 }',
  String visible = '[{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }]',
  String hidden = '[{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]',
  String inputs = '[{ "name": "nums", "type": "array<num>" }]',
}) =>
    parsePuzzleJson('''
{
  "id": "perf_probe", "title": "Perf", "world": "world_01", "tier": 1, "mode": "optimize",
  "story": "Count the numbers.",
  "io": { "inputs": $inputs, "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "arr.len", "var.get"] },
  "limits": $limits,
  "fixtures": { "visible": $visible, "hidden": $hidden }
}
''');

String _list(int n) => '[${List.filled(n, 1).join(', ')}]';

Program _main(List<Stmt> body, {List<Param>? params}) => Program(functions: [
      FnDecl(name: 'main', params: params ?? [Param('nums', _nums)], body: body),
    ]);

Expr _n(num v) => LitExpr(v, type: ValueType.number);
Expr _v(String name, [ValueType type = ValueType.number]) => VarExpr(name, type: type);
Expr _len() => CallExpr(BlockIds.arrLen, [_v('nums', _nums)], type: ValueType.number);
Expr _add(Expr a, Expr b) => BinaryExpr(BinaryOp.add, a, b, type: ValueType.number);

/// `return LENGTH OF nums`: 3 operations whatever the input.
Program _linear() => _main([ReturnStmt(value: _len())]);

/// Counts the list one item at a time: the same answer, more operations.
Program _counting() => _main([
      AssignStmt(target: const VarLValue('c'), value: _n(0)),
      ForRangeStmt(
        loopVar: 'i',
        start: _n(0),
        end: _len(),
        body: [AssignStmt(target: const VarLValue('c'), value: _add(_v('c'), _n(1)))],
      ),
      ReturnStmt(value: _v('c')),
    ]);

/// The same answer again, with a nested loop: quadratic in the list length.
Program _quadratic() => _main([
      AssignStmt(target: const VarLValue('c'), value: _n(0)),
      ForRangeStmt(loopVar: 'i', start: _n(0), end: _len(), body: [
        ForRangeStmt(loopVar: 'j', start: _n(0), end: _len(), body: [
          IfStmt(
            cond: BinaryExpr(BinaryOp.eq, _v('j'), _n(0), type: ValueType.boolean),
            thenBody: [AssignStmt(target: const VarLValue('c'), value: _add(_v('c'), _n(1)))],
          ),
        ]),
      ]),
      ReturnStmt(value: _v('c')),
    ]);

/// Slow and wrong: loops like [_counting], then answers one too many.
Program _slowAndWrong() => _main([
      ..._counting().functions.single.body.take(2),
      ReturnStmt(value: _add(_v('c'), _n(1))),
    ]);

const _runner = TestRunner();

void main() {
  group('the operation model is unchanged', () {
    test('LENGTH OF costs exactly three operations per case', () {
      final suite = _runner.run(_linear(), _puzzle());
      expect(suite.metrics.ops, 3);
      expect(suite.performance!.worstOps, 3);
    });

    test('a budget of exactly the cost passes; one less fails', () {
      final exact = _runner.run(_linear(), _puzzle(limits: '{ "maxOps": 3 }'));
      expect(exact.kind, ResultKind.correct);
      final short = _runner.run(_linear(), _puzzle(limits: '{ "maxOps": 2 }'));
      expect(short.kind, ResultKind.operationLimit);
      // MS6 semantics: the budgeted run stops at the budget, same message.
      expect(short.metrics.ops, 2);
      expect(short.message, 'This program took too many steps.');
    });

    test('metrics are identical on every repeat', () {
      final puzzle = _puzzle(hidden: '[{ "id": "h1", "in": { "nums": ${_list(40)} }, "out": 40 }]');
      final first = _runner.run(_counting(), puzzle);
      for (var i = 0; i < 5; i++) {
        final again = _runner.run(_counting(), puzzle);
        expect(again.metrics.ops, first.metrics.ops);
        expect(again.metrics.peakAlloc, first.metrics.peakAlloc);
        expect(again.metrics.peakDepth, first.metrics.peakDepth);
        expect(again.metrics.blocks, first.metrics.blocks);
        expect(again.performance!.worstOps, first.performance!.worstOps);
      }
    });

    test('a Program read back from JSON costs the same', () {
      final puzzle = _puzzle(hidden: '[{ "id": "h1", "in": { "nums": ${_list(25)} }, "out": 25 }]');
      final restored = Program.fromJsonString(_quadratic().toJsonString());
      final a = benchmark(_quadratic(), puzzle);
      final b = benchmark(restored, puzzle);
      expect([for (final s in b.samples) s.ops], [for (final s in a.samples) s.ops]);
      expect(_runner.run(restored, puzzle).metrics.ops, _runner.run(_quadratic(), puzzle).metrics.ops);
    });
  });

  group('memory and depth budgets', () {
    Program collect() => _main([
          AssignStmt(target: const VarLValue('a'), value: NewExpr(CollKind.array, type: _nums)),
          ForEachStmt(itemVar: 'x', collection: _v('nums', _nums), body: [
            ExprStmt(CallExpr(BlockIds.arrAppend, [_v('a', _nums), _v('x')], type: ValueType.voidType)),
          ]),
          ReturnStmt(value: CallExpr(BlockIds.arrLen, [_v('a', _nums)], type: ValueType.number)),
        ]);

    test('a list of three plus its container fits four cells, not three', () {
      final fits = _runner.run(collect(), _puzzle(limits: '{ "maxOps": 1000, "maxAlloc": 4 }'));
      expect(fits.kind, ResultKind.correct);
      expect(fits.metrics.peakAlloc, 4);
      final over = _runner.run(collect(), _puzzle(limits: '{ "maxOps": 1000, "maxAlloc": 3 }'));
      expect(over.kind, ResultKind.memoryLimit);
      expect(over.performance!.withinBudget, isTrue, reason: 'memory is not an operation overrun');
    });

    Program recurse() => Program(functions: [
          FnDecl(name: 'main', params: [Param('n', ValueType.number)], body: [
            ReturnStmt(value: CallExpr('down', [_v('n')], type: ValueType.number)),
          ]),
          FnDecl(name: 'down', params: [Param('n', ValueType.number)], body: [
            IfStmt(
              cond: BinaryExpr(BinaryOp.gt, _v('n'), _n(0), type: ValueType.boolean),
              thenBody: [
                ReturnStmt(
                  value: CallExpr(
                    'down',
                    [BinaryExpr(BinaryOp.sub, _v('n'), _n(1), type: ValueType.number)],
                    type: ValueType.number,
                  ),
                ),
              ],
            ),
            ReturnStmt(value: _n(0)),
          ]),
        ]);

    Puzzle depthPuzzle(int maxDepth) => _puzzle(
          inputs: '[{ "name": "n", "type": "num" }]',
          limits: '{ "maxOps": 1000, "maxDepth": $maxDepth }',
          visible: '[{ "id": "v1", "in": { "n": 3 }, "out": 0 }]',
          hidden: '[{ "id": "h1", "in": { "n": 1 }, "out": 0 }]',
        );

    test('recursion three deep needs five frames: five fits, four does not', () {
      final fits = _runner.run(recurse(), depthPuzzle(5));
      expect(fits.kind, ResultKind.correct);
      expect(fits.metrics.peakDepth, 5);
      final over = _runner.run(recurse(), depthPuzzle(4));
      expect(over.kind, ResultKind.depthLimit);
    });
  });

  group('correct but too slow', () {
    test('a correct solution over budget is measured, not just stopped', () {
      // 10 items: the counting loop needs 2 + 4 + 10 * 5 + 2 = 58 operations;
      // the budget is 40.
      final puzzle = _puzzle(
        limits: '{ "maxOps": 40 }',
        visible: '[{ "id": "v1", "in": { "nums": ${_list(10)} }, "out": 10 }]',
        hidden: '[{ "id": "h1", "in": { "nums": [5] }, "out": 1 }]',
      );
      final suite = _runner.run(_counting(), puzzle);
      expect(suite.kind, ResultKind.operationLimit, reason: 'the verdict is unchanged');
      expect(suite.metrics.ops, 40, reason: 'MS6 metrics stay the budgeted run');

      final perf = suite.performance!;
      expect(perf.overBudgetCases, 1);
      expect(perf.overBudgetFinished, isTrue);
      expect(perf.correctWhereFinished, isTrue);
      expect(perf.correctButOverBudget, isTrue);
      expect(perf.worstOps, 58);
      expect(perf.worstOverrun!.budget, 40);
      expect(perf.worstOverrun!.measuredOps, 58);

      final visible = suite.visible.single;
      expect(visible.overrun!.finished, isTrue);
      expect(visible.overrun!.outputCorrect, isTrue);
      expect(visible.overrun!.ceiling, overrunCeiling(40));
    });

    test('slow and wrong is told apart from slow and right', () {
      final puzzle = _puzzle(
        limits: '{ "maxOps": 40 }',
        visible: '[{ "id": "v1", "in": { "nums": ${_list(10)} }, "out": 10 }]',
      );
      final perf = _runner.run(_slowAndWrong(), puzzle).performance!;
      expect(perf.overBudgetFinished, isTrue);
      expect(perf.correctWhereFinished, isFalse);
      expect(perf.correctButOverBudget, isFalse);
      expect(perf.worstOverrun!.outputCorrect, isFalse);
    });

    test('far over budget stops at the measurement ceiling', () {
      final puzzle = _puzzle(
        limits: '{ "maxOps": 40 }',
        hidden: '[{ "id": "h1", "in": { "nums": ${_list(60)} }, "out": 60 }]',
      );
      final perf = _runner.run(_quadratic(), puzzle).performance!;
      expect(perf.overBudgetFinished, isFalse);
      expect(perf.worstOps, overrunCeiling(40));
      expect(perf.worstOverrun!.finished, isFalse);
      expect(perf.worstOverrun!.outputCorrect, isNull);
    });

    test('the measurement ceiling is five budgets, capped', () {
      expect(overrunCeiling(40), 200);
      expect(overrunCeiling(60000), 300000);
      expect(overrunCeiling(1000000), 2000000);
    });
  });

  group('per-case budgets for large inputs', () {
    // The puzzle's budget is generous; the large case declares its own.
    Puzzle scaling() => _puzzle(
          limits: '{ "maxOps": 1000000 }',
          visible: '[{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }]',
          hidden: '[{ "id": "large", "in": { "nums": ${_list(200)} }, "out": 200, "maxOps": 5000 }]',
        );

    test('the large case turns away a quadratic solution', () {
      final suite = _runner.run(_quadratic(), scaling());
      expect(suite.kind, ResultKind.operationLimit);
      expect(suite.visible.single.ok, isTrue, reason: 'small inputs are fine');
      expect(suite.hiddenSummary!.passed, 0);
      expect(suite.performance!.worstOverrun!.budget, 5000);
    });

    test('the same large case accepts the linear solution', () {
      final suite = _runner.run(_linear(), scaling());
      expect(suite.kind, ResultKind.correct);
      expect(suite.performance!.withinBudget, isTrue);
    });

    test('a case budget can only tighten the puzzle budget', () {
      final read = readPuzzleJson('''
{
  "id": "p", "title": "P", "world": "world_01", "tier": 1, "mode": "build", "story": "s",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return"] },
  "limits": { "maxOps": 100 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [] }, "out": 0, "maxOps": 500 }],
    "hidden": [{ "id": "h1", "in": { "nums": [] }, "out": 0 }]
  }
}
''');
      expect(read.ok, isFalse);
      expect(read.issues.single.path, 'fixtures.visible[0].maxOps');
      expect(read.issues.single.message, contains('cannot exceed limits.maxOps'));
    });
  });

  group('isolation', () {
    test('a case costs the same alone, in the suite, and in any order', () {
      final puzzle = _puzzle(
        visible: '[{ "id": "v1", "in": { "nums": ${_list(7)} }, "out": 7 }]',
        hidden: '[{ "id": "h1", "in": { "nums": ${_list(30)} }, "out": 30 }, '
            '{ "id": "h2", "in": { "nums": [] }, "out": 0 }]',
      );
      final together = {for (final s in benchmark(_counting(), puzzle).samples) s.caseId: s.ops};
      final reversed = {
        for (final s in benchmark(_counting(), puzzle, cases: puzzle.allTests.reversed.toList()).samples)
          s.caseId: s.ops,
      };
      expect(reversed, together);
      for (final testCase in puzzle.allTests) {
        final alone = benchmark(_counting(), puzzle, cases: [testCase]).samples.single;
        expect(alone.ops, together[testCase.id]);
      }
      expect(together['h1'], greaterThan(together['v1']!));
    });
  });

  group('benchmark', () {
    Puzzle sized() => _puzzle(
          limits: '{ "maxOps": 100000 }',
          visible: '[{ "id": "small", "in": { "nums": ${_list(10)} }, "out": 10 }]',
          hidden: '[{ "id": "medium", "in": { "nums": ${_list(40)} }, "out": 40 }, '
              '{ "id": "large", "in": { "nums": ${_list(160)} }, "out": 160, "maxOps": 2000 }]',
        );

    test('samples carry size, cost and budget checks, deterministically', () {
      final report = benchmark(_counting(), sized());
      expect([for (final s in report.samples) s.caseId], ['small', 'medium', 'large']);
      expect([for (final s in report.samples) s.inputSize], [10, 40, 160]);
      expect(report.samples.every((s) => s.finished), isTrue);
      expect(report.samples[1].ops, greaterThan(report.samples[0].ops));
      expect(report.checks.last.maxOps, 2000);
      expect(report.checks.last.passed, isTrue);
      expect(report.passed, isTrue);

      final again = benchmark(_counting(), sized());
      expect([for (final s in again.samples) s.ops], [for (final s in report.samples) s.ops]);
    });

    test('a failed budget check shows in the report', () {
      final report = benchmark(_quadratic(), sized());
      expect(report.passed, isFalse);
      final large = report.checks.singleWhere((c) => c.caseId == 'large');
      expect(large.passed, isFalse);
      expect(large.ops, greaterThan(2000));
    });

    test('input size counts collections, not scalars', () {
      final testCase = TestCase(
        id: 'x',
        input: {
          'nums': valueFromJson([1, 2, 3]),
          'k': const NumValue(9),
          'g': valueFromJson({
            'type': 'graph',
            'nodes': [
              {'id': 0},
              {'id': 1},
            ],
          }),
          'l': valueFromJson({'type': 'listNode', 'values': [4, 5]}),
        },
        output: const NilValue(),
      );
      expect(inputSize(testCase), 3 + 0 + 2 + 2);
    });
  });
}
