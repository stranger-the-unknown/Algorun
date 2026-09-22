import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

final _nums = ValueType.array(ValueType.number);

Expr _n(num value) => LitExpr(value, type: ValueType.number);

Expr _floorDiv(Expr a, Expr b, {String? src}) =>
    BinaryExpr(BinaryOp.floorDiv, a, b, type: ValueType.number, srcBlockId: src);

RunResult _run(List<Stmt> body, {Map<String, RuntimeValue> input = const {}}) {
  return runProgram(
    Program(functions: [
      FnDecl(
        name: 'main',
        params: [for (final name in input.keys) Param(name, _nums)],
        body: body,
      ),
    ]),
    input,
    RunLimits.standard,
  );
}

num _floorDivide(num a, num b) {
  final result = _run([ReturnStmt(value: _floorDiv(_n(a), _n(b)))]);
  expect(result.kind, ResultKind.correct, reason: '$a FLOOR DIVIDE $b: ${result.message}');
  return (result.output as NumValue).value;
}

String _add(GraphHistory h, String catalogId, String id, [Map<String, Object?> literals = const {}]) {
  final r = h.apply(AddBlockCommand(catalogId: catalogId, id: id, literals: literals));
  expect(r.ok, isTrue, reason: r.decision.message);
  return id;
}

void _plug(GraphHistory h, String from, String to, String port) {
  final r = h.apply(ConnectCommand(from: PortRef(from, 'out'), to: PortRef(to, port)));
  expect(r.ok, isTrue, reason: '$from → $to.$port: ${r.decision.message}');
}

