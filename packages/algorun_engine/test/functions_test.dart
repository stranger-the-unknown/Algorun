import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// L2: player functions and recursion. A puzzle declares the functions; the
/// editor puts a FUNCTION block for each at the top; CALL runs one in a new
/// frame, one level deeper.

Puzzle _puzzle({
  required List<Map<String, Object?>> inputs,
  required String output,
  required List<Map<String, Object?>> functions,
  List<Map<String, Object?>> pool = const [],
  List<String> allow = const ['ctrl.return'],
  int maxDepth = 32,
  Object? sampleIn,
  Object? sampleOut = 1,
}) {
  final given = sampleIn ?? <String, Object?>{for (final i in inputs) i['name']! as String: i['type'] == 'num' ? 1 : null};
  return parsePuzzleMap({
    'id': 'l2_probe',
    'title': 'L2',
    'world': 'world_12',
    'tier': 2,
    'mode': 'build',
    'story': 's',
    'io': {'inputs': inputs, 'output': {'type': output}},
    'blocks': {'allow': allow},
    'limits': {'maxOps': 100000, 'maxDepth': maxDepth},
    'validators': {'output': 'equal'},
    'fixtures': {
      'visible': [{'id': 'v1', 'in': given, 'out': sampleOut}],
      'hidden': [{'id': 'h1', 'in': given, 'out': sampleOut}],
    },
    'variables': {'pool': pool},
    'functions': functions,
  });
}

/// Builds top-down with the editor's own commands: every value is placed
/// into a hole whose block already sits in the program, as a player would.
final class _B {
  _B(BlockGraph start) : h = GraphHistory(start);

  final GraphHistory h;
  var _n = 0;

  BlockGraph get graph => h.current;

  String _new(String catalogId, [Map<String, Object?> literals = const {}]) {
    final id = 'k${_n++}';
    _ok(h.apply(AddBlockCommand(catalogId: catalogId, id: id, literals: literals)));
    return id;
  }

  void _ok(GraphMutationResult r) => expect(r.ok, isTrue, reason: '${r.decision.code} ${r.decision.message}');

  /// A statement at the end of [well].
  String stmt(String catalogId, PortRef well, [Map<String, Object?> literals = const {}]) {
    final id = _new(catalogId, literals);
    _ok(h.apply(AttachStatementCommand(blockId: id, to: well, index: graph.slotList(well.blockId, well.port).length)));
    return id;
  }

  /// A value plugged into [parent].[port].
  String val(String catalogId, String parent, String port, [Map<String, Object?> literals = const {}]) {
    final id = _new(catalogId, literals);
    _ok(h.apply(ConnectCommand(from: PortRef(id, 'out'), to: PortRef(parent, port))));
    return id;
  }

  /// Like [val], expecting the editor to refuse it with [code].
  void refused(String catalogId, String parent, String port, String code, [Map<String, Object?> literals = const {}]) {
    final id = _new(catalogId, literals);
    final r = h.apply(ConnectCommand(from: PortRef(id, 'out'), to: PortRef(parent, port)));
    expect(r.ok, isFalse);
    expect(r.decision.code, code);
  }

  String get(String name, String parent, String port) => val(BlockIds.varGet, parent, port, {'name': name});

  String num(int value, String parent, String port) => val(BlockIds.litNum, parent, port, {'value': value});
}

const _fact = {
  'name': 'fact',
  'params': [
    {'name': 'k', 'type': 'num'},
  ],
  'returns': 'num',
};

/// fact(k) = k <= 1 ? 1 : k * fact(k - 1); main returns fact(n).
(Puzzle, BlockGraph) _factorial({int maxDepth = 32}) {
  final puzzle = _puzzle(
    inputs: [
      {'name': 'n', 'type': 'num'},
    ],
    output: 'num',
    functions: [_fact],
    maxDepth: maxDepth,
  );
  final b = _B(FunctionSetup.ensure(BlockGraph(blocks: const {}, variables: {'n': ValueType.number}), puzzle.functions));
  const body = PortRef('fn_fact', 'body');
  final iff = b.stmt(BlockIds.ctrlIf, body);
  final le = b.val(BlockIds.cmpLe, iff, 'condition');
  b.get('k', le, 'left');
  b.num(1, le, 'right');
  final r1 = b.stmt(BlockIds.ctrlReturn, PortRef(iff, 'then'));
  b.num(1, r1, 'value');
  final r2 = b.stmt(BlockIds.ctrlReturn, body);
  final mul = b.val(BlockIds.arithMul, r2, 'value');
  b.get('k', mul, 'left');
  final call = b.val(BlockIds.fnCall1, mul, 'right', {'name': 'fact'});
  final sub = b.val(BlockIds.arithSub, call, 'a1');
  b.get('k', sub, 'left');
  b.num(1, sub, 'right');
  final ret = b.stmt(BlockIds.ctrlReturn, PortRef.mainBody);
  final top = b.val(BlockIds.fnCall1, ret, 'value', {'name': 'fact'});
  b.get('n', top, 'a1');
  return (puzzle, b.graph);
}

