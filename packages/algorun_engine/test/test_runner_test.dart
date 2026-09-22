import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Puzzle _puzzle({
  String validator = 'equal',
  String inputs = '[{ "name": "nums", "type": "array<num>" }]',
  String output = 'num',
  String visible = '[{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }]',
  String hidden = '[{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]',
  String limits = '{ "maxOps": 10000, "maxDepth": 32, "maxAlloc": 1000 }',
  String allow = '["ctrl.return", "arr.len", "var.get"]',
}) {
  return parsePuzzleJson('''
{
  "id": "runner_probe",
  "title": "Runner probe",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "s",
  "io": {
    "inputs": $inputs,
    "output": { "type": "$output" }
  },
  "blocks": { "allow": $allow },
  "limits": $limits,
  "validators": { "output": "$validator" },
  "fixtures": {
    "visible": $visible,
    "hidden": $hidden
  }
}
''');
}

final _numArray = ValueType.array(ValueType.number);

Expr _n(num value) => LitExpr(value, type: ValueType.number);

Program _main(List<Stmt> body, {List<Param> params = const []}) {
  return Program(functions: [FnDecl(name: 'main', params: params, body: body)]);
}

/// `return LENGTH OF nums` — correct for every fixture below.
Program _returnLength() {
  return _main(
    [
      ReturnStmt(
        value: CallExpr(
          BlockIds.arrLen,
          [VarExpr('nums', type: _numArray, srcBlockId: 'nums1')],
          type: ValueType.number,
          srcBlockId: 'len1',
        ),
        srcBlockId: 'ret1',
      ),
    ],
    params: [Param('nums', _numArray)],
  );
}

/// `return <value>` — the same answer whatever the fixture says.
Program _returnConstant(num value) {
  return _main(
    [ReturnStmt(value: _n(value), srcBlockId: 'ret1')],
    params: [Param('nums', _numArray)],
  );
}

Program _readOutOfRange() {
  return _main(
    [
      ReturnStmt(
        value: IndexExpr(
          VarExpr('nums', type: _numArray),
          _n(5),
          type: ValueType.number,
          srcBlockId: 'get1',
        ),
      ),
    ],
    params: [Param('nums', _numArray)],
  );
}

Program _spin() {
  return _main([
    WhileStmt(
      cond: LitExpr(true, type: ValueType.boolean),
      body: const [],
      srcBlockId: 'while1',
    ),
  ]);
}

Program _growForever() {
  return _main([
    AssignStmt(
      target: const VarLValue('a'),
      value: NewExpr(CollKind.array, type: _numArray, srcBlockId: 'new1'),
      srcBlockId: 'set1',
    ),
    ForRangeStmt(
      loopVar: 'i',
      start: _n(0),
      end: _n(1000),
      srcBlockId: 'for1',
      body: [
        ExprStmt(CallExpr(
          BlockIds.arrAppend,
          [VarExpr('a', type: _numArray), VarExpr('i', type: ValueType.number)],
          type: ValueType.voidType,
          srcBlockId: 'app1',
        )),
      ],
    ),
    ReturnStmt(value: _n(0)),
  ]);
}

Program _recurseForever() {
  return Program(functions: [
    const FnDecl(
      name: 'main',
      params: [],
      body: [
        ReturnStmt(
          value: CallExpr(
            'deep',
            [LitExpr(1, type: ValueType.number)],
            type: ValueType.number,
          ),
        ),
      ],
    ),
    const FnDecl(
      name: 'deep',
      params: [Param('n', ValueType.number)],
      srcBlockId: 'fn1',
      body: [
        ReturnStmt(
          value: CallExpr(
            'deep',
            [VarExpr('n', type: ValueType.number)],
            type: ValueType.number,
          ),
        ),
      ],
    ),
  ]);
}

/// Builds a list from `values` and returns it.
Program _returnBuiltList(List<num> values) {
  return _main([
    AssignStmt(
      target: const VarLValue('a'),
      value: NewExpr(CollKind.array, type: _numArray),
    ),
    for (final value in values)
      ExprStmt(CallExpr(
        BlockIds.arrAppend,
        [VarExpr('a', type: _numArray), _n(value)],
        type: ValueType.voidType,
      )),
    ReturnStmt(value: VarExpr('a', type: _numArray)),
  ]);
}

