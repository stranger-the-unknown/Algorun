import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Program _program(List<Stmt> body, {List<Param> params = const []}) {
  return Program(functions: [FnDecl(name: 'main', params: params, body: body)]);
}

Expr _n(num value, {String? src}) =>
    LitExpr(value, type: ValueType.number, srcBlockId: src);

Expr _bool(bool value) => LitExpr(value, type: ValueType.boolean);

Expr _get(String name, {ValueType type = ValueType.number, String? src}) =>
    VarExpr(name, type: type, srcBlockId: src);

Stmt _set(String name, Expr value, {String? src}) =>
    AssignStmt(target: VarLValue(name), value: value, srcBlockId: src);

Expr _add(Expr a, Expr b) => BinaryExpr(BinaryOp.add, a, b, type: ValueType.number);

Expr _lt(Expr a, Expr b) => BinaryExpr(BinaryOp.lt, a, b, type: ValueType.boolean);

Expr _len(Expr array, {String? src}) => CallExpr(
      BlockIds.arrLen,
      [array],
      type: ValueType.number,
      srcBlockId: src,
    );

Expr _nums(String name) => _get(name, type: ValueType.array(ValueType.number));

RunResult _run(
  Program program, {
  Map<String, RuntimeValue> input = const {},
  RunLimits limits = RunLimits.standard,
  TraceSink? trace,
}) {
  return const DefaultEngine().run(program, input, limits, trace: trace);
}

num _number(RunResult result) => (result.output as NumValue).value;

