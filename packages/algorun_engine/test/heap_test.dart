import 'dart:math';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// Milestone H: heaps of numbers — NEW MIN HEAP / NEW MAX HEAP, INSERT,
/// TAKE TOP, TOP, SIZE, IS EMPTY.
void main() {
  const numHeap = ValueType(TypeAtom.heap, param: ValueType.number);

  Expr h() => const VarExpr('h', type: numHeap);
  Expr n(num v) => LitExpr(v, type: ValueType.number);
  Stmt insert(num v) => ExprStmt(CallExpr(BlockIds.heapInsert, [h(), n(v)], type: ValueType.voidType));
  Expr take() => CallExpr(BlockIds.heapTake, [h()], type: ValueType.number, srcBlockId: 'take1');
  Stmt make({required bool max}) => AssignStmt(
        target: const VarLValue('h'),
        value: NewExpr(max ? CollKind.maxHeap : CollKind.minHeap, type: numHeap),
      );

  RunResult run(List<Stmt> body) => const DefaultEngine().run(
        Program(functions: [FnDecl(name: 'main', params: const [], body: body)]),
        const {},
        RunLimits.standard,
      );

  group('the value', () {
    test('a min heap takes from the smallest, a max heap from the largest', () {
      final random = Random(9);
      final values = [for (var i = 0; i < 200; i++) random.nextInt(50) - 25];
      final low = HeapValue([], isMax: false);
      final high = HeapValue([], isMax: true);
      for (final v in values) {
        low.insert(v);
        high.insert(v);
      }
      expect([for (var i = 0; i < values.length; i++) low.takeTop()], [...values]..sort());
      expect([for (var i = 0; i < values.length; i++) high.takeTop()], ([...values]..sort()).reversed);
    });

    test('shows its items in the order TAKE TOP gives them', () {
      final heap = HeapValue([], isMax: true)
        ..insert(3)
        ..insert(9)
        ..insert(1);
      expect(valueToJson(heap), {
        'type': 'heap',
        'order': 'max',
        'items': [9, 3, 1],
      });
      expect(heap.toJson(), [9, 3, 1]);
    });
  });

  group('running', () {
    test('INSERT, TOP, TAKE TOP, SIZE and IS EMPTY on a min heap', () {
      final result = run([
        make(max: false),
        insert(5),
        insert(1),
        insert(3),
        AssignStmt(target: const VarLValue('first'), value: take()),
        AssignStmt(
          target: const VarLValue('next'),
          value: CallExpr(BlockIds.heapTop, [h()], type: ValueType.number),
        ),
        ReturnStmt(
          value: BinaryExpr(
            BinaryOp.add,
            BinaryExpr(
              BinaryOp.add,
              BinaryExpr(BinaryOp.mul, const VarExpr('first', type: ValueType.number), n(100), type: ValueType.number),
              BinaryExpr(BinaryOp.mul, const VarExpr('next', type: ValueType.number), n(10), type: ValueType.number),
              type: ValueType.number,
            ),
            CallExpr(BlockIds.heapSize, [h()], type: ValueType.number),
            type: ValueType.number,
          ),
        ),
      ]);
      expect(result.kind, ResultKind.correct, reason: result.message);
      expect((result.output! as NumValue).value, 132); // took 1, then 3 on top, 2 left
    });

    test('a max heap gives the largest first', () {
      final result = run([make(max: true), insert(5), insert(1), insert(8), ReturnStmt(value: take())]);
      expect((result.output! as NumValue).value, 8);
    });

    test('IS EMPTY; the heap takes a memory cell and so does every item in it', () {
      final result = run([
        make(max: false),
        insert(2),
        insert(4),
        ExprStmt(take()),
        ReturnStmt(value: CallExpr(BlockIds.heapEmpty, [h()], type: ValueType.boolean)),
      ]);
      expect((result.output! as BoolValue).value, isFalse);
      expect(result.metrics.peakAlloc, 1 + 2);
    });

    test('TAKE TOP on an empty heap stops with a runtime error on that block', () {
      final result = run([make(max: false), ReturnStmt(value: take())]);
      expect(result.kind, ResultKind.runtimeError);
      expect(result.message, 'This heap is empty.');
      expect(result.blockId, 'take1');
    });
  });

  group('blocks', () {
    test('every heap block has a label in the collection category', () {
      for (final (id, label) in [
        (BlockIds.newMinHeap, 'NEW MIN HEAP'),
        (BlockIds.newMaxHeap, 'NEW MAX HEAP'),
        (BlockIds.heapInsert, 'INSERT'),
        (BlockIds.heapTake, 'TAKE TOP'),
        (BlockIds.heapTop, 'TOP'),
        (BlockIds.heapSize, 'SIZE'),
        (BlockIds.heapEmpty, 'IS EMPTY'),
      ]) {
        expect(BlockIds.exists(id), isTrue, reason: id);
        expect(BlockChrome.labelOf(id), label);
        expect(BlockChrome.of(id).category, BlockCategory.collection);
      }
    });

    GraphHistory history() => GraphHistory(BlockGraph(
          blocks: const {},
          variables: const {'h': numHeap, 'x': ValueType.number, 'ok': ValueType.boolean},
        ));

    String add(GraphHistory g, String catalogId, [Map<String, Object?> literals = const {}]) {
      final before = g.current.blocks.keys.toSet();
      final r = g.apply(AddBlockCommand(catalogId: catalogId, literals: literals));
      expect(r.ok, isTrue, reason: r.decision.message);
      return r.graph.blocks.keys.firstWhere((k) => !before.contains(k));
    }

    bool connect(GraphHistory g, String from, String to, String port) =>
        g.apply(ConnectCommand(from: PortRef(from, 'out'), to: PortRef(to, port))).ok;

    test('NEW MIN HEAP fits a heap variable, not a number one', () {
      final g = history();
      final setH = add(g, BlockIds.varSet, {'name': 'h'});
      final setX = add(g, BlockIds.varSet, {'name': 'x'});
      final fresh = add(g, BlockIds.newMinHeap);
      expect(connect(g, fresh, setX, 'value'), isFalse);
      expect(connect(g, fresh, setH, 'value'), isTrue);
    });

    test('INSERT takes a heap and a number; TAKE TOP gives a number', () {
      final g = history();
      final ins = add(g, BlockIds.heapInsert);
      final number = add(g, BlockIds.varGet, {'name': 'x'});
      final r = g.apply(ConnectCommand(from: PortRef(number, 'out'), to: PortRef(ins, 'heap')));
      expect(r.ok, isFalse);
      expect(r.decision.message, 'This block needs a heap.');
      expect(connect(g, add(g, BlockIds.varGet, {'name': 'h'}), ins, 'heap'), isTrue);
      expect(connect(g, add(g, BlockIds.litBool), ins, 'value'), isFalse);
      final top = add(g, BlockIds.heapTake);
      expect(connect(g, top, ins, 'value'), isTrue);
    });

    test('a program built from blocks lowers and runs', () {
      final g = history();
      final setH = add(g, BlockIds.varSet, {'name': 'h'});
      expect(connect(g, add(g, BlockIds.newMaxHeap), setH, 'value'), isTrue);
      final ins = add(g, BlockIds.heapInsert);
      expect(connect(g, add(g, BlockIds.varGet, {'name': 'h'}), ins, 'heap'), isTrue);
      expect(connect(g, add(g, BlockIds.litNum, {'value': 7}), ins, 'value'), isTrue);
      final ret = add(g, BlockIds.ctrlReturn);
      final top = add(g, BlockIds.heapTop);
      expect(connect(g, add(g, BlockIds.varGet, {'name': 'h'}), top, 'heap'), isTrue);
      expect(connect(g, top, ret, 'value'), isTrue);
      for (final id in [setH, ins, ret]) {
        expect(g.apply(AttachStatementCommand(blockId: id, to: PortRef.mainBody)).ok, isTrue);
      }
      final puzzle = parsePuzzleJson('''
{
  "id": "heap_probe", "title": "Heap probe", "world": "world_09", "tier": 1, "mode": "build", "story": "s",
  "io": { "inputs": [], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "var.set", "var.get", "lit.num", "new.max_heap", "heap.insert", "heap.top"] },
  "limits": { "maxOps": 1000 },
  "validators": { "output": "equal" },
  "fixtures": { "visible": [{ "id": "v1", "in": {}, "out": 7 }], "hidden": [{ "id": "h1", "in": {}, "out": 7 }] }
}
''');
      final lowered = const DefaultEngine().lower(g.current, puzzle);
      expect(lowered.errors, isEmpty, reason: '${lowered.errors.map((e) => e.message)}');
      final result = const DefaultEngine().run(lowered.program!, const {}, RunLimits.standard);
      expect((result.output! as NumValue).value, 7);
    });
  });
}