/// Appends 99 to the given list, then returns its length. Used to prove one
/// case cannot leak into the next.
Program _appendThenLength() {
  return _main(
    [
      ExprStmt(CallExpr(
        BlockIds.arrAppend,
        [VarExpr('nums', type: _numArray), _n(99)],
        type: ValueType.voidType,
      )),
      ReturnStmt(
        value: CallExpr(
          BlockIds.arrLen,
          [VarExpr('nums', type: _numArray)],
          type: ValueType.number,
        ),
      ),
    ],
    params: [Param('nums', _numArray)],
  );
}

void main() {
  const engine = DefaultEngine();
  const runner = TestRunner();

  group('grading', () {
    test('every visible and hidden case passes', () {
      final suite = runner.run(_returnLength(), _puzzle());
      expect(suite.kind, ResultKind.correct);
      expect(suite.ok, isTrue);
      expect(suite.message, 'Every case passed.');
      expect(suite.visible.single.id, 'v1');
      expect(suite.visible.single.ok, isTrue);
      expect(suite.hiddenSummary!.passed, 1);
      expect(suite.hiddenSummary!.total, 1);
      expect(suite.firstFailureBlockId, isNull);
      expect(suite.firstFailureCaseId, isNull);
      expect(suite.metrics.blocks, 3);
      expect(suite.metrics.hintsUsed, 0);
      expect(suite.metrics.ops, greaterThan(0));
    });

    test('a visible wrong answer names the case and shows both sides', () {
      final suite = runner.run(_returnConstant(99), _puzzle());
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.firstFailureCaseId, 'v1');
      expect(suite.message, contains('v1'));
      final failed = suite.visible.single;
      expect(failed.ok, isFalse);
      expect(failed.input, {'nums': [1, 2, 3]});
      expect(failed.expected, 3);
      expect(failed.actual, 99);
    });

    test('a hidden failure stays a summary', () {
      // Correct for the visible case, wrong for the hidden one.
      final suite = runner.run(_returnConstant(3), _puzzle());
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible.single.ok, isTrue);
      expect(suite.hiddenSummary!.passed, 0);
      expect(suite.hiddenSummary!.total, 1);
      expect(suite.firstFailureCaseId, isNull);
      expect(suite.message, 'A hidden case did not come out the way the puzzle expects.');
      expect(suite.message, isNot(contains('h1')));
      expect(suite.visible.every((c) => c.visible), isTrue);
    });

    test('hidden payloads never leave the engine', () {
      final suite = runner.run(_returnLength(), _puzzle());
      expect(suite.visible.map((c) => c.id), ['v1']);
      for (final c in suite.visible) {
        expect(c.visible, isTrue);
      }
      // The summary carries counts and nothing else.
      expect(suite.hiddenSummary!.allPassed, isTrue);
    });

    test('a puzzle with no checker the game knows is invalid', () {
      final suite = runner.run(_returnLength(), _puzzle(validator: 'bogus'));
      expect(suite.kind, ResultKind.invalidProgram);
      expect(suite.message, 'This puzzle does not have a checker the game knows.');
      expect(suite.visible, isEmpty);
    });
  });

  group('failures come from the interpreter', () {
    test('a runtime failure carries its message, block and op index', () {
      final suite = runner.run(_readOutOfRange(), _puzzle());
      expect(suite.kind, ResultKind.runtimeError);
      expect(suite.message, 'That position is outside the list.');
      expect(suite.firstFailureBlockId, 'get1');
      expect(suite.firstFailureOpIndex, greaterThan(0));
      expect(suite.firstFailureCaseId, 'v1');
    });

    test('the operation budget stops the suite', () {
      final suite = runner.run(
        _spin(),
        _puzzle(limits: '{ "maxOps": 50, "maxDepth": 32, "maxAlloc": 1000 }'),
      );
      expect(suite.kind, ResultKind.operationLimit);
      expect(suite.message, 'This program took too many steps.');
      expect(suite.metrics.ops, 50);
    });

    test('the memory budget stops the suite', () {
      final suite = runner.run(
        _growForever(),
        _puzzle(limits: '{ "maxOps": 100000, "maxDepth": 32, "maxAlloc": 10 }'),
      );
      expect(suite.kind, ResultKind.memoryLimit);
      expect(suite.message, 'This program used too much memory.');
      expect(suite.metrics.peakAlloc, 10);
    });

    test('the depth budget stops the suite', () {
      final suite = runner.run(
        _recurseForever(),
        _puzzle(limits: '{ "maxOps": 100000, "maxDepth": 8, "maxAlloc": 1000 }'),
      );
      expect(suite.kind, ResultKind.depthLimit);
      expect(suite.message, 'This program went too many levels deep.');
      expect(suite.metrics.peakDepth, 8);
    });

    test('a program that cannot start is invalid, not wrong', () {
      final suite = runner.run(Program.empty, _puzzle());
      expect(suite.kind, ResultKind.invalidProgram);
      expect(suite.message, 'This program has no starting point.');
    });
  });

  group('comparators', () {
    test('unorderedArray accepts a permutation through the runner', () {
      final puzzle = _puzzle(
        validator: 'unorderedArray',
        output: 'array<num>',
        visible: '[{ "id": "v1", "in": { "nums": [0] }, "out": [0, 1] }]',
        hidden: '[{ "id": "h1", "in": { "nums": [0] }, "out": [1, 0] }]',
      );
      final suite = runner.run(_returnBuiltList([1, 0]), puzzle);
      expect(suite.kind, ResultKind.correct);
      expect(suite.hiddenSummary!.passed, 1);
    });

    test('equal rejects the same permutation', () {
      final puzzle = _puzzle(
        output: 'array<num>',
        visible: '[{ "id": "v1", "in": { "nums": [0] }, "out": [0, 1] }]',
        hidden: '[{ "id": "h1", "in": { "nums": [0] }, "out": [0, 1] }]',
      );
      final suite = runner.run(_returnBuiltList([1, 0]), puzzle);
      expect(suite.kind, ResultKind.wrongAnswer);
      expect(suite.visible.single.actual, [1, 0]);
      expect(suite.visible.single.expected, [0, 1]);
    });

    test('equal is strict about shape', () {
      expect(
        valuesEqual(valueFromJson([1, 2]), ListNodeValue(1, next: ListNodeValue(2))),
        isFalse,
      );
      expect(valuesEqual(valueFromJson([1, 2]), valueFromJson([1, 2])), isTrue);
    });

    test('listEqualByValue matches a linked list against fixture values', () {
      final chain = ListNodeValue(1, next: ListNodeValue(2, next: ListNodeValue(3)));
      expect(
        compareOutputs(ValidatorId.listEqualByValue, chain, valueFromJson([1, 2, 3])),
        isTrue,
      );
      expect(
        compareOutputs(ValidatorId.listEqualByValue, chain, valueFromJson([1, 3, 2])),
        isFalse,
      );
    });

    test('listEqualByValue survives a cycle instead of hanging', () {
      final second = ListNodeValue(2);
      final first = ListNodeValue(1, next: second);
      second.next = first;
      expect(
        compareOutputs(ValidatorId.listEqualByValue, first, valueFromJson([1, 2])),
        isTrue,
      );
    });

    test('treeEqual compares a runtime tree with a fixture object', () {
      final tree = TreeNodeValue(
        2,
        left: TreeNodeValue(1),
        right: TreeNodeValue(3),
      );
      final expected = valueFromJson({
        'value': 2,
        'left': {'value': 1, 'left': null, 'right': null},
        'right': {'value': 3, 'left': null, 'right': null},
      });
      expect(compareOutputs(ValidatorId.treeEqual, tree, expected), isTrue);
      final mirrored = TreeNodeValue(
        2,
        left: TreeNodeValue(3),
        right: TreeNodeValue(1),
      );
      expect(compareOutputs(ValidatorId.treeEqual, mirrored, expected), isFalse);
    });

    test('setEqual ignores order and repeats', () {
      expect(
        compareOutputs(
          ValidatorId.setEqual,
          valueFromJson([2, 1, 2]),
          valueFromJson([1, 2]),
        ),
        isTrue,
      );
      expect(
        compareOutputs(
          ValidatorId.setEqual,
          valueFromJson([1, 3]),
          valueFromJson([1, 2]),
        ),
        isFalse,
      );
    });

    test('unorderedPairs ignores order inside a pair', () {
      expect(
        compareOutputs(
          ValidatorId.unorderedPairs,
          valueFromJson([
            [1, 0],
          ]),
          valueFromJson([
            [0, 1],
          ]),
        ),
        isTrue,
      );
      expect(
        compareOutputs(
          ValidatorId.unorderedPairs,
          valueFromJson([
            [1, 2],
          ]),
          valueFromJson([
            [0, 1],
          ]),
        ),
        isFalse,
      );
    });

    test('the registry covers every validator id', () {
      expect(outputValidators.keys.toSet(), ValidatorId.values.toSet());
    });
  });

  group('isolation', () {
    test('one case cannot leak into the next', () {
      final puzzle = _puzzle(
        visible: '''[
          { "id": "v1", "in": { "nums": [1, 2] }, "out": 3 },
          { "id": "v2", "in": { "nums": [1, 2, 3] }, "out": 4 }
        ]''',
        hidden: '[{ "id": "h1", "in": { "nums": [7] }, "out": 2 }]',
      );
      final suite = runner.run(_appendThenLength(), puzzle);
      expect(suite.kind, ResultKind.correct);
      expect(suite.visible.map((c) => c.actual), [3, 4]);
      expect(suite.hiddenSummary!.passed, 1);
    });

    test('a run cannot mutate the fixtures', () {
      final puzzle = _puzzle(
        visible: '[{ "id": "v1", "in": { "nums": [1, 2] }, "out": 3 }]',
        hidden: '[{ "id": "h1", "in": { "nums": [7] }, "out": 2 }]',
      );
      runner.run(_appendThenLength(), puzzle);
      expect(puzzle.visibleTests.single.input['nums'], [1, 2]);
      expect(puzzle.hiddenTests.single.input['nums'], [7]);
      // And a second suite sees the same fixtures.
      final again = runner.run(_appendThenLength(), puzzle);
      expect(again.kind, ResultKind.correct);
    });

    test('repeated runs give the same verdict and the same metrics', () {
      final puzzle = _puzzle();
      final first = runner.run(_returnLength(), puzzle);
      final second = runner.run(_returnLength(), puzzle);
      expect(first.kind, second.kind);
      expect(first.metrics.ops, second.metrics.ops);
      expect(first.metrics.peakAlloc, second.metrics.peakAlloc);
      expect(first.metrics.blocks, second.metrics.blocks);
      expect(
        first.visible.map((c) => c.actual),
        second.visible.map((c) => c.actual),
      );
    });

    test('a Program that made a round trip through JSON grades the same', () {
      final puzzle = _puzzle();
      final program = _returnLength();
      final restored = Program.fromJsonString(program.toJsonString());
      final direct = runner.run(program, puzzle);
      final roundTripped = runner.run(restored, puzzle);
      expect(roundTripped.kind, direct.kind);
      expect(roundTripped.metrics.ops, direct.metrics.ops);
      expect(roundTripped.metrics.blocks, direct.metrics.blocks);
      expect(
        roundTripped.visible.map((c) => c.actual),
        direct.visible.map((c) => c.actual),
      );
    });

    test('runCases grades exactly the cases it is handed', () {
      final puzzle = _puzzle();
      final suite = runner.runCases(
        _returnLength(),
        puzzle,
        puzzle.visibleTests,
      );
      expect(suite.kind, ResultKind.correct);
      expect(suite.visible, hasLength(1));
      expect(suite.hiddenSummary, isNull);
    });
  });

  group('pipeline', () {
    test('graph → validate → lower → runTests', () {
      final puzzle = _puzzle();
      final history = GraphHistory(
        BlockGraph(blocks: const {}, variables: {'nums': _numArray}),
      );
      for (final add in [
        AddBlockCommand(catalogId: BlockIds.ctrlReturn, id: 'ret1'),
        AddBlockCommand(catalogId: BlockIds.arrLen, id: 'len1'),
        AddBlockCommand(
          catalogId: BlockIds.varGet,
          id: 'nums1',
          literals: const {'name': 'nums'},
        ),
      ]) {
        expect(history.apply(add).ok, isTrue);
      }
      expect(
        history.apply(AttachStatementCommand(
          blockId: 'ret1',
          to: PortRef.mainBody,
        )).ok,
        isTrue,
      );
      expect(
        history.apply(ConnectCommand(
          from: PortRef('len1', 'out'),
          to: PortRef('ret1', 'value'),
        )).ok,
        isTrue,
      );
      expect(
        history.apply(ConnectCommand(
          from: PortRef('nums1', 'out'),
          to: PortRef('len1', 'array'),
        )).ok,
        isTrue,
      );

      expect(engine.validate(history.current, puzzle).ok, isTrue);
      final lowered = engine.lower(history.current, puzzle);
      expect(lowered.ok, isTrue, reason: '${lowered.errors}');

      final suite = engine.runTests(lowered.program!, puzzle);
      expect(suite.kind, ResultKind.correct);
      expect(suite.visible.single.actual, 3);
      expect(suite.hiddenSummary!.passed, 1);
      expect(suite.metrics.blocks, 3);
      expect(suite.metrics.ops, lessThanOrEqualTo(puzzle.limits.maxOps));
    });
  });
}