void main() {
  group('control flow', () {
    test('returns a given value', () {
      final result = _run(
        _program(
          [ReturnStmt(value: _get('x'))],
          params: [Param('x', ValueType.number)],
        ),
        input: {'x': const NumValue(7)},
      );
      expect(result.kind, ResultKind.correct);
      expect(_number(result), 7);
    });

    test('a program with no return ends empty', () {
      final result = _run(_program([_set('x', _n(1))]));
      expect(result.kind, ResultKind.correct);
      expect(result.output, isA<NilValue>());
    });

    test('for-range sums a list', () {
      final program = _program(
        [
          _set('total', _n(0)),
          ForRangeStmt(
            loopVar: 'i',
            start: _n(0),
            end: _len(_nums('nums')),
            body: [
              _set(
                'total',
                _add(
                  _get('total'),
                  IndexExpr(_nums('nums'), _get('i'), type: ValueType.number),
                ),
              ),
            ],
          ),
          ReturnStmt(value: _get('total')),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final result = _run(program, input: {'nums': valueFromJson([1, 2, 3, 4])});
      expect(result.kind, ResultKind.correct);
      expect(_number(result), 10);
    });

    test('for-range counts down with a negative step', () {
      final result = _run(_program([
        _set('total', _n(0)),
        ForRangeStmt(
          loopVar: 'i',
          start: _n(5),
          end: _n(0),
          step: _n(-1),
          body: [_set('total', _add(_get('total'), _get('i')))],
        ),
        ReturnStmt(value: _get('total')),
      ]));
      expect(_number(result), 15);
    });

    test('a zero step is a runtime error, not a hang', () {
      final result = _run(_program([
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _n(3),
          step: _n(0),
          body: const [],
          srcBlockId: 'loop1',
        ),
      ]));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'loop1');
      expect(result.message, 'This loop would never finish.');
    });

    test('the loop counter is owned by the loop', () {
      final result = _run(_program([
        _set('runs', _n(0)),
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _n(3),
          body: [
            _set('runs', _add(_get('runs'), _n(1))),
            _set('i', _n(99)),
          ],
        ),
        ReturnStmt(value: _get('runs')),
      ]));
      expect(_number(result), 3);
    });

    test('for-each walks a list with an index', () {
      final program = _program(
        [
          _set('total', _n(0)),
          ForEachStmt(
            itemVar: 'item',
            indexVar: 'index',
            collection: _nums('nums'),
            body: [
              _set(
                'total',
                _add(_get('total'), BinaryExpr(
                  BinaryOp.mul,
                  _get('item'),
                  _get('index'),
                  type: ValueType.number,
                )),
              ),
            ],
          ),
          ReturnStmt(value: _get('total')),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final result = _run(program, input: {'nums': valueFromJson([5, 6, 7])});
      expect(_number(result), 0 * 5 + 1 * 6 + 2 * 7);
    });

    test('for-each iterates a snapshot', () {
      final program = _program(
        [
          _set('runs', _n(0)),
          ForEachStmt(
            itemVar: 'item',
            collection: _nums('nums'),
            body: [
              _set('runs', _add(_get('runs'), _n(1))),
              ExprStmt(CallExpr(
                BlockIds.arrAppend,
                [_nums('nums'), _n(0)],
                type: ValueType.voidType,
              )),
            ],
          ),
          ReturnStmt(value: _get('runs')),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final result = _run(program, input: {'nums': valueFromJson([1, 2])});
      expect(_number(result), 2);
    });

    test('while runs with break and continue', () {
      final result = _run(_program([
        _set('i', _n(0)),
        _set('total', _n(0)),
        WhileStmt(
          cond: _bool(true),
          body: [
            IncStmt(const VarLValue('i')),
            IfStmt(
              cond: _lt(_get('i'), _n(3)),
              thenBody: const [ContinueStmt()],
            ),
            IfStmt(
              cond: BinaryExpr(
                BinaryOp.gt,
                _get('i'),
                _n(5),
                type: ValueType.boolean,
              ),
              thenBody: const [BreakStmt()],
            ),
            _set('total', _add(_get('total'), _get('i'))),
          ],
        ),
        ReturnStmt(value: _get('total')),
      ]));
      expect(_number(result), 3 + 4 + 5);
    });

    test('if takes the else branch', () {
      final result = _run(_program([
        IfStmt(
          cond: _bool(false),
          thenBody: [ReturnStmt(value: _n(1))],
          elseBody: [ReturnStmt(value: _n(2))],
        ),
      ]));
      expect(_number(result), 2);
    });

    test('inc and dec walk a number', () {
      final result = _run(_program([
        _set('x', _n(10)),
        IncStmt(const VarLValue('x')),
        DecStmt(const VarLValue('x')),
        DecStmt(const VarLValue('x')),
        ReturnStmt(value: _get('x')),
      ]));
      expect(_number(result), 9);
    });
  });

  group('expressions', () {
    test('whole division stays whole, uneven division does not', () {
      final result = _run(_program([
        ReturnStmt(
          value: BinaryExpr(
            BinaryOp.div,
            _n(7),
            _n(2),
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 3.5);
      final exact = _run(_program([
        ReturnStmt(
          value: BinaryExpr(BinaryOp.div, _n(8), _n(2), type: ValueType.number),
        ),
      ]));
      expect(_number(exact), 4);
    });

    test('dividing by zero is a runtime error', () {
      final result = _run(_program([
        ReturnStmt(
          value: BinaryExpr(
            BinaryOp.div,
            _n(1),
            _n(0),
            type: ValueType.number,
            srcBlockId: 'div1',
          ),
        ),
      ]));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'div1');
      expect(result.message, 'You cannot divide by zero.');
    });

    test('AND short-circuits, so the right side never runs', () {
      final result = _run(_program([
        ReturnStmt(
          value: BinaryExpr(
            BinaryOp.and,
            _bool(false),
            BinaryExpr(
              BinaryOp.lt,
              BinaryExpr(BinaryOp.div, _n(1), _n(0), type: ValueType.number),
              _n(1),
              type: ValueType.boolean,
            ),
            type: ValueType.boolean,
          ),
        ),
      ]));
      expect(result.kind, ResultKind.correct);
      expect((result.output as BoolValue).value, isFalse);
    });

    test('equality compares values, never two different lists', () {
      final program = _program(
        [
          ReturnStmt(
            value: BinaryExpr(
              BinaryOp.eq,
              _nums('a'),
              _nums('b'),
              type: ValueType.boolean,
            ),
          ),
        ],
        params: [
          Param('a', ValueType.array(ValueType.number)),
          Param('b', ValueType.array(ValueType.number)),
        ],
      );
      final result = _run(program, input: {
        'a': valueFromJson([1, 2]),
        'b': valueFromJson([1, 2]),
      });
      expect((result.output as BoolValue).value, isFalse);
    });

    test('a name with no value is a runtime error', () {
      final result = _run(_program([
        ReturnStmt(value: _get('ghost', src: 'g1')),
      ]));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'g1');
    });

    test('the wrong sort of value names the block', () {
      final result = _run(_program([
        IfStmt(cond: _n(1, src: 'n1'), thenBody: const [], srcBlockId: 'if1'),
      ]));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'n1');
      expect(result.message, 'This block needs a yes or no value.');
    });
  });

  group('collections', () {
    test('a list can be built, read, swapped and trimmed', () {
      final result = _run(_program([
        _set('a', NewExpr(CollKind.array, type: ValueType.array(ValueType.number))),
        ExprStmt(CallExpr(
          BlockIds.arrAppend,
          [_nums('a'), _n(1)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.arrAppend,
          [_nums('a'), _n(2)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.arrAppend,
          [_nums('a'), _n(3)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.arrSwap,
          [_nums('a'), _n(0), _n(2)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.arrRemove,
          [_nums('a'), _n(1)],
          type: ValueType.voidType,
        )),
        AssignStmt(
          target: IndexLValue(_nums('a'), _n(1)),
          value: _n(9),
        ),
        ReturnStmt(value: _nums('a')),
      ]));
      expect(result.kind, ResultKind.correct);
      expect(result.output!.toJson(), [3, 9]);
    });

    test('a position outside the list names the block', () {
      final program = _program(
        [
          ReturnStmt(
            value: IndexExpr(
              _nums('nums'),
              _n(5),
              type: ValueType.number,
              srcBlockId: 'get1',
            ),
          ),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final result = _run(program, input: {'nums': valueFromJson([1, 2])});
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'get1');
      expect(result.message, 'That position is outside the list.');
    });

    test('a map keeps what it is given', () {
      final mapType = ValueType.mapOf(ValueType.string, ValueType.number);
      final result = _run(_program([
        _set('m', NewExpr(CollKind.map, type: mapType)),
        ExprStmt(CallExpr(
          BlockIds.mapSet,
          [
            _get('m', type: mapType),
            LitExpr('a', type: ValueType.string),
            _n(1),
          ],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.mapSet,
          [
            _get('m', type: mapType),
            LitExpr('b', type: ValueType.string),
            _n(2),
          ],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.mapRemove,
          [_get('m', type: mapType), LitExpr('a', type: ValueType.string)],
          type: ValueType.voidType,
        )),
        ReturnStmt(
          value: CallExpr(
            BlockIds.mapSize,
            [_get('m', type: mapType)],
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 1);
    });

    test('a set ignores a repeat', () {
      final setType = ValueType.setOf(ValueType.number);
      final result = _run(_program([
        _set('s', NewExpr(CollKind.set, type: setType)),
        ExprStmt(CallExpr(
          BlockIds.setAdd,
          [_get('s', type: setType), _n(4)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.setAdd,
          [_get('s', type: setType), _n(4)],
          type: ValueType.voidType,
        )),
        ReturnStmt(
          value: CallExpr(
            BlockIds.setSize,
            [_get('s', type: setType)],
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 1);
    });

    test('a stack is last in, first out', () {
      final stackType = ValueType.stackOf(ValueType.number);
      final result = _run(_program([
        _set('s', NewExpr(CollKind.stack, type: stackType)),
        ExprStmt(CallExpr(
          BlockIds.stackPush,
          [_get('s', type: stackType), _n(1)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.stackPush,
          [_get('s', type: stackType), _n(2)],
          type: ValueType.voidType,
        )),
        ReturnStmt(
          value: CallExpr(
            BlockIds.stackPop,
            [_get('s', type: stackType)],
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 2);
    });

    test('a queue is first in, first out', () {
      final queueType = ValueType.queueOf(ValueType.number);
      final result = _run(_program([
        _set('q', NewExpr(CollKind.queue, type: queueType)),
        ExprStmt(CallExpr(
          BlockIds.queueEnq,
          [_get('q', type: queueType), _n(1)],
          type: ValueType.voidType,
        )),
        ExprStmt(CallExpr(
          BlockIds.queueEnq,
          [_get('q', type: queueType), _n(2)],
          type: ValueType.voidType,
        )),
        ReturnStmt(
          value: CallExpr(
            BlockIds.queueDeq,
            [_get('q', type: queueType)],
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 1);
    });

    test('popping an empty stack is a runtime error', () {
      final stackType = ValueType.stackOf(ValueType.number);
      final result = _run(_program([
        _set('s', NewExpr(CollKind.stack, type: stackType)),
        ReturnStmt(
          value: CallExpr(
            BlockIds.stackPop,
            [_get('s', type: stackType)],
            type: ValueType.number,
            srcBlockId: 'pop1',
          ),
        ),
      ]));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'pop1');
      expect(result.message, 'This stack is empty.');
    });

    test('swap exchanges two names', () {
      final result = _run(_program([
        _set('a', _n(1)),
        _set('b', _n(2)),
        ExprStmt(CallExpr(
          BlockIds.varSwap,
          [_get('a'), _get('b')],
          type: ValueType.voidType,
        )),
        ReturnStmt(
          value: BinaryExpr(
            BinaryOp.sub,
            _get('a'),
            _get('b'),
            type: ValueType.number,
          ),
        ),
      ]));
      expect(_number(result), 1);
    });
  });

  group('nodes and graphs', () {
    test('a linked list can be read and relinked', () {
      final third = ListNodeValue(3);
      final second = ListNodeValue(2, next: third);
      final first = ListNodeValue(1, next: second);
      final program = _program(
        [
          // head.next = head.next.next
          AssignStmt(
            target: FieldLValue(_get('head', type: ValueType.listNode), 'next'),
            value: FieldExpr(
              FieldExpr(
                _get('head', type: ValueType.listNode),
                'next',
                type: ValueType.listNode.asNullable,
              ),
              'next',
              type: ValueType.listNode.asNullable,
            ),
          ),
          ReturnStmt(value: _get('head', type: ValueType.listNode)),
        ],
        params: [Param('head', ValueType.listNode)],
      );
      final result = _run(program, input: {'head': first});
      expect(result.kind, ResultKind.correct);
      expect(result.output!.toJson(), [1, 3]);
      // The given list is copied, so the fixture is untouched.
      expect(first.toJson(), [1, 2, 3]);
    });

    test('reading through an empty node is a runtime error', () {
      final program = _program(
        [
          ReturnStmt(
            value: FieldExpr(
              FieldExpr(
                _get('head', type: ValueType.listNode),
                'next',
                type: ValueType.listNode.asNullable,
              ),
              'value',
              type: ValueType.number,
              srcBlockId: 'val1',
            ),
          ),
        ],
        params: [Param('head', ValueType.listNode)],
      );
      final result = _run(program, input: {'head': ListNodeValue(1)});
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'val1');
      expect(result.message, 'There is nothing here.');
    });

    test('a graph reports neighbors and remembers marks', () {
      final graph = GraphValue({
        0: [1, 2],
        1: [0],
        2: [0],
      });
      final program = _program(
        [
          ExprStmt(CallExpr(
            BlockIds.graphMark,
            [_get('g', type: ValueType.graph), _n(1)],
            type: ValueType.voidType,
          )),
          IfStmt(
            cond: CallExpr(
              BlockIds.graphVisited,
              [_get('g', type: ValueType.graph), _n(1)],
              type: ValueType.boolean,
            ),
            thenBody: [
              ReturnStmt(
                value: _len(CallExpr(
                  BlockIds.graphNeighbors,
                  [_get('g', type: ValueType.graph), _n(0)],
                  type: ValueType.array(ValueType.number),
                )),
              ),
            ],
          ),
          ReturnStmt(value: _n(-1)),
        ],
        params: [Param('g', ValueType.graph)],
      );
      final result = _run(program, input: {'g': graph});
      expect(_number(result), 2);
      expect(graph.visited, isEmpty, reason: 'the given graph is copied');
    });
  });

  group('budgets', () {
    test('an endless loop stops on the operation budget', () {
      final result = _run(
        _program([
          WhileStmt(cond: _bool(true), body: const [], srcBlockId: 'w1'),
        ]),
        limits: const RunLimits(maxOps: 50),
      );
      expect(result.kind, ResultKind.operationLimit);
      expect(result.message, 'This program took too many steps.');
      expect(result.metrics.ops, 50);
    });

    test('runaway allocation stops on the memory budget', () {
      final result = _run(
        _program([
          _set('a', NewExpr(CollKind.array, type: ValueType.array(ValueType.number))),
          ForRangeStmt(
            loopVar: 'i',
            start: _n(0),
            end: _n(1000),
            body: [
              ExprStmt(CallExpr(
                BlockIds.arrAppend,
                [_nums('a'), _get('i')],
                type: ValueType.voidType,
              )),
            ],
          ),
        ]),
        limits: const RunLimits(maxOps: 100000, maxAlloc: 10),
      );
      expect(result.kind, ResultKind.memoryLimit);
      expect(result.metrics.peakAlloc, 10);
    });

    test('removing an element gives its cell back', () {
      final result = _run(
        _program([
          _set('a', NewExpr(CollKind.array, type: ValueType.array(ValueType.number))),
          ForRangeStmt(
            loopVar: 'i',
            start: _n(0),
            end: _n(20),
            body: [
              ExprStmt(CallExpr(
                BlockIds.arrAppend,
                [_nums('a'), _get('i')],
                type: ValueType.voidType,
              )),
              ExprStmt(CallExpr(
                BlockIds.arrRemove,
                [_nums('a'), _n(0)],
                type: ValueType.voidType,
              )),
            ],
          ),
        ]),
        limits: const RunLimits(maxAlloc: 4),
      );
      expect(result.kind, ResultKind.correct);
      expect(result.metrics.peakAlloc, 2);
    });

    test('runaway recursion stops on the depth budget', () {
      final program = Program(functions: [
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
      final result = _run(program, limits: const RunLimits(maxDepth: 8));
      expect(result.kind, ResultKind.runtimeError);
      expect(result.message, 'This program went too many levels deep.');
      expect(result.metrics.peakDepth, 8);
    });

    test('metrics report the work that was done', () {
      final result = _run(_program([
        _set('total', _n(0)),
        ForRangeStmt(
          loopVar: 'i',
          start: _n(0),
          end: _n(3),
          body: [_set('total', _add(_get('total'), _get('i')))],
        ),
        ReturnStmt(value: _get('total')),
      ]));
      expect(result.kind, ResultKind.correct);
      expect(result.metrics.ops, greaterThan(0));
      expect(result.metrics.peakDepth, 1);
      expect(result.metrics.peakAlloc, 0);
    });
  });

  group('sandbox', () {
    test('the same program and input always give the same result', () {
      Program build() => _program(
            [
              _set('total', _n(0)),
              ForEachStmt(
                itemVar: 'item',
                collection: _nums('nums'),
                body: [_set('total', _add(_get('total'), _get('item')))],
              ),
              ReturnStmt(value: _get('total')),
            ],
            params: [Param('nums', ValueType.array(ValueType.number))],
          );
      final first = _run(build(), input: {'nums': valueFromJson([3, 1, 2])});
      final second = _run(build(), input: {'nums': valueFromJson([3, 1, 2])});
      expect(_number(first), _number(second));
      expect(first.metrics.ops, second.metrics.ops);
      expect(first.metrics.peakAlloc, second.metrics.peakAlloc);
    });

    test('a run cannot mutate the values it was given', () {
      final nums = valueFromJson([1, 2]) as ArrayValue;
      final program = _program(
        [
          ExprStmt(CallExpr(
            BlockIds.arrAppend,
            [_nums('nums'), _n(3)],
            type: ValueType.voidType,
          )),
          AssignStmt(target: IndexLValue(_nums('nums'), _n(0)), value: _n(99)),
          ReturnStmt(value: _nums('nums')),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final result = _run(program, input: {'nums': nums});
      expect(result.output!.toJson(), [99, 2, 3]);
      expect(nums.toJson(), [1, 2]);
    });

    test('a missing value is an invalid program, not a crash', () {
      final result = _run(
        _program(
          [ReturnStmt(value: _get('x'))],
          params: [Param('x', ValueType.number)],
        ),
      );
      expect(result.kind, ResultKind.invalidProgram);
      expect(result.message, contains('x'));
    });

    test('a program with no entry function is invalid', () {
      final result = _run(Program.empty);
      expect(result.kind, ResultKind.invalidProgram);
      expect(result.message, 'This program has no starting point.');
    });

    test('a block the VM cannot run is invalid, never evaluated', () {
      final result = _run(_program([
        ExprStmt(CallExpr(
          BlockIds.fnCall,
          const [],
          type: ValueType.voidType,
          srcBlockId: 'call1',
        )),
      ]));
      expect(result.kind, ResultKind.invalidProgram);
      expect(result.blockId, 'call1');
      expect(result.message, 'This block cannot run yet.');
    });

    test('the VM runs IR that made a round trip through JSON', () {
      final program = _program(
        [
          _set('total', _n(0)),
          ForRangeStmt(
            loopVar: 'i',
            start: _n(0),
            end: _len(_nums('nums')),
            body: [
              _set(
                'total',
                _add(
                  _get('total'),
                  IndexExpr(_nums('nums'), _get('i'), type: ValueType.number),
                ),
              ),
            ],
          ),
          ReturnStmt(value: _get('total')),
        ],
        params: [Param('nums', ValueType.array(ValueType.number))],
      );
      final restored = Program.fromJsonString(program.toJsonString());
      final direct = _run(program, input: {'nums': valueFromJson([1, 2, 3])});
      final roundTripped =
          _run(restored, input: {'nums': valueFromJson([1, 2, 3])});
      expect(_number(roundTripped), _number(direct));
      expect(roundTripped.metrics.ops, direct.metrics.ops);
    });
  });

  group('trace', () {
    test('steps carry the block that ran and the names in play', () {
      final events = <TraceEvent>[];
      final result = _run(
        _program([
          _set('x', _n(1), src: 'set1'),
          IfStmt(cond: _bool(true), thenBody: const [], srcBlockId: 'if1'),
        ]),
        trace: events.add,
      );
      expect(result.kind, ResultKind.correct);
      expect(events.map((e) => e.kind), containsAll(['assign', 'if']));
      final assign = events.firstWhere((e) => e.kind == 'assign');
      expect(assign.blockId, 'set1');
      expect(assign.locals['x'], '1');
      expect(assign.opIndex, greaterThan(0));
    });

    test('a run without a trace sink emits nothing', () {
      final result = _run(_program([_set('x', _n(1))]));
      expect(result.kind, ResultKind.correct);
    });
  });

  group('pipeline', () {
    test('graph → lower → run returns the length of the given list', () {
      final puzzle = parsePuzzleJson('''
{
  "id": "vm_probe",
  "title": "VM probe",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "s",
  "io": {
    "inputs": [{ "name": "nums", "type": "array<num>" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": ["ctrl.return", "arr.len", "var.get"] },
  "limits": { "maxOps": 10000 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }
}
''');
      final history = GraphHistory(
        BlockGraph(
          blocks: const {},
          variables: {'nums': ValueType.array(ValueType.number)},
        ),
      );
      for (final add in [
        AddBlockCommand(catalogId: BlockIds.ctrlReturn, id: 'ret1'),
        AddBlockCommand(catalogId: BlockIds.arrLen, id: 'len1'),
        AddBlockCommand(
          catalogId: BlockIds.varGet,
          id: 'nums1',
          literals: {'name': 'nums'},
        ),
      ]) {
        expect(history.apply(add).ok, isTrue);
      }
      expect(history.apply(AttachStatementCommand(
        blockId: 'ret1',
        to: PortRef.mainBody,
      )).ok, isTrue);
      expect(history.apply(ConnectCommand(
        from: PortRef('len1', 'out'),
        to: PortRef('ret1', 'value'),
      )).ok, isTrue);
      expect(history.apply(ConnectCommand(
        from: PortRef('nums1', 'out'),
        to: PortRef('len1', 'array'),
      )).ok, isTrue);

      const engine = DefaultEngine();
      final lowered = engine.lower(history.current, puzzle);
      expect(lowered.ok, isTrue, reason: '${lowered.errors}');

      final fixture = puzzle.visibleTests.single;
      final result = engine.run(
        lowered.program!,
        {
          for (final input in puzzle.io.inputs)
            input.name: valueFromJson(fixture.input[input.name]),
        },
        puzzle.limits.asLimits,
      );
      expect(result.kind, ResultKind.correct);
      expect(_number(result), 3);
      expect(result.metrics.ops, lessThanOrEqualTo(puzzle.limits.maxOps));
    });
  });
}
