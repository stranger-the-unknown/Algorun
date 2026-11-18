// algorun-lang only (not in the game): A3 blocks and deviations D5–D9.
// Every test builds a BlockGraph the way the editor stores it, lowers it with
// the real Lowerer (static typing) and runs it, so typing and VM are covered.
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

final class _G {
  final blocks = <String, Map<String, Object?>>{};
  var _n = 0;
  String add(String id, {Map<String, Object?> literals = const {}, Map<String, Object?> slots = const {}}) {
    final b = 'b${++_n}';
    blocks[b] = {'id': b, 'catalogId': id, 'literals': literals, 'slots': slots};
    return b;
  }

  String v(String name) => add(BlockIds.varGet, literals: {'name': name});
  String n(int value) => add(BlockIds.litNum, literals: {'value': value});
  String s(String value) => add(BlockIds.litStr, literals: {'value': value});
  String set(String name, String value) =>
      add(BlockIds.varSet, literals: {'name': name}, slots: {'value': {'ref': value}});
  String ret(String value) => add(BlockIds.ctrlReturn, slots: {'value': {'ref': value}});
  String op(String id, Map<String, String> ports) =>
      add(id, slots: {for (final e in ports.entries) e.key: {'ref': e.value}});
  BlockGraph graph(List<String> entry, Map<String, String> vars) =>
      BlockGraph.fromJson({'variables': vars, 'entryIds': entry, 'blocks': blocks});
}

Puzzle _puzzle(String output) => parsePuzzleJson('''
{ "id": "a3", "title": "A3", "world": "world_01", "tier": 1, "mode": "build", "story": "s",
  "io": { "inputs": [{ "name": "x", "type": "num" }], "output": { "type": "$output" } },
  "blocks": { "allow": ["var.get"] }, "limits": { "maxOps": 100000 },
  "fixtures": { "visible": [{ "id": "v", "in": { "x": 1 }, "out": ${_sample(output)} }],
                "hidden": [{ "id": "h", "in": { "x": 1 }, "out": ${_sample(output)} }] } }''');

String _sample(String type) => switch (type) { 'str' => '"a"', 'bool' => 'true', _ => '1' };

RunResult _run(BlockGraph g, {String output = 'num'}) {
  final lowered = lower(g, _puzzle(output));
  expect(lowered.ok, isTrue, reason: '${lowered.errors.map((e) => '${e.code} ${e.message} @${e.blockId}')}');
  // Through JSON, like the conformance suite.
  final program = Program.fromJsonString(lowered.program!.toJsonString());
  return const DefaultEngine().run(program, {'x': const NumValue(1)}, RunLimits.standard);
}

Object? _out(RunResult r) {
  expect(r.kind, ResultKind.correct, reason: r.message);
  return valueToJson(r.output!);
}

