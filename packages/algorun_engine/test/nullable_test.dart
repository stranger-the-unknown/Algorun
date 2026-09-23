import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// L1: values that may be empty, IS NOTHING / IS NOT NOTHING, and narrowing.

const _mayBeEmpty = 'This value may be empty here. Check that it is not empty first.';

/// Builds a BlockGraph the way the editor stores it, with readable helpers.
final class _G {
  final blocks = <String, Map<String, Object?>>{};
  var _n = 0;

  String add(
    String catalogId, {
    Map<String, Object?> literals = const {},
    Map<String, Object?> slots = const {},
  }) {
    final id = 'b${++_n}';
    blocks[id] = {'id': id, 'catalogId': catalogId, 'literals': literals, 'slots': slots};
    return id;
  }

  String v(String name) => add(BlockIds.varGet, literals: {'name': name});
  String n(num value) => add(BlockIds.litNum, literals: {'value': value});
  String set(String name, String value) =>
      add(BlockIds.varSet, literals: {'name': name}, slots: {'value': {'ref': value}});
  String ret(String value) => add(BlockIds.ctrlReturn, slots: {'value': {'ref': value}});
  String isNot(String value) => add(BlockIds.logicIsNotNothing, slots: {'value': {'ref': value}});
  String isNothing(String value) => add(BlockIds.logicIsNothing, slots: {'value': {'ref': value}});
  String of(String catalogId, String node) => add(catalogId, slots: {'node': {'ref': node}});
  String bin(String catalogId, String left, String right) =>
      add(catalogId, slots: {'left': {'ref': left}, 'right': {'ref': right}});

  String iff(String cond, List<String> then, {List<String>? orElse}) {
    final slots = <String, Object?>{
      'condition': {'ref': cond},
      'then': {'list': then},
    };
    if (orElse != null) {
      slots['else'] = {'ref': add(BlockIds.ctrlElse, slots: {'body': {'list': orElse}})};
    }
    return add(BlockIds.ctrlIf, slots: slots);
  }

  String loop(String cond, List<String> body) => add(
        BlockIds.ctrlWhile,
        slots: {'condition': {'ref': cond}, 'body': {'list': body}},
      );

  BlockGraph graph(List<String> entry, Map<String, String> variables) =>
      BlockGraph.fromJson({'variables': variables, 'entryIds': entry, 'blocks': blocks});
}

const _samples = {
  'num': '1',
  'num?': 'null',
  'str': '"a"',
  'bool': 'true',
  'listNode': '{ "type": "listNode", "values": [1] }',
  'listNode?': 'null',
  'treeNode': '{ "type": "treeNode", "value": 1 }',
  'treeNode?': 'null',
  'map<str,num>': '{ "type": "map", "entries": [["a", 1]] }',
};

/// A puzzle with [inputs] (name → type). Lowering reads only its inputs.
Puzzle _puzzle(Map<String, String> inputs, {String output = 'num'}) {
  final io = [
    for (final e in inputs.entries) '{ "name": "${e.key}", "type": "${e.value}" }',
  ].join(', ');
  final given = [for (final e in inputs.entries) '"${e.key}": ${_samples[e.value]}'].join(', ');
  return parsePuzzleJson('''
{
  "id": "l1_probe", "title": "L1", "world": "world_01", "tier": 1, "mode": "build",
  "story": "s",
  "io": { "inputs": [$io], "output": { "type": "$output" } },
  "blocks": { "allow": ["var.get"] },
  "limits": { "maxOps": 100000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { $given }, "out": ${_samples[output]} }],
    "hidden": [{ "id": "h1", "in": { $given }, "out": ${_samples[output]} }]
  }
}
''');
}

/// Lowers [graph] against a puzzle that gives [inputs].
LowerResult _lower(BlockGraph graph, Map<String, String> inputs) =>
    lower(graph, _puzzle(inputs));

RunResult _run(Program program, Map<String, RuntimeValue> input) =>
    const DefaultEngine().run(program, input, RunLimits.standard);

Program _ok(BlockGraph graph, Map<String, String> inputs) {
  final result = _lower(graph, inputs);
  expect(result.ok, isTrue, reason: '${result.errors.map((e) => '${e.code} ${e.message} @${e.blockId}')}');
  return result.program!;
}

void _fails(BlockGraph graph, Map<String, String> inputs, String code, {String? message, String? blockId}) {
  final result = _lower(graph, inputs);
  expect(result.ok, isFalse, reason: 'expected $code');
  final match = result.errors.where((e) => e.code == code);
  expect(match, isNotEmpty, reason: '${result.errors.map((e) => '${e.code} ${e.message}')}');
  if (message != null) expect(match.first.message, message);
  if (blockId != null) expect(match.map((e) => e.blockId), contains(blockId));
}

ListNodeValue _list(List<num> values) {
  ListNodeValue? head;
  for (final v in values.reversed) {
    head = ListNodeValue(v, next: head);
  }
  return head!;
}

num _number(RunResult result) {
  expect(result.kind, ResultKind.correct, reason: result.message);
  return (result.output as NumValue).value;
}

