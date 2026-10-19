import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// Same-level `ctrl.if` blocks must lower to sibling [IfStmt] nodes.
/// A block attached to the first IF's THEN is a different graph.
void main() {
  const lowerer = Lowerer();

  test('two sibling IFs stay two sibling IfStmts, in order', () {
    final graph = _siblings(const ['if1', 'if2']);
    final body = _body(lowerer, graph);
    expect(body.map((s) => (s as IfStmt).srcBlockId), ['if1', 'if2']);
    expect(_thenIds(body[0] as IfStmt), ['set1']);
    expect(_thenIds(body[1] as IfStmt), ['set2']);
    expect((body[0] as IfStmt).thenBody.whereType<IfStmt>(), isEmpty);
    expect(graph.entryIds, ['if1', 'if2']);
    expect(graph.slotList('if1', 'then'), ['set1']);
    expect(graph.parentOf('if2')?.blockId, BlockGraph.mainId);
  });

  test('three sibling IFs stay three sibling IfStmts, in order', () {
    final graph = _siblings(const ['if1', 'if2', 'if3']);
    final body = _body(lowerer, graph);
    expect(body, hasLength(3));
    expect(body.map((s) => (s as IfStmt).srcBlockId), ['if1', 'if2', 'if3']);
    expect(_thenIds(body[0] as IfStmt), ['set1']);
    expect(_thenIds(body[1] as IfStmt), ['set2']);
    expect(_thenIds(body[2] as IfStmt), ['set3']);
    expect(graph.entryIds, ['if1', 'if2', 'if3']);
    expect(graph.slotList('if1', 'then'), ['set1']);
    expect(graph.slotList('if2', 'then'), ['set2']);
  });

  test('an IF attached to THEN is nested, not a sibling', () {
    final h = _hist();
    _add(h, BlockIds.ctrlIf, id: 'if1');
    _add(h, BlockIds.ctrlIf, id: 'if2');
    _add(h, BlockIds.litBool, id: 'c1', literals: {'value': true});
    _add(h, BlockIds.litBool, id: 'c2', literals: {'value': true});
    _add(h, BlockIds.varSet, id: 'set1', literals: {'name': 'x'});
    _add(h, BlockIds.varSet, id: 'set2', literals: {'name': 'x'});
    _add(h, BlockIds.litNum, id: 'n1', literals: {'value': 1});
    _add(h, BlockIds.litNum, id: 'n2', literals: {'value': 2});
    _connect(h, 'c1', 'out', 'if1', 'condition');
    _connect(h, 'c2', 'out', 'if2', 'condition');
    _connect(h, 'n1', 'out', 'set1', 'value');
    _connect(h, 'n2', 'out', 'set2', 'value');
    _attach(h, 'if1', PortRef.mainBody);
    _attach(h, 'set1', const PortRef('if1', 'then'));
    _attach(h, 'if2', const PortRef('if1', 'then'));
    _attach(h, 'set2', const PortRef('if2', 'then'));

    final graph = h.current;
    expect(graph.entryIds, ['if1']);
    expect(graph.slotList('if1', 'then'), ['set1', 'if2']);
    expect(graph.parentOf('if2')?.blockId, 'if1');

    final body = _body(lowerer, graph);
    expect(body, hasLength(1));
    final outer = body.single as IfStmt;
    expect(outer.srcBlockId, 'if1');
    expect(outer.thenBody, hasLength(2));
    expect(outer.thenBody[1], isA<IfStmt>());
    expect((outer.thenBody[1] as IfStmt).srcBlockId, 'if2');
    expect(_thenIds(outer.thenBody[1] as IfStmt), ['set2']);
  });
}

List<Stmt> _body(Lowerer lowerer, BlockGraph graph) {
  final result = lowerer.lower(graph, _puzzle());
  expect(result.ok, isTrue, reason: '${result.errors}');
  return result.program!.functions.single.body;
}

List<String?> _thenIds(IfStmt stmt) =>
    [for (final step in stmt.thenBody) step.srcBlockId];

/// [ids] are attached to the main list, in order. Each THEN sets `x`.
BlockGraph _siblings(List<String> ids) {
  final h = _hist();
  for (var i = 0; i < ids.length; i++) {
    final n = i + 1;
    final ifId = ids[i];
    _add(h, BlockIds.ctrlIf, id: ifId);
    _add(h, BlockIds.litBool, id: 'c$n', literals: {'value': true});
    _add(h, BlockIds.varSet, id: 'set$n', literals: {'name': 'x'});
    _add(h, BlockIds.litNum, id: 'n$n', literals: {'value': n});
    _connect(h, 'c$n', 'out', ifId, 'condition');
    _connect(h, 'n$n', 'out', 'set$n', 'value');
    _attach(h, ifId, PortRef.mainBody);
    _attach(h, 'set$n', PortRef(ifId, 'then'));
  }
  return h.current;
}

Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "sibling_if_lower",
  "title": "L",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "s",
  "io": {
    "inputs": [{ "name": "x", "type": "num" }],
    "output": { "type": "num" }
  },
  "blocks": {
    "allow": ["ctrl.if", "var.set", "var.get", "lit.num", "lit.bool"]
  },
  "limits": { "maxOps": 1000 },
  "validators": { "output": "equal" },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "x": 1 }, "out": 1 }],
    "hidden": [{ "id": "h1", "in": { "x": 1 }, "out": 1 }]
  }
}
''');

GraphHistory _hist() => GraphHistory(BlockGraph(
      blocks: const {},
      variables: {'x': ValueType.number},
    ));

void _add(
  GraphHistory h,
  String catalogId, {
  required String id,
  Map<String, Object?> literals = const {},
}) {
  final r = h.apply(AddBlockCommand(catalogId: catalogId, id: id, literals: literals));
  expect(r.ok, isTrue, reason: r.decision.message);
}

void _connect(GraphHistory h, String from, String fromPort, String to, String toPort) {
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