void main() {
  group('the block', () {
    test('is in the catalog as num FLOOR DIVIDE num → num', () {
      expect(BlockIds.exists(BlockIds.arithFloorDiv), isTrue);
      expect(BlockIds.arithFloorDiv, 'arith.floor_div');
      final def = BlockCatalog.of(BlockIds.arithFloorDiv)!;
      final inputs = def.inputs.where((p) => p.isExpr).toList();
      expect(inputs.map((p) => p.name), ['left', 'right']);
      expect(inputs.every((p) => p.type == ValueType.number), isTrue);
      expect(def.ports.singleWhere((p) => p.isOutput).type, ValueType.number);
    });

    test('reads FLOOR DIVIDE next to DIVIDE and REMAINDER', () {
      expect(BlockChrome.labelOf(BlockIds.arithFloorDiv), 'FLOOR DIVIDE');
      expect(BlockChrome.labelOf(BlockIds.arithDiv), 'DIVIDE');
      expect(
        BlockChrome.of(BlockIds.arithFloorDiv).category,
        BlockChrome.of(BlockIds.arithDiv).category,
      );
    });

    test('lowers to its own binary operator', () {
      final h = GraphHistory(BlockGraph(blocks: const {}));
      _add(h, BlockIds.ctrlReturn, 'ret1');
      _add(h, BlockIds.arithFloorDiv, 'fd1');
      _add(h, BlockIds.litNum, 'a', {'value': 7});
      _add(h, BlockIds.litNum, 'b', {'value': 2});
      expect(h.apply(AttachStatementCommand(blockId: 'ret1', to: PortRef.mainBody)).ok, isTrue);
      _plug(h, 'fd1', 'ret1', 'value');
      _plug(h, 'a', 'fd1', 'left');
      _plug(h, 'b', 'fd1', 'right');
      final puzzle = parsePuzzleJson('''
{
  "id": "fd_probe", "title": "FD", "world": "world_01", "tier": 1, "mode": "build",
  "story": "s",
  "io": { "inputs": [], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "arith.floor_div", "lit.num"] },
  "limits": { "maxOps": 100 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": {}, "out": 3 }],
    "hidden": [{ "id": "h1", "in": {}, "out": 3 }]
  }
}
''');
      final lowered = const DefaultEngine().lower(h.current, puzzle);
      expect(lowered.ok, isTrue, reason: '${lowered.errors}');
      final ret = lowered.program!.functions.single.body.single as ReturnStmt;
      final expr = ret.value! as BinaryExpr;
      expect(expr.op, BinaryOp.floorDiv);
      expect(expr.srcBlockId, 'fd1');
      expect(const DefaultEngine().runTests(lowered.program!, puzzle).kind, ResultKind.correct);
    });

    test('survives an IR JSON round trip', () {
      final program = Program(functions: [
        FnDecl(name: 'main', params: const [], body: [ReturnStmt(value: _floorDiv(_n(9), _n(4)))]),
      ]);
      final json = program.toJsonString();
      expect(json, contains('"op":"floorDiv"'));
      final restored = Program.fromJsonString(json);
      final ret = restored.functions.single.body.single as ReturnStmt;
      expect((ret.value! as BinaryExpr).op, BinaryOp.floorDiv);
    });
  });

  group('semantics', () {
    test('positive values round down', () {
      expect(_floorDivide(7, 2), 3);
      expect(_floorDivide(1, 3), 0);
      expect(_floorDivide(0, 5), 0);
    });

    test('exact division stays exact and whole', () {
      final result = _floorDivide(8, 2);
      expect(result, 4);
      expect(result, isA<int>());
    });

    test('non-exact division never leaves a fraction', () {
      expect(_floorDivide(7.5, 2), 3);
      expect(_floorDivide(10, 4), isA<int>());
    });

    test('negative values round down, toward minus infinity', () {
      expect(_floorDivide(-7, 2), -4);
      expect(_floorDivide(7, -2), -4);
      expect(_floorDivide(-7, -2), 3);
      expect(_floorDivide(-8, 2), -4);
    });

    test('a zero denominator is a runtime error on that block', () {
      final result = _run([
        ReturnStmt(value: _floorDiv(_n(1), _n(0), src: 'fd1')),
      ]);
      expect(result.kind, ResultKind.runtimeError);
      expect(result.blockId, 'fd1');
      expect(result.message, 'You cannot divide by zero.');
    });

    test('DIVIDE is unchanged', () {
      final result = _run([
        ReturnStmt(value: BinaryExpr(BinaryOp.div, _n(7), _n(2), type: ValueType.number)),
      ]);
      expect((result.output as NumValue).value, 3.5);
    });

    test('costs one op, like every other block', () {
      final floor = _run([ReturnStmt(value: _floorDiv(_n(7), _n(2)))]);
      final plain = _run([
        ReturnStmt(value: BinaryExpr(BinaryOp.div, _n(7), _n(2), type: ValueType.number)),
      ]);
      expect(floor.metrics.ops, plain.metrics.ops);
    });
  });

  group('list positions', () {
    // nums[(0 + 3) ÷ 2] on a four-item list.
    Stmt midpoint(BinaryOp op) => ReturnStmt(
          value: IndexExpr(
            VarExpr('nums', type: _nums),
            BinaryExpr(
              op,
              BinaryExpr(BinaryOp.add, _n(0), _n(3), type: ValueType.number),
              _n(2),
              type: ValueType.number,
            ),
            type: ValueType.number,
            srcBlockId: 'get1',
          ),
        );

    test('a FLOOR DIVIDE midpoint is a valid position', () {
      final result = _run(
        [midpoint(BinaryOp.floorDiv)],
        input: {'nums': valueFromJson([10, 20, 30, 40])},
      );
      expect(result.kind, ResultKind.correct);
      expect((result.output as NumValue).value, 20);
    });

    test('the same midpoint with DIVIDE is not', () {
      final result = _run(
        [midpoint(BinaryOp.div)],
        input: {'nums': valueFromJson([10, 20, 30, 40])},
      );
      expect(result.kind, ResultKind.runtimeError);
      expect(result.message, 'A position has to be a whole number.');
    });

    test('graph → lower → runTests: the middle of a list', () {
      final puzzle = parsePuzzleJson('''
{
  "id": "middle_probe", "title": "Middle", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Return the middle item; for an even count, the left middle.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.return", "arr.get", "arr.len", "var.get", "arith.sub", "arith.floor_div", "lit.num"]
  },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [
      { "id": "odd", "in": { "nums": [1, 2, 3] }, "out": 2 },
      { "id": "even", "in": { "nums": [5, 6, 7, 8] }, "out": 6 }
    ],
    "hidden": [{ "id": "one", "in": { "nums": [9] }, "out": 9 }]
  }
}
''');
      final h = GraphHistory(BlockGraph(blocks: const {}, variables: {'nums': _nums}));
      _add(h, BlockIds.ctrlReturn, 'ret1');
      _add(h, BlockIds.arrGet, 'get1');
      _add(h, BlockIds.varGet, 'nums1', {'name': 'nums'});
      _add(h, BlockIds.arithFloorDiv, 'fd1');
      _add(h, BlockIds.arithSub, 'sub1');
      _add(h, BlockIds.arrLen, 'len1');
      _add(h, BlockIds.varGet, 'nums2', {'name': 'nums'});
      _add(h, BlockIds.litNum, 'one', {'value': 1});
      _add(h, BlockIds.litNum, 'two', {'value': 2});
      expect(h.apply(AttachStatementCommand(blockId: 'ret1', to: PortRef.mainBody)).ok, isTrue);
      _plug(h, 'get1', 'ret1', 'value');
      _plug(h, 'nums1', 'get1', 'array');
      _plug(h, 'fd1', 'get1', 'index');
      _plug(h, 'sub1', 'fd1', 'left');
      _plug(h, 'two', 'fd1', 'right');
      _plug(h, 'len1', 'sub1', 'left');
      _plug(h, 'one', 'sub1', 'right');
      _plug(h, 'nums2', 'len1', 'array');

      const engine = DefaultEngine();
      final lowered = engine.lower(h.current, puzzle);
      expect(lowered.ok, isTrue, reason: '${lowered.errors}');
      final suite = engine.runTests(lowered.program!, puzzle);
      expect(suite.kind, ResultKind.correct, reason: suite.message);
      expect(suite.visible.map((c) => c.actual), [2, 6]);
      expect(suite.hiddenSummary!.passed, 1);
    });
  });
}
