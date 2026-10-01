import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Puzzle _puzzle({
  List<String>? allow,
  String output = 'num',
  List<Map<String, String>> inputs = const [
    {'name': 'x', 'type': 'num'},
  ],
}) {
  final allowList = allow ??
      [
        'ctrl.if',
        'ctrl.else',
        'ctrl.while',
        'ctrl.for_range',
        'ctrl.foreach',
        'ctrl.return',
        'var.set',
        'var.get',
        'var.inc',
        'lit.num',
        'lit.bool',
        'cmp.gt',
        'cmp.lt',
        'arith.add',
        'arr.get',
        'arr.len',
        'arr.set',
        'map.get',
        'ctrl.continue',
        'fn.call',
      ];
  final inJson = [
    for (final i in inputs) '{ "name": "${i['name']}", "type": "${i['type']}" }',
  ].join(',');
  // Lowering never reads fixtures, but the schema does: give each input and
  // the output a value of its declared type.
  final given = [
    for (final i in inputs) '"${i['name']}": ${_sample[i['type']]}',
  ].join(', ');
  return parsePuzzleJson('''
{
  "id": "lower_probe",
  "title": "L",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "s",
  "io": {
    "inputs": [$inJson],
    "output": { "type": "$output" }
  },
  "blocks": { "allow": [${allowList.map((e) => '"$e"').join(',')}] },
  "limits": { "maxOps": 10000 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { $given }, "out": ${_sample[output]} }],
    "hidden": [{ "id": "h1", "in": { $given }, "out": ${_sample[output]} }]
  }
}
''');
}

const _sample = {'num': '1', 'bool': 'true', 'array<num>': '[1]'};