RunResult _run(Puzzle puzzle, BlockGraph graph, Map<String, Object?> input, {int maxDepth = 32}) {
  final lowered = lower(graph, puzzle);
  expect(lowered.ok, isTrue, reason: '${lowered.errors.map((e) => '${e.code}: ${e.message}')}');
  final types = {for (final i in puzzle.io.inputs) i.name: i.type};
  return runProgram(
    lowered.program!,
    {for (final e in input.entries) e.key: valueFromJson(e.value, type: types[e.key]!)},
    RunLimits(maxOps: 1000000, maxDepth: maxDepth, maxAlloc: 100000),
  );
}

void main() {
  group('puzzle schema', () {
    test('functions are read with their parameters and return type', () {
      final p = _puzzle(inputs: [
        {'name': 'n', 'type': 'num'},
      ], output: 'num', functions: [_fact]);
      expect(p.functions.single.name, 'fact');
      expect(p.functions.single.params.single, const FunctionParam('k', ValueType.number));
      expect(p.functions.single.returns, ValueType.number);
    });

    for (final (why, fn) in [
      ('a parameter named like an input', {
        'name': 'f',
        'params': [
          {'name': 'n', 'type': 'num'},
        ],
        'returns': 'num',
      }),
      ('more than three parameters', {
        'name': 'f',
        'params': [
          for (final p in ['a', 'b', 'c', 'd']) {'name': p, 'type': 'num'},
        ],
        'returns': 'num',
      }),
      ('the name main', {'name': 'main', 'params': <Object?>[], 'returns': 'num'}),
      ('a name with capitals', {'name': 'Fact', 'params': <Object?>[], 'returns': 'num'}),
    ]) {
      test('refuses $why', () {
        expect(
          () => _puzzle(inputs: [
            {'name': 'n', 'type': 'num'},
          ], output: 'num', functions: [fn]),
          throwsA(isA<SchemaException>()),
        );
      });
    }
  });

  group('setup', () {
    final puzzle = _puzzle(inputs: [
      {'name': 'n', 'type': 'num'},
    ], output: 'num', functions: [_fact]);

    test('puts a FUNCTION at the top and declares its parameters', () {
      final g = FunctionSetup.ensure(
        const BlockGraph(blocks: {'r': BlockInstance(id: 'r', catalogId: BlockIds.ctrlReturn)}, entryIds: ['r']),
        puzzle.functions,
      );
      expect(g.entryIds, ['fn_fact', 'r']);
      expect(g.blocks['fn_fact']!.catalogId, BlockIds.fnDef);
      expect(g.variables['k'], ValueType.number);
      expect(FunctionTable.of(g)['fact'], puzzle.functions.single);
    });

    test('is idempotent, keeps the body and updates a changed signature', () {
      final (_, graph) = _factorial();
      expect(FunctionSetup.ensure(graph, puzzle.functions).entryIds, graph.entryIds);
      const changed = FunctionSignature(
        name: 'fact',
        params: [FunctionParam('k', ValueType.number)],
        returns: ValueType.boolean,
      );
      final g = FunctionSetup.ensure(graph, [changed]);
      expect(FunctionTable.of(g)['fact']!.returns, ValueType.boolean);
      expect(g.slotList('fn_fact', 'body'), graph.slotList('fn_fact', 'body'));
    });
  });

  group('typing', () {
    test('CALL is offered per function with the right number of values', () {
      final puzzle = _puzzle(inputs: [
        {'name': 'n', 'type': 'num'},
      ], output: 'num', functions: [_fact]);
      final b = _B(FunctionSetup.ensure(BlockGraph(blocks: const {}, variables: {'n': ValueType.number}), puzzle.functions));
      final ret = b.stmt(BlockIds.ctrlReturn, PortRef.mainBody);
      final placements = GraphTyping.compatiblePlacements(
        b.graph,
        to: PortRef(ret, 'value'),
        allow: [BlockIds.fnCall, BlockIds.fnCall1, BlockIds.fnCall2],
      );
      expect([for (final p in placements) '${p.catalogId} ${p.literals['name']}'], ['fn.call1 fact']);
    });

    test('values passed and values returned have the declared types', () {
      final puzzle = _puzzle(inputs: [
        {'name': 'n', 'type': 'num'},
      ], output: 'num', functions: [_fact]);
      final b = _B(FunctionSetup.ensure(BlockGraph(blocks: const {}, variables: {'n': ValueType.number}), puzzle.functions));
      final r = b.stmt(BlockIds.ctrlReturn, const PortRef('fn_fact', 'body'));
      b.refused(BlockIds.litBool, r, 'value', 'type_mismatch', {'value': true});
      final call = b.val(BlockIds.fnCall1, r, 'value', {'name': 'fact'});
      expect(GraphTyping.resolveOutput(b.graph, call), ValueType.number);
      b.refused(BlockIds.litBool, call, 'a1', 'type_mismatch', {'value': true});
    });
  });

  group('running', () {
    test('a recursive function: 5! = 120, one level per call', () {
      final (puzzle, graph) = _factorial();
      final run = _run(puzzle, graph, {'n': 5});
      expect(run.kind, ResultKind.correct, reason: run.message);
      expect((run.output! as NumValue).value, 120);
      expect(run.metrics.peakDepth, 6, reason: 'main, then fact(5) down to fact(1)');
    });

    test('too deep stops with DEPTH LIMIT', () {
      final (puzzle, graph) = _factorial(maxDepth: 10);
      final run = _run(puzzle, graph, {'n': 50}, maxDepth: 10);
      expect(run.kind, ResultKind.depthLimit);
    });

    test('recursion over a tree: the height of a tree', () {
      final puzzle = _puzzle(
        inputs: [
          {'name': 'root', 'type': 'treeNode?'},
        ],
        output: 'num',
        functions: [
          {
            'name': 'height',
            'params': [
              {'name': 'node', 'type': 'treeNode?'},
            ],
            'returns': 'num',
          },
        ],
        sampleIn: {'root': null},
        sampleOut: 0,
      );
      final b = _B(FunctionSetup.ensure(
        BlockGraph(blocks: const {}, variables: {'root': ValueType.treeNode.asNullable}),
        puzzle.functions,
      ));
      const body = PortRef('fn_height', 'body');
      final iff = b.stmt(BlockIds.ctrlIf, body);
      final check = b.val(BlockIds.logicIsNothing, iff, 'condition');
      b.get('node', check, 'value');
      final r0 = b.stmt(BlockIds.ctrlReturn, PortRef(iff, 'then'));
      b.num(0, r0, 'value');
      // ELSE: 1 + MAX(height(LEFT node), height(RIGHT node)); node is
      // narrowed there.
      final els = b._new(BlockIds.ctrlElse);
      b._ok(b.h.apply(ConnectCommand(from: PortRef(els, 'clause'), to: PortRef(iff, 'else'))));
      final r1 = b.stmt(BlockIds.ctrlReturn, PortRef(els, 'body'));
      final add = b.val(BlockIds.arithAdd, r1, 'value');
      b.num(1, add, 'left');
      final mx = b.val(BlockIds.arithMax, add, 'right');
      final cl = b.val(BlockIds.fnCall1, mx, 'left', {'name': 'height'});
      final left = b.val(BlockIds.treeLeft, cl, 'a1');
      b.get('node', left, 'node');
      final cr = b.val(BlockIds.fnCall1, mx, 'right', {'name': 'height'});
      final right = b.val(BlockIds.treeRight, cr, 'a1');
      b.get('node', right, 'node');
      final ret = b.stmt(BlockIds.ctrlReturn, PortRef.mainBody);
      final top = b.val(BlockIds.fnCall1, ret, 'value', {'name': 'height'});
      b.get('root', top, 'a1');

      Object? t(int v, [Object? l, Object? r]) =>
          {'type': 'treeNode', 'value': v, 'left': ?l, 'right': ?r};
      for (final (tree, want) in [
        (null, 0),
        (t(1), 1),
        (t(1, t(2, t(3)), t(4)), 3),
        (t(1, null, t(2, null, t(3, null, t(4)))), 4),
      ]) {
        final run = _run(puzzle, b.graph, {'root': tree});
        expect(run.kind, ResultKind.correct, reason: run.message);
        expect((run.output! as NumValue).value, want, reason: jsonEncode(tree));
      }
    });

    test('each call has its own variables; lists are shared', () {
      // fill(xs, k): SET count TO k; APPEND count to xs; RETURN k.
      // main: SET count TO 7; SET out TO fill(list, 3); RETURN count.
      final puzzle = _puzzle(
        inputs: [
          {'name': 'list', 'type': 'array<num>'},
        ],
        output: 'num',
        pool: [
          {'name': 'count', 'type': 'num'},
          {'name': 'out', 'type': 'num'},
        ],
        functions: [
          {
            'name': 'fill',
            'params': [
              {'name': 'xs', 'type': 'array<num>'},
              {'name': 'k', 'type': 'num'},
            ],
            'returns': 'num',
          },
        ],
        sampleIn: {'list': <int>[]},
      );
      final b = _B(FunctionSetup.ensure(
        BlockGraph(blocks: const {}, variables: {
          'list': ValueType.array(ValueType.number),
          'count': ValueType.number,
          'out': ValueType.number,
        }),
        puzzle.functions,
      ));
      const body = PortRef('fn_fill', 'body');
      final s1 = b.stmt(BlockIds.varSet, body, {'name': 'count'});
      b.get('k', s1, 'value');
      final app = b.stmt(BlockIds.arrAppend, body);
      b.get('xs', app, 'array');
      b.get('count', app, 'value');
      final r = b.stmt(BlockIds.ctrlReturn, body);
      b.get('k', r, 'value');
      final m1 = b.stmt(BlockIds.varSet, PortRef.mainBody, {'name': 'count'});
      b.num(7, m1, 'value');
      final m2 = b.stmt(BlockIds.varSet, PortRef.mainBody, {'name': 'out'});
      final call = b.val(BlockIds.fnCall2, m2, 'value', {'name': 'fill'});
      b.get('list', call, 'a1');
      b.num(3, call, 'a2');
      // RETURN count PLUS LENGTH list: 7 + 1 when the function's count is its
      // own and its APPEND reached main's list.
      final m3 = b.stmt(BlockIds.ctrlReturn, PortRef.mainBody);
      final plus = b.val(BlockIds.arithAdd, m3, 'value');
      b.get('count', plus, 'left');
      final len = b.val(BlockIds.arrLen, plus, 'right');
      b.get('list', len, 'array');
      final run = _run(puzzle, b.graph, {'list': <int>[]});
      expect(run.kind, ResultKind.correct, reason: run.message);
      expect((run.output! as NumValue).value, 8);
    });
  });

  group('lowering errors', () {
    test('a FUNCTION moved inside another block', () {
      final (puzzle, graph) = _factorial();
      final h = GraphHistory(graph);
      h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'wrap'));
      h.apply(AttachStatementCommand(blockId: 'wrap', to: PortRef.mainBody, index: 0));
      final moved = h.current.detach('fn_fact');
      final inside = moved.copyWith(blocks: {
        ...moved.blocks,
        'wrap': moved.blocks['wrap']!.copyWith(slots: {'then': const ListBinding(['fn_fact'])}),
      });
      final result = lower(inside, puzzle);
      expect(result.errors.map((e) => e.code), contains('nested_function'));
    });

    test('a CALL to a function that is not there', () {
      final (puzzle, graph) = _factorial();
      final call = graph.blocks.values.firstWhere((b) => b.catalogId == BlockIds.fnCall1);
      final g = graph.replaceBlock(call.copyWith(literals: {'name': 'ghost'}));
      expect(lower(g, puzzle).errors.map((e) => e.code), contains('undefined_function'));
    });

    test('a given read inside a FUNCTION', () {
      final (puzzle, graph) = _factorial();
      final inside = graph.blocks.values.firstWhere(
        (b) => b.catalogId == BlockIds.varGet && b.literals['name'] == 'k' && FunctionTable.enclosing(graph, b.id) != null,
      );
      final g = graph.replaceBlock(inside.copyWith(literals: {'name': 'n'}));
      expect(lower(g, puzzle).errors.map((e) => e.code), contains('not_in_function'));
    });

    test('a FUNCTION that ends without RETURN stops the run', () {
      final (puzzle, graph) = _factorial();
      // Keep only the IF in fact's body: k > 1 falls off the end.
      final body = graph.slotList('fn_fact', 'body');
      final g = graph.replaceBlock(graph.blocks['fn_fact']!.copyWith(slots: {'body': ListBinding([body.first])}));
      final run = _run(puzzle, g, {'n': 3});
      expect(run.kind, ResultKind.runtimeError);
      expect(run.message, 'FUNCTION fact ended without RETURN.');
    });
  });
}