void main() {
  group('values that may be empty are ordinary values', () {
    test('1. a variable that may be empty holds LEFT of a node', () {
      final g = _G();
      final entry = [g.set('child', g.of(BlockIds.treeLeft, g.v('root'))), g.ret(g.n(0))];
      final program = _ok(
        g.graph(entry, {'root': 'treeNode', 'child': 'treeNode?'}),
        {'root': 'treeNode'},
      );
      final assign = program.functions.single.body.first as AssignStmt;
      expect(assign.value.type, ValueType.treeNode.asNullable);
    });

    test('2. a plain variable cannot take a value that may be empty', () {
      final g = _G();
      final set = g.set('n', g.of(BlockIds.llNext, g.v('head')));
      _fails(
        g.graph([set], {'head': 'listNode', 'n': 'listNode'}),
        {'head': 'listNode'},
        'may_be_empty',
        message: _mayBeEmpty,
        blockId: set,
      );
    });

    test('2b. the editor refuses the same drop with the same words', () {
      final g = _G();
      final next = g.of(BlockIds.llNext, g.v('head'));
      final set = g.add(BlockIds.varSet, literals: {'name': 'n'});
      final graph = g.graph([set], {'head': 'listNode', 'n': 'listNode'});
      final d = GraphTyping.canConnect(graph, from: PortRef(next, 'out'), to: PortRef(set, 'value'));
      expect(d.allowed, isFalse);
      expect(d.code, 'may_be_empty');
      expect(d.message, _mayBeEmpty);
    });

    test('a checked value may go into a plain variable', () {
      final g = _G();
      final entry = [
        g.set('maybe', g.of(BlockIds.llNext, g.v('head'))),
        g.iff(g.isNot(g.v('maybe')), [g.set('sure', g.v('maybe'))]),
        g.ret(g.n(0)),
      ];
      _ok(g.graph(entry, {'head': 'listNode', 'maybe': 'listNode?', 'sure': 'listNode'}), {'head': 'listNode'});
    });

    test('SET NEXT takes a value that may be empty or NOTHING', () {
      final g = _G();
      final entry = [
        g.add(BlockIds.llSetNext, slots: {
          'node': {'ref': g.v('head')},
          'next': {'ref': g.of(BlockIds.llNext, g.v('head'))},
        }),
        g.add(BlockIds.llSetNext, slots: {
          'node': {'ref': g.v('head')},
          'next': {'ref': g.add(BlockIds.litNull)},
        }),
        g.ret(g.n(0)),
      ];
      _ok(g.graph(entry, {'head': 'listNode'}), {'head': 'listNode'});
    });
  });

  group('narrowing', () {
    test('3. inside IF x IS NOT NOTHING, x is a plain node', () {
      final g = _G();
      final read = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [
        g.set('result', g.n(0)),
        g.iff(g.isNot(g.v('x')), [g.set('result', read)]),
        g.ret(g.v('result')),
      ];
      final program = _ok(g.graph(entry, {'x': 'treeNode?', 'result': 'num'}), {'x': 'treeNode?'});
      final iff = program.functions.single.body[1] as IfStmt;
      final field = (iff.thenBody.single as AssignStmt).value as FieldExpr;
      expect(field.object.type, ValueType.treeNode);
    });

    test('3b. the same read without the check is refused before it runs', () {
      final g = _G();
      final read = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [g.set('result', read), g.ret(g.v('result'))];
      _fails(
        g.graph(entry, {'x': 'treeNode?', 'result': 'num'}),
        {'x': 'treeNode?'},
        'may_be_empty',
        message: _mayBeEmpty,
        blockId: read,
      );
    });

    test('4. after the IF, x may be empty again', () {
      final g = _G();
      final after = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [
        g.iff(g.isNot(g.v('x')), [g.set('result', g.of(BlockIds.treeValue, g.v('x')))]),
        g.set('result', after),
        g.ret(g.v('result')),
      ];
      _fails(g.graph(entry, {'x': 'treeNode?', 'result': 'num'}), {'x': 'treeNode?'}, 'may_be_empty',
          blockId: after);
    });

    test('4b. IS NOTHING narrows its ELSE, not its THEN', () {
      final g = _G();
      final entry = [
        g.iff(
          g.isNothing(g.v('x')),
          [g.ret(g.n(0))],
          orElse: [g.ret(g.of(BlockIds.treeValue, g.v('x')))],
        ),
      ];
      _ok(g.graph(entry, {'x': 'treeNode?'}), {'x': 'treeNode?'});

      final h = _G();
      final inThen = h.of(BlockIds.treeValue, h.v('x'));
      _fails(
        h.graph([h.iff(h.isNothing(h.v('x')), [h.ret(inThen)])], {'x': 'treeNode?'}),
        {'x': 'treeNode?'},
        'may_be_empty',
        blockId: inThen,
      );
    });

    test('4c. the ELSE of IS NOT NOTHING is not narrowed', () {
      final g = _G();
      final inElse = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [
        g.iff(g.isNot(g.v('x')), [g.ret(g.n(1))], orElse: [g.ret(inElse)]),
      ];
      _fails(g.graph(entry, {'x': 'treeNode?'}), {'x': 'treeNode?'}, 'may_be_empty', blockId: inElse);
    });

    // x: treeNode?; IF x IS NOT NOTHING { y = LEFT x; IF y IS NOT NOTHING {…} … } …
    ({BlockGraph graph, String inInner, String afterInnerX, String afterInnerY, String afterOuter}) nested() {
      final g = _G();
      final inInner = g.bin(BlockIds.arithAdd, g.of(BlockIds.treeValue, g.v('x')), g.of(BlockIds.treeValue, g.v('y')));
      final afterInnerX = g.v('x');
      final afterInnerY = g.v('y');
      final afterOuter = g.v('x');
      final entry = [
        g.set('r', g.n(0)),
        g.iff(g.isNot(g.v('x')), [
          g.set('y', g.of(BlockIds.treeLeft, g.v('x'))),
          g.iff(g.isNot(g.v('y')), [g.set('r', inInner)]),
          g.set('r', g.of(BlockIds.treeValue, afterInnerX)),
          g.set('y', afterInnerY),
        ]),
        g.set('x', afterOuter),
        g.ret(g.v('r')),
      ];
      return (
        graph: g.graph(entry, {'x': 'treeNode?', 'y': 'treeNode?', 'r': 'num'}),
        inInner: inInner,
        afterInnerX: afterInnerX,
        afterInnerY: afterInnerY,
        afterOuter: afterOuter,
      );
    }

    test('5. nested checks: each variable is narrowed exactly where it was checked', () {
      final s = nested();
      _ok(s.graph, {'x': 'treeNode?'});
      // What the editor sees at each place.
      final add = s.graph.blocks[s.inInner]!;
      final xInner = (add.slots['left']! as RefBinding).blockId;
      final yInner = (add.slots['right']! as RefBinding).blockId;
      final xRead = (s.graph.blocks[xInner]!.slots['node']! as RefBinding).blockId;
      final yRead = (s.graph.blocks[yInner]!.slots['node']! as RefBinding).blockId;
      expect(GraphTyping.resolveOutput(s.graph, xRead), ValueType.treeNode);
      expect(GraphTyping.resolveOutput(s.graph, yRead), ValueType.treeNode);
      expect(GraphTyping.resolveOutput(s.graph, s.afterInnerX), ValueType.treeNode);
      expect(GraphTyping.resolveOutput(s.graph, s.afterInnerY), ValueType.treeNode.asNullable);
      expect(GraphTyping.resolveOutput(s.graph, s.afterOuter), ValueType.treeNode.asNullable);
    });

    test('5b. after the inner IF, y may be empty again; after the outer IF, x may', () {
      final g = _G();
      final yAfter = g.of(BlockIds.treeValue, g.v('y'));
      final entry = [
        g.iff(g.isNot(g.v('x')), [
          g.set('y', g.of(BlockIds.treeLeft, g.v('x'))),
          g.iff(g.isNot(g.v('y')), [g.ret(g.of(BlockIds.treeValue, g.v('y')))]),
          g.ret(yAfter),
        ]),
        g.ret(g.n(0)),
      ];
      _fails(g.graph(entry, {'x': 'treeNode?', 'y': 'treeNode?'}), {'x': 'treeNode?'}, 'may_be_empty',
          blockId: yAfter);

      final h = _G();
      final xAfter = h.of(BlockIds.treeValue, h.v('x'));
      final entry2 = [
        h.iff(h.isNot(h.v('x')), [h.ret(h.of(BlockIds.treeValue, h.v('x')))]),
        h.ret(xAfter),
      ];
      _fails(h.graph(entry2, {'x': 'treeNode?'}), {'x': 'treeNode?'}, 'may_be_empty', blockId: xAfter);
    });

    test('6. two variables, two nested checks, both plain inside', () {
      final g = _G();
      final entry = [
        g.iff(g.isNot(g.v('a')), [
          g.iff(g.isNot(g.v('b')), [
            g.ret(g.bin(BlockIds.arithAdd, g.of(BlockIds.llValue, g.v('a')), g.of(BlockIds.llValue, g.v('b')))),
          ]),
          g.ret(g.of(BlockIds.llValue, g.v('a'))),
        ]),
        g.ret(g.n(0)),
      ];
      final program = _ok(g.graph(entry, {'a': 'listNode?', 'b': 'listNode?'}), {'a': 'listNode?', 'b': 'listNode?'});
      expect(_number(_run(program, {'a': _list([2]), 'b': _list([5])})), 7);
      expect(_number(_run(program, {'a': _list([2]), 'b': const NilValue()})), 2);
      expect(_number(_run(program, {'a': const NilValue(), 'b': _list([5])})), 0);

      // Checking a does nothing for b.
      final h = _G();
      final bRead = h.of(BlockIds.llValue, h.v('b'));
      _fails(
        h.graph([h.iff(h.isNot(h.v('a')), [h.ret(bRead)]), h.ret(h.n(0))], {'a': 'listNode?', 'b': 'listNode?'}),
        {'a': 'listNode?', 'b': 'listNode?'},
        'may_be_empty',
        blockId: bRead,
      );
    });

    test('AND: the right side and the branch see what the left side proved', () {
      final g = _G();
      final cond = g.bin(
        BlockIds.logicAnd,
        g.isNot(g.v('x')),
        g.bin(BlockIds.cmpGt, g.of(BlockIds.llValue, g.v('x')), g.n(0)),
      );
      final entry = [
        g.iff(cond, [g.ret(g.of(BlockIds.llValue, g.v('x')))]),
        g.ret(g.n(0)),
      ];
      final program = _ok(g.graph(entry, {'x': 'listNode?'}), {'x': 'listNode?'});
      expect(_number(_run(program, {'x': _list([4])})), 4);
      expect(_number(_run(program, {'x': _list([-4])})), 0);
      // AND stops at a false left side: the right side never reads NOTHING.
      expect(_number(_run(program, {'x': const NilValue()})), 0);
    });

    test('OR and NOT prove nothing', () {
      final g = _G();
      final orRead = g.of(BlockIds.llValue, g.v('x'));
      final orCond = g.bin(BlockIds.logicOr, g.isNot(g.v('x')), g.add(BlockIds.litBool, literals: {'value': true}));
      _fails(g.graph([g.iff(orCond, [g.ret(orRead)]), g.ret(g.n(0))], {'x': 'listNode?'}), {'x': 'listNode?'},
          'may_be_empty', blockId: orRead);

      final h = _G();
      final notRead = h.of(BlockIds.llValue, h.v('x'));
      final notCond = h.add(BlockIds.logicNot, slots: {'arg': {'ref': h.isNothing(h.v('x'))}});
      _fails(h.graph([h.iff(notCond, [h.ret(notRead)]), h.ret(h.n(0))], {'x': 'listNode?'}), {'x': 'listNode?'},
          'may_be_empty', blockId: notRead);
    });

    test('EQUAL NOTHING compares but does not narrow', () {
      final g = _G();
      final read = g.of(BlockIds.llValue, g.v('x'));
      final cond = g.bin(BlockIds.cmpNe, g.v('x'), g.add(BlockIds.litNull));
      _fails(g.graph([g.iff(cond, [g.ret(read)]), g.ret(g.n(0))], {'x': 'listNode?'}), {'x': 'listNode?'},
          'may_be_empty', blockId: read);
    });

    test('only a plain variable is narrowed: a checked LEFT x is not remembered', () {
      final g = _G();
      final again = g.of(BlockIds.treeValue, g.of(BlockIds.treeLeft, g.v('root')));
      final entry = [
        g.iff(g.isNot(g.of(BlockIds.treeLeft, g.v('root'))), [g.ret(again)]),
        g.ret(g.n(0)),
      ];
      _fails(g.graph(entry, {'root': 'treeNode'}), {'root': 'treeNode'}, 'may_be_empty', blockId: again);
    });
  });

  group('what IS NOTHING accepts', () {
    test('7. a plain number, a condition or NOTHING itself cannot be checked', () {
      for (final (label, make, message) in [
        ('number', (_G g) => g.v('count'), 'This value is never empty here, so there is nothing to check.'),
        ('condition', (_G g) => g.add(BlockIds.litBool, literals: {'value': true}),
            'This value is never empty here, so there is nothing to check.'),
        ('NOTHING', (_G g) => g.add(BlockIds.litNull), 'Check a value that may be empty, not NOTHING itself.'),
        ('plain node', (_G g) => g.v('root'), 'This value is never empty here, so there is nothing to check.'),
      ]) {
        final g = _G();
        final check = g.isNothing(make(g));
        final entry = [g.iff(check, [g.ret(g.n(1))]), g.ret(g.n(0))];
        final graph = g.graph(entry, {'count': 'num', 'root': 'treeNode'});
        final result = _lower(graph, {'count': 'num', 'root': 'treeNode'});
        expect(result.ok, isFalse, reason: label);
        expect(result.errors.first.code, 'type_mismatch', reason: label);
        expect(result.errors.first.message, message, reason: label);
        expect(result.errors.first.blockId, check, reason: label);
      }
    });

    test('7b. the editor refuses them too, and a variable already checked', () {
      final g = _G();
      final outer = g.isNot(g.v('x'));
      final inner = g.add(BlockIds.logicIsNothing);
      final entry = [g.iff(outer, [g.iff(inner, [g.ret(g.n(1))])]), g.ret(g.n(0))];
      final graph = g.graph(entry, {'x': 'listNode?', 'count': 'num'});
      final names = GraphTyping.compatiblePlacements(
        graph,
        to: PortRef(inner, 'value'),
        allow: const [BlockIds.varGet, BlockIds.litNull, BlockIds.litNum, BlockIds.llNext],
      ).map((p) => p.literals['name'] ?? p.catalogId).toList();
      // x is already known to hold a node here; NEXT NODE of it may be empty.
      expect(names, [BlockIds.llNext]);
    });

    test('a map lookup can be checked', () {
      final g = _G();
      final lookup = g.add(BlockIds.mapGet, slots: {'map': {'ref': g.v('counts')}, 'key': {'ref': g.v('key')}});
      final entry = [g.iff(g.isNothing(lookup), [g.ret(g.n(0))]), g.ret(g.n(1))];
      _ok(g.graph(entry, {'counts': 'map<str,num>', 'key': 'str'}), {'counts': 'map<str,num>', 'key': 'str'});
    });
  });

  group('malformed programs are refused', () {
    test('8. an empty check, a check used as an instruction, a missing piece', () {
      final g = _G();
      final empty = g.add(BlockIds.logicIsNotNothing);
      _fails(g.graph([g.iff(empty, [g.ret(g.n(1))])], {'x': 'listNode?'}), {'x': 'listNode?'}, 'missing_expr',
          blockId: empty);

      final h = _G();
      final loose = h.isNot(h.v('x'));
      _fails(h.graph([loose], {'x': 'listNode?'}), {'x': 'listNode?'}, 'wrong_kind');

      final k = _G();
      final check = k.add(BlockIds.logicIsNotNothing, slots: {'value': {'ref': 'ghost_block'}});
      final result = _lower(k.graph([k.iff(check, [k.ret(k.n(1))])], {'x': 'listNode?'}), {'x': 'listNode?'});
      expect(result.ok, isFalse);
    });

    test('9. checking a variable that does not exist is refused', () {
      final g = _G();
      final ghost = g.v('ghost');
      _fails(g.graph([g.iff(g.isNot(ghost), [g.ret(g.n(1))]), g.ret(g.n(0))], {}), {}, 'undefined_variable',
          blockId: ghost);
    });
  });

  group('no narrowing outlives what it proved', () {
    test('10. writing the variable ends its narrowing', () {
      final g = _G();
      final stale = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [
        g.iff(g.isNot(g.v('x')), [
          g.set('x', g.of(BlockIds.treeLeft, g.v('x'))),
          g.ret(stale),
        ]),
        g.ret(g.n(0)),
      ];
      _fails(g.graph(entry, {'x': 'treeNode?'}), {'x': 'treeNode?'}, 'may_be_empty', blockId: stale);
    });

    test('10b. a loop that writes the variable cannot rely on an outer check', () {
      // IF x IS NOT NOTHING { WHILE … { r = VALUE x; x = LEFT x } }: the second
      // iteration would read an unchecked x.
      final g = _G();
      final second = g.of(BlockIds.treeValue, g.v('x'));
      final entry = [
        g.set('r', g.n(0)),
        g.iff(g.isNot(g.v('x')), [
          g.loop(g.bin(BlockIds.cmpLt, g.v('r'), g.n(3)), [
            g.set('r', second),
            g.set('x', g.of(BlockIds.treeLeft, g.v('x'))),
          ]),
        ]),
        g.ret(g.v('r')),
      ];
      _fails(g.graph(entry, {'x': 'treeNode?', 'r': 'num'}), {'x': 'treeNode?'}, 'may_be_empty', blockId: second);
    });

    test('10c. a loop that leaves the variable alone keeps the outer check', () {
      final g = _G();
      final entry = [
        g.set('r', g.n(0)),
        g.iff(g.isNot(g.v('x')), [
          g.loop(g.bin(BlockIds.cmpLt, g.v('r'), g.n(10)), [
            g.set('r', g.bin(BlockIds.arithAdd, g.v('r'), g.of(BlockIds.treeValue, g.v('x')))),
          ]),
        ]),
        g.ret(g.v('r')),
      ];
      final program = _ok(g.graph(entry, {'x': 'treeNode?', 'r': 'num'}), {'x': 'treeNode?'});
      expect(_number(_run(program, {'x': TreeNodeValue(4)})), 12);
      expect(_number(_run(program, {'x': const NilValue()})), 0);
    });

    test('10d. WHILE: plain in the body until reassigned, and after the loop may be empty', () {
      final g = _G();
      final afterStep = g.of(BlockIds.llValue, g.v('node'));
      final entry = [
        g.set('node', g.v('head')),
        g.loop(g.isNot(g.v('node')), [
          g.set('node', g.of(BlockIds.llNext, g.v('node'))),
          g.set('total', afterStep),
        ]),
        g.ret(g.n(0)),
      ];
      _fails(g.graph(entry, {'head': 'listNode?', 'node': 'listNode?', 'total': 'num'}), {'head': 'listNode?'},
          'may_be_empty', blockId: afterStep);

      final h = _G();
      final afterLoop = h.of(BlockIds.llValue, h.v('node'));
      final entry2 = [
        h.set('node', h.v('head')),
        h.loop(h.isNot(h.v('node')), [h.set('node', h.of(BlockIds.llNext, h.v('node')))]),
        h.ret(afterLoop),
      ];
      _fails(h.graph(entry2, {'head': 'listNode?', 'node': 'listNode?'}), {'head': 'listNode?'}, 'may_be_empty',
          blockId: afterLoop);
    });

    test('10f. COPY and SWAP follow the same rules as SET', () {
      const vars = {'maybe': 'listNode?', 'sure': 'listNode'};
      const inputs = {'maybe': 'listNode?', 'sure': 'listNode'};
      const copy = {'name': 'sure', 'from': 'maybe'};

      final g = _G();
      final unchecked = g.add(BlockIds.varCopy, literals: copy);
      _fails(g.graph([unchecked, g.ret(g.n(0))], vars), inputs, 'may_be_empty', message: _mayBeEmpty,
          blockId: unchecked);

      final h = _G();
      _ok(h.graph([h.iff(h.isNot(h.v('maybe')), [h.add(BlockIds.varCopy, literals: copy)]), h.ret(h.n(0))], vars),
          inputs);

      final k = _G();
      final swap = k.add(BlockIds.varSwap, literals: {'name': 'sure', 'other': 'maybe'});
      _fails(k.graph([swap, k.ret(k.n(0))], vars), inputs, 'may_be_empty', blockId: swap);

      // COPY writes its destination, which ends the destination's narrowing.
      final m = _G();
      final stale = m.of(BlockIds.llValue, m.v('maybe'));
      final entry = [
        m.iff(m.isNot(m.v('maybe')), [
          m.add(BlockIds.varCopy, literals: {'name': 'maybe', 'from': 'other'}),
          m.ret(stale),
        ]),
        m.ret(m.n(0)),
      ];
      _fails(m.graph(entry, {'maybe': 'listNode?', 'other': 'listNode?'}), {'maybe': 'listNode?', 'other': 'listNode?'},
          'may_be_empty', blockId: stale);
    });

    test('10e. a FOR counter or a FOR body that writes the variable ends the narrowing', () {
      final g = _G();
      final inside = g.of(BlockIds.llValue, g.v('x'));
      final entry = [
        g.iff(g.isNot(g.v('x')), [
          g.add(BlockIds.ctrlForRange, literals: {'name': 'i'}, slots: {
            'start': {'ref': g.n(0)},
            'end': {'ref': g.n(2)},
            'body': {
              'list': [
                g.set('r', inside),
                g.set('x', g.of(BlockIds.llNext, g.v('x'))),
              ],
            },
          }),
        ]),
        g.ret(g.n(0)),
      ];
      _fails(g.graph(entry, {'x': 'listNode?', 'r': 'num', 'i': 'num'}), {'x': 'listNode?'}, 'may_be_empty',
          blockId: inside);
    });
  });

  group('runtime', () {
    Program check(UnaryOp op) => Program(functions: [
          FnDecl(
            name: 'main',
            params: [Param('x', ValueType.listNode.asNullable)],
            body: [
              ReturnStmt(
                value: UnaryExpr(
                  op,
                  VarExpr('x', type: ValueType.listNode.asNullable, srcBlockId: 'get'),
                  type: ValueType.boolean,
                  srcBlockId: 'check',
                ),
                srcBlockId: 'ret',
              ),
            ],
          ),
        ]);

    bool answer(RunResult r) {
      expect(r.kind, ResultKind.correct, reason: r.message);
      return (r.output as BoolValue).value;
    }

    test('11. IS NOTHING on NOTHING is true', () {
      expect(answer(_run(check(UnaryOp.isNothing), {'x': const NilValue()})), isTrue);
    });

    test('12. IS NOTHING on a node is false', () {
      expect(answer(_run(check(UnaryOp.isNothing), {'x': _list([1])})), isFalse);
    });

    test('13. IS NOT NOTHING on NOTHING is false', () {
      expect(answer(_run(check(UnaryOp.isNotNothing), {'x': const NilValue()})), isFalse);
    });

    test('14. IS NOT NOTHING on a node is true', () {
      expect(answer(_run(check(UnaryOp.isNotNothing), {'x': _list([1])})), isTrue);
    });

    test('checks work on any value, never raise, and a number is not NOTHING', () {
      final program = Program(functions: [
        FnDecl(name: 'main', params: [Param('x', ValueType.number.asNullable)], body: [
          ReturnStmt(
            value: UnaryExpr(UnaryOp.isNothing, VarExpr('x', type: ValueType.number.asNullable),
                type: ValueType.boolean),
          ),
        ]),
      ]);
      expect(answer(_run(program, {'x': const NumValue(0)})), isFalse);
      expect(answer(_run(program, {'x': const NilValue()})), isTrue);
    });

    test('15. a check costs one operation, the same for NOTHING and a node, every run', () {
      final counts = <int>{};
      for (final op in [UnaryOp.isNothing, UnaryOp.isNotNothing]) {
        for (final x in <RuntimeValue>[const NilValue(), _list([1, 2])]) {
          for (var i = 0; i < 3; i++) {
            counts.add(_run(check(op), {'x': x}).metrics.ops);
          }
        }
      }
      // RETURN + check + GET.
      expect(counts, {3});
    });

    test('the lowered program is exactly the IR form and survives JSON', () {
      final g = _G();
      final entry = [
        g.iff(g.isNot(g.v('x')), [g.ret(g.of(BlockIds.llValue, g.v('x')))]),
        g.ret(g.n(-1)),
      ];
      final program = _ok(g.graph(entry, {'x': 'listNode?'}), {'x': 'listNode?'});
      final json = program.toJson();
      final cond = (program.functions.single.body.first as IfStmt).cond as UnaryExpr;
      expect(cond.op, UnaryOp.isNotNothing);
      expect(cond.toJson()['op'], 'isNotNothing');
      final back = Program.fromJson(json);
      expect(back.toJson(), json);
      for (final x in <RuntimeValue>[const NilValue(), _list([9])]) {
        final a = _run(program, {'x': x});
        final b = _run(back, {'x': x});
        expect((b.output as NumValue).value, (a.output as NumValue).value);
        expect(b.metrics.ops, a.metrics.ops);
      }
    });
  });

  group('data structures', () {
    test('16. tree: check LEFT and RIGHT, then read them', () {
      final g = _G();
      final entry = [
        g.set('sum', g.of(BlockIds.treeValue, g.v('root'))),
        g.set('l', g.of(BlockIds.treeLeft, g.v('root'))),
        g.set('r', g.of(BlockIds.treeRight, g.v('root'))),
        g.iff(g.isNot(g.v('l')), [
          g.set('sum', g.bin(BlockIds.arithAdd, g.v('sum'), g.of(BlockIds.treeValue, g.v('l')))),
        ]),
        g.iff(g.isNot(g.v('r')), [
          g.set('sum', g.bin(BlockIds.arithAdd, g.v('sum'), g.of(BlockIds.treeValue, g.v('r')))),
        ]),
        g.ret(g.v('sum')),
      ];
      final program = _ok(
        g.graph(entry, {'root': 'treeNode', 'sum': 'num', 'l': 'treeNode?', 'r': 'treeNode?'}),
        {'root': 'treeNode'},
      );
      expect(_number(_run(program, {'root': TreeNodeValue(1, left: TreeNodeValue(2), right: TreeNodeValue(3))})), 6);
      expect(_number(_run(program, {'root': TreeNodeValue(1, left: TreeNodeValue(2))})), 3);
      expect(_number(_run(program, {'root': TreeNodeValue(1, right: TreeNodeValue(3))})), 4);
      expect(_number(_run(program, {'root': TreeNodeValue(1)})), 1);
    });

    test('17. linked list: check NEXT NODE, then read it', () {
      final g = _G();
      final entry = [
        g.set('n', g.of(BlockIds.llNext, g.v('head'))),
        g.iff(g.isNot(g.v('n')), [g.ret(g.of(BlockIds.llValue, g.v('n')))]),
        g.ret(g.n(-1)),
      ];
      final program = _ok(g.graph(entry, {'head': 'listNode', 'n': 'listNode?'}), {'head': 'listNode'});
      expect(_number(_run(program, {'head': _list([4, 7])})), 7);
      expect(_number(_run(program, {'head': _list([4])})), -1);
    });

    test('17b. linked list: SET NEXT through a checked link unlinks the node after it', () {
      final g = _G();
      final entry = [
        g.set('n', g.of(BlockIds.llNext, g.v('head'))),
        g.iff(g.isNot(g.v('n')), [
          g.add(BlockIds.llSetNext, slots: {
            'node': {'ref': g.v('head')},
            'next': {'ref': g.of(BlockIds.llNext, g.v('n'))},
          }),
        ]),
        g.set('n', g.of(BlockIds.llNext, g.v('head'))),
        g.iff(g.isNot(g.v('n')), [g.ret(g.of(BlockIds.llValue, g.v('n')))]),
        g.ret(g.n(-1)),
      ];
      final program = _ok(g.graph(entry, {'head': 'listNode', 'n': 'listNode?'}), {'head': 'listNode'});
      expect(_number(_run(program, {'head': _list([1, 2, 3])})), 3);
      expect(_number(_run(program, {'head': _list([1, 2])})), -1);
      expect(_number(_run(program, {'head': _list([1])})), -1);
    });

    test('16b. tree: breadth-first with a queue of nodes, children checked before they queue', () {
      final g = _G();
      String enqueue(String value) =>
          g.add(BlockIds.queueEnq, slots: {'queue': {'ref': g.v('q')}, 'value': {'ref': value}});
      final entry = [
        g.set('q', g.add(BlockIds.newQueue)),
        enqueue(g.v('root')),
        g.set('total', g.n(0)),
        g.loop(g.add(BlockIds.logicNot, slots: {'arg': {'ref': g.add(BlockIds.queueEmpty, slots: {'queue': {'ref': g.v('q')}})}}), [
          g.set('node', g.add(BlockIds.queueDeq, slots: {'queue': {'ref': g.v('q')}})),
          g.set('total', g.bin(BlockIds.arithAdd, g.v('total'), g.of(BlockIds.treeValue, g.v('node')))),
          g.set('child', g.of(BlockIds.treeLeft, g.v('node'))),
          g.iff(g.isNot(g.v('child')), [enqueue(g.v('child'))]),
          g.set('child', g.of(BlockIds.treeRight, g.v('node'))),
          g.iff(g.isNot(g.v('child')), [enqueue(g.v('child'))]),
        ]),
        g.ret(g.v('total')),
      ];
      final program = _ok(
        g.graph(entry, {
          'root': 'treeNode',
          'q': 'queue<treeNode>',
          'node': 'treeNode',
          'child': 'treeNode?',
          'total': 'num',
        }),
        {'root': 'treeNode'},
      );
      final tree = TreeNodeValue(1,
          left: TreeNodeValue(2, left: TreeNodeValue(4)), right: TreeNodeValue(3, right: TreeNodeValue(5)));
      expect(_number(_run(program, {'root': tree})), 15);
      expect(_number(_run(program, {'root': TreeNodeValue(7)})), 7);

      // Queueing LEFT node without the check is refused.
      final h = _G();
      final raw = h.of(BlockIds.treeLeft, h.v('root'));
      final unchecked = [
        h.set('q', h.add(BlockIds.newQueue)),
        h.add(BlockIds.queueEnq, slots: {'queue': {'ref': h.v('q')}, 'value': {'ref': raw}}),
        h.ret(h.n(0)),
      ];
      _fails(h.graph(unchecked, {'root': 'treeNode', 'q': 'queue<treeNode>'}), {'root': 'treeNode'}, 'may_be_empty',
          message: _mayBeEmpty);
    });

    test('18. map: a lookup is checked before it is counted', () {
      final g = _G();
      final lookup = g.add(BlockIds.mapGet, slots: {'map': {'ref': g.v('counts')}, 'key': {'ref': g.v('key')}});
      final entry = [
        g.set('c', lookup),
        g.iff(g.isNot(g.v('c')), [g.ret(g.bin(BlockIds.arithAdd, g.v('c'), g.n(1)))]),
        g.ret(g.n(0)),
      ];
      final inputs = {'counts': 'map<str,num>', 'key': 'str'};
      final program = _ok(g.graph(entry, {...inputs, 'c': 'num?'}), inputs);
      final counts = valueFromJson({
        'type': 'map',
        'entries': [
          ['a', 2],
        ],
      }, type: ValueType.mapOf(ValueType.string, ValueType.number));
      expect(_number(_run(program, {'counts': counts, 'key': const StrValue('a')})), 3);
      expect(_number(_run(program, {'counts': counts, 'key': const StrValue('z')})), 0);

      // Adding to the lookup without the check is refused.
      final h = _G();
      final raw = h.add(BlockIds.mapGet, slots: {'map': {'ref': h.v('counts')}, 'key': {'ref': h.v('key')}});
      _fails(h.graph([h.ret(h.bin(BlockIds.arithAdd, raw, h.n(1)))], inputs), inputs, 'may_be_empty',
          message: _mayBeEmpty);
    });

    test('19. linked list: WHILE node IS NOT NOTHING walks every node', () {
      final g = _G();
      final entry = [
        g.set('count', g.n(0)),
        g.set('total', g.n(0)),
        g.set('node', g.v('head')),
        g.loop(g.isNot(g.v('node')), [
          g.set('count', g.bin(BlockIds.arithAdd, g.v('count'), g.n(1))),
          g.set('total', g.bin(BlockIds.arithAdd, g.v('total'), g.of(BlockIds.llValue, g.v('node')))),
          g.set('node', g.of(BlockIds.llNext, g.v('node'))),
        ]),
        g.ret(g.bin(BlockIds.arithMul, g.v('count'), g.v('total'))),
      ];
      final program = _ok(
        g.graph(entry, {'head': 'listNode?', 'node': 'listNode?', 'count': 'num', 'total': 'num'}),
        {'head': 'listNode?'},
      );
      expect(_number(_run(program, {'head': _list([1, 2, 3])})), 3 * 6);
      expect(_number(_run(program, {'head': const NilValue()})), 0);
      final ops = {for (var i = 0; i < 3; i++) _run(program, {'head': _list([1, 2, 3])}).metrics.ops};
      expect(ops, hasLength(1));
    });
  });

  group('editor', () {
    test('the picker offers the checks for a condition, and GET x inside the checked branch only', () {
      final g = _G();
      final inside = g.add(BlockIds.llValue);
      final outside = g.add(BlockIds.llValue);
      final cond = g.add(BlockIds.ctrlIf);
      final entry = [
        g.iff(g.isNot(g.v('x')), [g.set('r', inside)]),
        g.set('r', outside),
        cond,
      ];
      final graph = g.graph(entry, {'x': 'listNode?', 'r': 'num'});
      const allow = [
        BlockIds.varGet,
        BlockIds.logicIsNothing,
        BlockIds.logicIsNotNothing,
        BlockIds.llNext,
        BlockIds.litBool,
      ];
      List<Object?> offered(PortRef hole) => GraphTyping.compatiblePlacements(graph, to: hole, allow: allow)
          .map((p) => p.literals['name'] ?? p.catalogId)
          .toList();

      expect(offered(PortRef(cond, 'condition')),
          containsAll([BlockIds.logicIsNothing, BlockIds.logicIsNotNothing, BlockIds.litBool]));
      expect(offered(PortRef(inside, 'node')), ['x']);
      expect(offered(PortRef(outside, 'node')), isEmpty);
    });

    test('dropping GET x into a node hole outside the check explains why', () {
      final g = _G();
      final value = g.add(BlockIds.llValue);
      final x = g.v('x');
      final graph = g.graph([g.set('r', value)], {'x': 'listNode?', 'r': 'num'});
      final d = GraphTyping.canConnect(graph, from: PortRef(x, 'out'), to: PortRef(value, 'node'));
      expect(d.code, 'may_be_empty');
      expect(d.message, _mayBeEmpty);
    });

    test('the new blocks read as English and serialize deterministically', () {
      expect(BlockChrome.labelOf(BlockIds.logicIsNothing), 'IS NOTHING');
      expect(BlockChrome.labelOf(BlockIds.logicIsNotNothing), 'IS NOT NOTHING');
      expect(BlockChrome.of(BlockIds.logicIsNotNothing).layout, BlockLayout.verbObject);
      for (final id in [BlockIds.logicIsNothing, BlockIds.logicIsNotNothing]) {
        final label = BlockChrome.labelOf(id);
        for (final word in ['null', 'option', 'nullable', 'cast', '?', '!']) {
          expect(label.toLowerCase(), isNot(contains(word)));
        }
      }
      final g = _G();
      final graph = g.graph([
        g.iff(g.isNothing(g.v('x')), [g.ret(g.n(0))], orElse: [g.ret(g.of(BlockIds.llValue, g.v('x')))]),
      ], {'x': 'listNode?'});
      final json = graph.toJson();
      expect(BlockGraph.fromJson(json).toJson(), json);
      expect(BlockGraph.fromJson(json).variables['x'], ValueType.listNode.asNullable);
    });
  });
}