void main() {
  const lowerer = Lowerer();

  group('golden lowering', () {
    test('A simple SET', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 1});
      _connect(h, 'n1', 'out', 'set1', 'value');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final assign = result.program!.functions.single.body.single as AssignStmt;
      expect(assign.srcBlockId, 'set1');
      expect((assign.target as VarLValue).name, 'x');
      expect((assign.value as LitExpr).value, 1);
      expect(assign.value.srcBlockId, 'n1');
    });

    test('B arithmetic expression', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.arithAdd, id: 'add1');
      _add(h, BlockIds.varGet, id: 'gx', literals: {'name': 'x'});
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 1});
      _connect(h, 'add1', 'out', 'set1', 'value');
      _connect(h, 'gx', 'out', 'add1', 'left');
      _connect(h, 'n1', 'out', 'add1', 'right');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final assign = result.program!.functions.single.body.single as AssignStmt;
      final add = assign.value as BinaryExpr;
      expect(add.op, BinaryOp.add);
      expect(add.srcBlockId, 'add1');
      expect((add.left as VarExpr).name, 'x');
      expect((add.right as LitExpr).value, 1);
    });

    test('C IF', () {
      final h = _hist();
      _add(h, BlockIds.ctrlIf, id: 'if1');
      _add(h, BlockIds.litBool, id: 'b1', literals: {'value': true});
      _add(h, BlockIds.ctrlReturn, id: 'r1');
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 0});
      _connect(h, 'b1', 'out', 'if1', 'condition');
      _connect(h, 'n1', 'out', 'r1', 'value');
      _attach(h, 'if1', PortRef.mainBody);
      _attach(h, 'r1', const PortRef('if1', 'then'));
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final iff = result.program!.functions.single.body.single as IfStmt;
      expect(iff.srcBlockId, 'if1');
      expect(iff.elseBody, isNull);
      expect(iff.thenBody.single, isA<ReturnStmt>());
      expect((iff.cond as LitExpr).value, true);
    });

    test('D IF/ELSE is one If node', () {
      final h = _hist({'found': ValueType.boolean});
      _add(h, BlockIds.ctrlIf, id: 'if1');
      _add(h, BlockIds.litBool, id: 'cond', literals: {'value': true});
      _add(h, BlockIds.ctrlElse, id: 'else1');
      _add(h, BlockIds.varSet, id: 'st', literals: {'name': 'found'});
      _add(h, BlockIds.varSet, id: 'sf', literals: {'name': 'found'});
      _add(h, BlockIds.litBool, id: 't', literals: {'value': true});
      _add(h, BlockIds.litBool, id: 'f', literals: {'value': false});
      _connect(h, 'cond', 'out', 'if1', 'condition');
      _connect(h, 'else1', 'clause', 'if1', 'else');
      _attach(h, 'if1', PortRef.mainBody);
      _attach(h, 'st', const PortRef('if1', 'then'));
      _attach(h, 'sf', const PortRef('else1', 'body'));
      _connect(h, 't', 'out', 'st', 'value');
      _connect(h, 'f', 'out', 'sf', 'value');
      final result = lowerer.lower(
        h.current,
        _puzzle(output: 'bool', inputs: [
          {'name': 'found', 'type': 'bool'},
        ]),
      );
      expect(result.ok, isTrue, reason: '${result.errors}');
      final iff = result.program!.functions.single.body.single as IfStmt;
      expect(iff.elseBody, isNotNull);
      expect(iff.elseBody, hasLength(1));
      expect(iff.thenBody.single, isA<AssignStmt>());
      expect(iff.elseBody!.single, isA<AssignStmt>());
      expect(result.program!.functions.single.body.whereType<IfStmt>(), hasLength(1));
    });

    test('E WHILE', () {
      final h = _hist({'i': ValueType.number});
      _add(h, BlockIds.ctrlWhile, id: 'w1');
      _add(h, BlockIds.litBool, id: 'b1', literals: {'value': true});
      _add(h, BlockIds.varInc, id: 'inc', literals: {'name': 'i'});
      _connect(h, 'b1', 'out', 'w1', 'condition');
      _attach(h, 'w1', PortRef.mainBody);
      _attach(h, 'inc', const PortRef('w1', 'body'));
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final w = result.program!.functions.single.body.single as WhileStmt;
      expect(w.srcBlockId, 'w1');
      expect(w.body.single, isA<IncStmt>());
      expect(((w.body.single as IncStmt).target as VarLValue).name, 'i');
    });

    test('F nested IF inside WHILE', () {
      final h = _hist();
      _add(h, BlockIds.ctrlWhile, id: 'w1');
      _add(h, BlockIds.ctrlIf, id: 'if1');
      _add(h, BlockIds.litBool, id: 'b1', literals: {'value': true});
      _add(h, BlockIds.litBool, id: 'b2', literals: {'value': false});
      _add(h, BlockIds.ctrlBreak, id: 'br');
      _connect(h, 'b1', 'out', 'w1', 'condition');
      _connect(h, 'b2', 'out', 'if1', 'condition');
      _attach(h, 'w1', PortRef.mainBody);
      _attach(h, 'if1', const PortRef('w1', 'body'));
      _attach(h, 'br', const PortRef('if1', 'then'));
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final w = result.program!.functions.single.body.single as WhileStmt;
      final iff = w.body.single as IfStmt;
      expect(iff.thenBody.single, isA<BreakStmt>());
      expect(iff.thenBody.single.srcBlockId, 'br');
    });

    test('G array GET', () {
      final h = _hist({
        'nums': ValueType.array(ValueType.number),
        'x': ValueType.number,
      });
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.arrGet, id: 'get1');
      _add(h, BlockIds.varGet, id: 'nums', literals: {'name': 'nums'});
      _add(h, BlockIds.litNum, id: 'n0', literals: {'value': 0});
      _connect(h, 'get1', 'out', 'set1', 'value');
      _connect(h, 'nums', 'out', 'get1', 'array');
      _connect(h, 'n0', 'out', 'get1', 'index');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(
        h.current,
        _puzzle(inputs: [
          {'name': 'nums', 'type': 'array<num>'},
          {'name': 'x', 'type': 'num'},
        ]),
      );
      expect(result.ok, isTrue, reason: '${result.errors}');
      final assign = result.program!.functions.single.body.single as AssignStmt;
      final idx = assign.value as IndexExpr;
      expect(idx.srcBlockId, 'get1');
      expect((idx.collection as VarExpr).name, 'nums');
      expect(idx.type, ValueType.number);
    });

    test('H variable assignment source mapping', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.varGet, id: 'gx', literals: {'name': 'x'});
      _connect(h, 'gx', 'out', 'set1', 'value');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue);
      final assign = result.program!.functions.single.body.single as AssignStmt;
      expect(assign.srcBlockId, 'set1');
      expect((assign.target as VarLValue).srcBlockId, 'set1');
      expect(assign.value.srcBlockId, 'gx');
    });

    test('I RETURN', () {
      final h = _hist();
      _add(h, BlockIds.ctrlReturn, id: 'r1');
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 7});
      _connect(h, 'n1', 'out', 'r1', 'value');
      _attach(h, 'r1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final ret = result.program!.functions.single.body.single as ReturnStmt;
      expect(ret.srcBlockId, 'r1');
      expect((ret.value as LitExpr).value, 7);
    });

    test('J editor probe combination', () {
      final graph = _editorProbe();
      final puzzle = _puzzle(
        output: 'bool',
        inputs: [
          {'name': 'nums', 'type': 'array<num>'},
          {'name': 'target', 'type': 'num'},
        ],
      );
      final result = lowerer.lower(graph, puzzle);
      expect(result.ok, isTrue, reason: '${result.errors}');
      final body = result.program!.functions.single.body;
      expect(body, hasLength(2));
      final iff = body[0] as IfStmt;
      final gt = iff.cond as BinaryExpr;
      expect(gt.op, BinaryOp.gt);
      expect(gt.left, isA<IndexExpr>());
      expect(((gt.left as IndexExpr).collection as VarExpr).name, 'nums');
      expect(iff.thenBody.single, isA<AssignStmt>());
      expect(iff.elseBody!.single, isA<AssignStmt>());
      final w = body[1] as WhileStmt;
      expect((w.cond as BinaryExpr).op, BinaryOp.lt);
      final setI = w.body.single as AssignStmt;
      expect((setI.value as BinaryExpr).op, BinaryOp.add);
    });

    test('positions and collapsed do not change IR', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'}, x: 0, y: 0);
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 4});
      _connect(h, 'n1', 'out', 'set1', 'value');
      _attach(h, 'set1', PortRef.mainBody);
      final a = lowerer.lower(h.current, _puzzle());
      h.apply(MoveBlockCommand('set1', x: 40, y: 90));
      final moved = h.current.blocks['set1']!.copyWith(collapsed: true);
      final g2 = h.current.replaceBlock(moved);
      final b = lowerer.lower(g2, _puzzle());
      expect(a.program!.toJsonString(), b.program!.toJsonString());
    });

    test('JSON round trip', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 2});
      _connect(h, 'n1', 'out', 'set1', 'value');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      final json = result.program!.toJsonString();
      final restored = Program.fromJsonString(json);
      expect(restored.toJsonString(), json);
    });

    test('for-range has explicit loop var, start, end, body', () {
      final h = _hist();
      _add(h, BlockIds.ctrlForRange, id: 'fr', literals: {'name': 'i'});
      _add(h, BlockIds.litNum, id: 's', literals: {'value': 0});
      _add(h, BlockIds.litNum, id: 'e', literals: {'value': 3});
      _add(h, BlockIds.ctrlContinue, id: 'c1');
      _connect(h, 's', 'out', 'fr', 'start');
      _connect(h, 'e', 'out', 'fr', 'end');
      _attach(h, 'fr', PortRef.mainBody);
      _attach(h, 'c1', const PortRef('fr', 'body'));
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isTrue, reason: '${result.errors}');
      final fr = result.program!.functions.single.body.single as ForRangeStmt;
      expect(fr.srcBlockId, 'fr');
      expect(fr.loopVar, 'i');
      expect((fr.start as LitExpr).value, 0);
      expect((fr.end as LitExpr).value, 3);
      expect(fr.step, isNull);
      expect(fr.body.single, isA<ContinueStmt>());
      expect(fr.body.single.srcBlockId, 'c1');
    });

    test('for-each iterates a list into a typed item var', () {
      final h = _hist({
        'nums': ValueType.array(ValueType.number),
        'x': ValueType.number,
      });
      _add(h, BlockIds.ctrlForEach, id: 'fe', literals: {'name': 'x'});
      _add(h, BlockIds.varGet, id: 'nums', literals: {'name': 'nums'});
      _add(h, BlockIds.varInc, id: 'inc', literals: {'name': 'x'});
      _connect(h, 'nums', 'out', 'fe', 'collection');
      _attach(h, 'fe', PortRef.mainBody);
      _attach(h, 'inc', const PortRef('fe', 'body'));
      final result = lowerer.lower(
        h.current,
        _puzzle(inputs: [
          {'name': 'nums', 'type': 'array<num>'},
          {'name': 'x', 'type': 'num'},
        ]),
      );
      expect(result.ok, isTrue, reason: '${result.errors}');
      final fe = result.program!.functions.single.body.single as ForEachStmt;
      expect(fe.srcBlockId, 'fe');
      expect(fe.itemVar, 'x');
      expect((fe.collection as VarExpr).name, 'nums');
      expect(fe.body.single, isA<IncStmt>());
    });

    test('arr.len maps through the catalog, not a puzzle id', () {
      final h = _hist({
        'nums': ValueType.array(ValueType.number),
        'x': ValueType.number,
      });
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.arrLen, id: 'len1');
      _add(h, BlockIds.varGet, id: 'nums', literals: {'name': 'nums'});
      _connect(h, 'len1', 'out', 'set1', 'value');
      _connect(h, 'nums', 'out', 'len1', 'array');
      _attach(h, 'set1', PortRef.mainBody);
      final result = lowerer.lower(
        h.current,
        _puzzle(inputs: [
          {'name': 'nums', 'type': 'array<num>'},
          {'name': 'x', 'type': 'num'},
        ]),
      );
      expect(result.ok, isTrue, reason: '${result.errors}');
      final assign = result.program!.functions.single.body.single as AssignStmt;
      final call = assign.value as CallExpr;
      expect(call.callee, BlockIds.arrLen);
      expect(call.srcBlockId, 'len1');
      expect(call.type, ValueType.number);
    });

    test('top-level lower matches Lowerer.lower', () {
      final h = _hist({'x': ValueType.number});
      _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
      _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 9});
      _connect(h, 'n1', 'out', 'set1', 'value');
      _attach(h, 'set1', PortRef.mainBody);
      final a = lowerer.lower(h.current, _puzzle());
      final b = lower(h.current, _puzzle());
      expect(a.program!.toJsonString(), b.program!.toJsonString());
    });
  });

  group('invalid lowering', () {
    test('missing required expression', () {
      final h = _hist();
      _add(h, BlockIds.ctrlIf, id: 'if1');
      _attach(h, 'if1', PortRef.mainBody);
      final result = lowerer.lower(h.current, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'missing_expr'), isTrue);
      expect(result.errors.first.message, isNot(contains('syntax')));
    });

    test('unresolved variable', () {
      const graph = BlockGraph(
        blocks: {
          'set1': BlockInstance(
            id: 'set1',
            catalogId: BlockIds.varSet,
            literals: {'name': 'ghost'},
            slots: {'value': RefBinding('n1')},
          ),
          'n1': BlockInstance(
            id: 'n1',
            catalogId: BlockIds.litNum,
            literals: {'value': 1},
          ),
        },
        entryIds: ['set1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'undefined_variable'), isTrue);
    });

    test('invalid block id', () {
      const graph = BlockGraph(
        blocks: {
          'a': BlockInstance(id: 'a', catalogId: 'not.a.block'),
        },
        entryIds: ['a'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'unknown_block'), isTrue);
    });

    test('malformed statement nesting', () {
      const graph = BlockGraph(
        blocks: {
          'n1': BlockInstance(id: 'n1', catalogId: BlockIds.litNum),
        },
        entryIds: ['n1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'wrong_kind'), isTrue);
    });

    test('invalid ELSE structure', () {
      final h = _hist();
      _add(h, BlockIds.ctrlIf, id: 'if1');
      _add(h, BlockIds.litBool, id: 'b1', literals: {'value': true});
      _add(h, BlockIds.ctrlReturn, id: 'r1');
      _connect(h, 'b1', 'out', 'if1', 'condition');
      _attach(h, 'if1', PortRef.mainBody);
      // Force a return onto the else port via raw graph (illegal).
      final bad = h.current.replaceBlock(
        h.current.blocks['if1']!.copyWith(
          slots: {
            ...h.current.blocks['if1']!.slots,
            'else': const ListBinding(['r1']),
          },
        ),
      );
      final result = lowerer.lower(bad, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'wrong_kind'), isTrue);
    });

    test('invalid port relationship', () {
      const graph = BlockGraph(
        blocks: {
          'if1': BlockInstance(
            id: 'if1',
            catalogId: BlockIds.ctrlIf,
            slots: {'banana': RefBinding('b1')},
          ),
          'b1': BlockInstance(id: 'b1', catalogId: BlockIds.litBool),
        },
        entryIds: ['if1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'unknown_port'), isTrue);
    });

    test('a CALL that names no function (L2)', () {
      // The editor never builds this (an unnamed CALL has no type to snap
      // with); lowering still refuses it in words.
      const graph = BlockGraph(
        blocks: {
          'c1': BlockInstance(id: 'c1', catalogId: BlockIds.fnCall),
          'r1': BlockInstance(id: 'r1', catalogId: BlockIds.ctrlReturn, slots: {'value': RefBinding('c1')}),
        },
        entryIds: ['r1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.map((e) => e.code), contains('undefined_function'));
    });

    test('does not throw on malformed graphs', () {
      const graph = BlockGraph(
        blocks: {
          'if1': BlockInstance(
            id: 'if1',
            catalogId: BlockIds.ctrlIf,
            slots: {'condition': RefBinding('ghost')},
          ),
        },
        entryIds: ['if1'],
      );
      expect(() => lowerer.lower(graph, _puzzle()), returnsNormally);
      expect(lowerer.lower(graph, _puzzle()).ok, isFalse);
    });

    test('number in a condition is a type mismatch, not a Program', () {
      const graph = BlockGraph(
        blocks: {
          'if1': BlockInstance(
            id: 'if1',
            catalogId: BlockIds.ctrlIf,
            slots: {'condition': RefBinding('n1')},
          ),
          'n1': BlockInstance(
            id: 'n1',
            catalogId: BlockIds.litNum,
            literals: {'value': 1},
          ),
        },
        entryIds: ['if1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'type_mismatch'), isTrue);
      expect(result.errors.first.message, isNot(contains('TypeError')));
      expect(result.errors.first.message, isNot(contains('syntax')));
    });

    test('bool operands on PLUS fail instead of untyped IR', () {
      const graph = BlockGraph(
        blocks: {
          'set1': BlockInstance(
            id: 'set1',
            catalogId: BlockIds.varSet,
            literals: {'name': 'x'},
            slots: {'value': RefBinding('add1')},
          ),
          'add1': BlockInstance(
            id: 'add1',
            catalogId: BlockIds.arithAdd,
            slots: {
              'left': RefBinding('t'),
              'right': RefBinding('f'),
            },
          ),
          't': BlockInstance(
            id: 't',
            catalogId: BlockIds.litBool,
            literals: {'value': true},
          ),
          'f': BlockInstance(
            id: 'f',
            catalogId: BlockIds.litBool,
            literals: {'value': false},
          ),
        },
        variables: {'x': ValueType.number},
        entryIds: ['set1'],
      );
      final result = lowerer.lower(graph, _puzzle());
      expect(result.ok, isFalse);
      expect(result.errors.any((e) => e.code == 'type_mismatch'), isTrue);
    });
  });

  test('engine.lower uses the same pipeline', () {
    const engine = DefaultEngine();
    final h = _hist({'x': ValueType.number});
    _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
    _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 1});
    _connect(h, 'n1', 'out', 'set1', 'value');
    _attach(h, 'set1', PortRef.mainBody);
    final result = engine.lower(h.current, _puzzle());
    expect(result.ok, isTrue);
    expect(result.program!.functions.single.body, hasLength(1));
  });
}

GraphHistory _hist([Map<String, ValueType> variables = const {}]) =>
    GraphHistory(BlockGraph(blocks: const {}, variables: variables));

String _add(
  GraphHistory h,
  String catalogId, {
  required String id,
  Map<String, Object?> literals = const {},
  double x = 0,
  double y = 0,
}) {
  final r = h.apply(AddBlockCommand(
    catalogId: catalogId,
    id: id,
    literals: literals,
    x: x,
    y: y,
  ));
  expect(r.ok, isTrue, reason: r.decision.message);
  return id;
}

void _connect(
  GraphHistory h,
  String from,
  String fromPort,
  String to,
  String toPort,
) {
  final r = h.apply(ConnectCommand(
    from: PortRef(from, fromPort),
    to: PortRef(to, toPort),
  ));
  expect(r.ok, isTrue, reason: r.decision.message);
}

void _attach(GraphHistory h, String blockId, PortRef to) {
  final r = h.apply(AttachStatementCommand(blockId: blockId, to: to));
  expect(r.ok, isTrue, reason: r.decision.message);
}

BlockGraph _editorProbe() {
  final h = _hist({
    'nums': ValueType.array(ValueType.number),
    'target': ValueType.number,
    'i': ValueType.number,
    'found': ValueType.boolean,
  });
  _add(h, BlockIds.ctrlIf, id: 'if1');
  _add(h, BlockIds.cmpGt, id: 'gt1');
  _add(h, BlockIds.arrGet, id: 'get1');
  _add(h, BlockIds.varGet, id: 'nums', literals: {'name': 'nums'});
  _add(h, BlockIds.litNum, id: 'z', literals: {'value': 0});
  _add(h, BlockIds.litNum, id: 'three', literals: {'value': 3});
  _add(h, BlockIds.varSet, id: 'st', literals: {'name': 'found'});
  _add(h, BlockIds.litBool, id: 't', literals: {'value': true});
  _add(h, BlockIds.ctrlElse, id: 'else1');
  _add(h, BlockIds.varSet, id: 'sf', literals: {'name': 'found'});
  _add(h, BlockIds.litBool, id: 'f', literals: {'value': false});
  _add(h, BlockIds.ctrlWhile, id: 'w1');
  _add(h, BlockIds.cmpLt, id: 'lt1');
  _add(h, BlockIds.varGet, id: 'gi', literals: {'name': 'i'});
  _add(h, BlockIds.varGet, id: 'gtgt', literals: {'name': 'target'});
  _add(h, BlockIds.varSet, id: 'si', literals: {'name': 'i'});
  _add(h, BlockIds.arithAdd, id: 'plus');
  _add(h, BlockIds.varGet, id: 'gi2', literals: {'name': 'i'});
  _add(h, BlockIds.litNum, id: 'one', literals: {'value': 1});

  _attach(h, 'if1', PortRef.mainBody);
  _connect(h, 'gt1', 'out', 'if1', 'condition');
  _connect(h, 'get1', 'out', 'gt1', 'left');
  _connect(h, 'nums', 'out', 'get1', 'array');
  _connect(h, 'z', 'out', 'get1', 'index');
  _connect(h, 'three', 'out', 'gt1', 'right');
  _attach(h, 'st', const PortRef('if1', 'then'));
  _connect(h, 't', 'out', 'st', 'value');
  _connect(h, 'else1', 'clause', 'if1', 'else');
  _attach(h, 'sf', const PortRef('else1', 'body'));
  _connect(h, 'f', 'out', 'sf', 'value');

  _attach(h, 'w1', PortRef.mainBody);
  _connect(h, 'lt1', 'out', 'w1', 'condition');
  _connect(h, 'gi', 'out', 'lt1', 'left');
  _connect(h, 'gtgt', 'out', 'lt1', 'right');
  _attach(h, 'si', const PortRef('w1', 'body'));
  _connect(h, 'plus', 'out', 'si', 'value');
  _connect(h, 'gi2', 'out', 'plus', 'left');
  _connect(h, 'one', 'out', 'plus', 'right');
  return h.current;
}
