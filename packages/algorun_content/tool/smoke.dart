import 'package:algorun_engine/algorun_engine.dart';

import 'prog.dart';

void main() {
  final p = Prog(inputs: const {'values': 'array<num>'}, pool: const {'i': 'num', 'count': 'num'});
  p.set('count', p.lit(0));
  p.range('i', p.lit(1), p.len(p.get('values')), () {
    p.iff(p.lt(p.at(p.get('values'), p.get('i')), p.at(p.get('values'), p.sub(p.get('i'), p.lit(1)))), () {
      p.ret(p.get('i'));
    });
  });
  p.ret(p.lit(-1));
  final puzzle = parsePuzzleJson('''
{
  "id": "first_descent",
  "version": 1,
  "title": "First Descent",
  "world": "world_02",
  "chapter": "first_strict_descent",
  "tier": 2,
  "mode": "edge",
  "concepts": ["arrays"],
  "prerequisites": ["variables"],
  "story": "A path of stones.",
  "io": {"inputs": [{"name": "values", "type": "array<num>"}], "output": {"type": "num"}},
  "blocks": {"allow": ["arith.sub", "arr.get", "arr.len", "cmp.lt", "ctrl.for_range", "ctrl.if", "ctrl.return", "lit.num", "var.get", "var.set"], "maxBlocks": 40},
  "limits": {"maxOps": 10000, "maxDepth": 32, "maxAlloc": 100},
  "hints": ["a", "b", "c"],
  "validators": {"output": "equal"},
  "fixtures": {"visible": [{"id": "v1", "in": {"values": [1, 3, 2]}, "out": 2}], "hidden": [{"id": "h1", "in": {"values": [1, 2, 3]}, "out": -1}, {"id": "h2", "in": {"values": []}, "out": -1}, {"id": "h3", "in": {"values": [4, 4]}, "out": -1}, {"id": "h4", "in": {"values": [2, 1]}, "out": 1}]},
  "variables": {"pool": [{"name": "i", "type": "num"}, {"name": "count", "type": "num"}]},
  "reference": {"strategy": "first_strict_descent"}
}
''');
  final engine = DefaultEngine();
  final report = engine.validate(p.graph, puzzle);
  if (!report.ok) {
    for (final m in report.messages) {
      print('VALIDATE ${m.code} ${m.message}');
    }
  }
  final lowered = engine.lower(p.graph, puzzle);
  if (!lowered.ok) {
    for (final m in lowered.errors) {
      print('LOWER ${m.code} ${m.message}');
    }
    return;
  }
  final suite = engine.runTests(lowered.program!, puzzle);
  print('kind ${suite.kind.name} ops ${suite.metrics.ops} alloc ${suite.metrics.peakAlloc} blocks ${suite.metrics.blocks}');
  print(suite.ok);
}