void main() {
  group('D5 COPY is a real copy', () {
    test('appending to the copy leaves the original alone', () {
      final g = _G();
      final entry = [
        g.set('a', g.add(BlockIds.newArray, literals: {'of': 'num'})),
        g.op(BlockIds.arrAppend, {'array': g.v('a'), 'value': g.n(1)}),
        g.add(BlockIds.varCopy, literals: {'name': 'b', 'from': 'a'}),
        g.op(BlockIds.arrAppend, {'array': g.v('b'), 'value': g.n(2)}),
        g.ret(g.op(BlockIds.arrLen, {'array': g.v('a')})),
      ];
      expect(_out(_run(g.graph(entry, {'a': 'array<num>', 'b': 'array<num>'}))), 1);
    });
  });

  group('D6 text', () {
    test('length, letter at, join, part, compare, number <-> text', () {
      final g = _G();
      final word = g.op(BlockIds.strConcat, {'left': g.s('hé'), 'right': g.s('llo')});
      final entry = [
        g.set('w', word),
        g.set('part', g.op(BlockIds.strSubstring, {'text': g.v('w'), 'start': g.n(1), 'end': g.n(3)})),
        g.set('c', g.op(BlockIds.strCharAt, {'text': g.v('w'), 'index': g.n(1)})),
        g.set('len', g.op(BlockIds.strLen, {'text': g.v('w')})),
        g.set('cmp', g.op(BlockIds.strCompare, {'left': g.v('part'), 'right': g.v('c')})),
        g.ret(g.op(BlockIds.strConcat, {
          'left': g.op(BlockIds.strFromNum, {'value': g.v('len')}),
          'right': g.op(BlockIds.strConcat, {'left': g.v('part'), 'right': g.op(BlockIds.strFromNum, {'value': g.v('cmp')})}),
        })),
      ];
      expect(_out(_run(g.graph(entry, {'w': 'str', 'part': 'str', 'c': 'str', 'len': 'num', 'cmp': 'num'}), output: 'str')), '5él1');
    });
    test('TEXT AS NUMBER gives a number or NOTHING, and its result may be empty', () {
      final g = _G();
      final parsed = g.op(BlockIds.strToNum, {'text': g.s('-42')});
      final entry = [
        g.set('p', parsed),
        g.ret(g.v('p')),
      ];
      final lowered = lower(g.graph(entry, {'p': 'num'}), _puzzle('num'));
      expect(lowered.ok, isFalse, reason: 'num? must not fit a num variable');
      final g2 = _G();
      final e2 = [
        g2.set('p', g2.op(BlockIds.strToNum, {'text': g2.s('12x')})),
        g2.ret(g2.op(BlockIds.logicIsNothing, {'value': g2.v('p')})),
      ];
      final r = _run(g2.graph(e2, {'p': 'num?'}), output: 'bool');
      expect(r.kind, ResultKind.correct);
      expect((r.output as BoolValue).value, isTrue);
    });
    test('a number does not fit a text hole', () {
      final g = _G();
      final entry = [g.ret(g.op(BlockIds.strLen, {'text': g.n(3)}))];
      expect(lower(g.graph(entry, {}), _puzzle('num')).ok, isFalse);
    });
  });

  group('D7 deque', () {
    test('push front/back, pop front/back, front, back, size', () {
      final g = _G();
      String d() => g.v('d');
      final entry = [
        g.set('d', g.add(BlockIds.newDeque, literals: {'of': 'num'})),
        g.op(BlockIds.dequePushBack, {'deque': d(), 'value': g.n(2)}),
        g.op(BlockIds.dequePushFront, {'deque': d(), 'value': g.n(1)}),
        g.op(BlockIds.dequePushBack, {'deque': d(), 'value': g.n(3)}),
        g.set('a', g.op(BlockIds.dequePopFront, {'deque': d()})),
        g.set('b', g.op(BlockIds.dequePopBack, {'deque': d()})),
        g.ret(g.op(BlockIds.arithAdd, {
          'left': g.op(BlockIds.arithMul, {'left': g.v('a'), 'right': g.n(100)}),
          'right': g.op(BlockIds.arithAdd, {
            'left': g.op(BlockIds.arithMul, {'left': g.v('b'), 'right': g.n(10)}),
            'right': g.op(BlockIds.dequeSize, {'deque': d()}),
          }),
        })),
      ];
      expect(_out(_run(g.graph(entry, {'d': 'deque<num>', 'a': 'num', 'b': 'num'}))), 131);
    });
  });

  group('D8 SORT', () {
    test('sorts numbers ascending in place', () {
      final g = _G();
      final entry = [
        g.set('a', g.add(BlockIds.newArray, literals: {'of': 'num'})),
        for (final v in [3, -1, 2]) g.op(BlockIds.arrAppend, {'array': g.v('a'), 'value': g.n(v)}),
        g.op(BlockIds.arrSort, {'array': g.v('a')}),
        g.ret(g.op(BlockIds.arrGet, {'array': g.v('a'), 'index': g.n(0)})),
      ];
      expect(_out(_run(g.graph(entry, {'a': 'array<num>'}))), -1);
    });
  });

  group('D9 pairs', () {
    test('MAKE PAIR keeps both types; FIRST and SECOND read them', () {
      final g = _G();
      final entry = [
        g.set('p', g.op(BlockIds.pairMake, {'first': g.n(7), 'second': g.s('seven')})),
        g.ret(g.op(BlockIds.strConcat, {
          'left': g.op(BlockIds.pairSecond, {'pair': g.v('p')}),
          'right': g.op(BlockIds.strFromNum, {'value': g.op(BlockIds.pairFirst, {'pair': g.v('p')})}),
        })),
      ];
      expect(_out(_run(g.graph(entry, {'p': 'pair<num,str>'}), output: 'str')), 'seven7');
    });
    test('SECOND of a pair<num,str> does not fit a number hole', () {
      final g = _G();
      final entry = [
        g.set('p', g.op(BlockIds.pairMake, {'first': g.n(7), 'second': g.s('seven')})),
        g.ret(g.op(BlockIds.arithAdd, {'left': g.op(BlockIds.pairSecond, {'pair': g.v('p')}), 'right': g.n(1)})),
      ];
      expect(lower(g.graph(entry, {'p': 'pair<num,str>'}), _puzzle('num')).ok, isFalse);
    });
  });

  test('every new block has a label and a definition', () {
    for (final id in [
      BlockIds.strLen, BlockIds.strCharAt, BlockIds.strConcat, BlockIds.strSubstring,
      BlockIds.strCompare, BlockIds.strFromNum, BlockIds.strToNum, BlockIds.newDeque,
      BlockIds.dequePushFront, BlockIds.dequePushBack, BlockIds.dequePopFront,
      BlockIds.dequePopBack, BlockIds.dequeFront, BlockIds.dequeBack, BlockIds.dequeSize,
      BlockIds.dequeEmpty, BlockIds.arrSort, BlockIds.pairMake, BlockIds.pairFirst, BlockIds.pairSecond,
    ]) {
      expect(BlockCatalog.of(id), isNotNull, reason: id);
      expect(BlockIds.exists(id), isTrue, reason: id);
    }
  });
}
