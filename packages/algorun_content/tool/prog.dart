import 'package:algorun_engine/algorun_engine.dart';

/// Builds a block graph with the same commands the phone editor issues.
///
/// Statements land in the current well. Expressions are created first and
/// then plugged in, which is a valid tree: [replayInEditor] rebuilds it
/// top-down and does not care about this construction order.
final class Prog {
  Prog({
    required Map<String, String> inputs,
    required Map<String, String> pool,
  }) {
    history = GraphHistory(BlockGraph(
      blocks: const {},
      variables: {for (final e in inputs.entries) e.key: parseValueType(e.value)},
    ));
    for (final e in pool.entries) {
      _must(DeclareVariableCommand(name: e.key, type: parseValueType(e.value)));
    }
    _wells.add((PortRef.mainBody, 0));
  }

  late final GraphHistory history;
  final _wells = <(PortRef, int)>[];
  var _seq = 0;

  BlockGraph get graph => history.current;

  String lit(int value) => _add(BlockIds.litNum, {'value': value});

  String truth(bool value) => _add(BlockIds.litBool, {'value': value});

  String get(String name) => _add(BlockIds.varGet, {'name': name});

  String bin(String op, String left, String right) {
    final id = _add(op);
    _plug(left, id, 'left');
    _plug(right, id, 'right');
    return id;
  }

  String una(String op, String arg, {String port = 'arg'}) {
    final id = _add(op);
    _plug(arg, id, port);
    return id;
  }

  String call(String op, Map<String, String> args) {
    final id = _add(op);
    for (final e in args.entries) {
      _plug(e.value, id, e.key);
    }
    return id;
  }

  String add(String left, String right) => bin(BlockIds.arithAdd, left, right);
  String sub(String left, String right) => bin(BlockIds.arithSub, left, right);
  String mul(String left, String right) => bin(BlockIds.arithMul, left, right);
  String min(String left, String right) => bin(BlockIds.arithMin, left, right);
  String max(String left, String right) => bin(BlockIds.arithMax, left, right);
  String eq(String left, String right) => bin(BlockIds.cmpEq, left, right);
  String lt(String left, String right) => bin(BlockIds.cmpLt, left, right);
  String le(String left, String right) => bin(BlockIds.cmpLe, left, right);
  String gt(String left, String right) => bin(BlockIds.cmpGt, left, right);
  String ge(String left, String right) => bin(BlockIds.cmpGe, left, right);
  String and(String left, String right) => bin(BlockIds.logicAnd, left, right);
  String or(String left, String right) => bin(BlockIds.logicOr, left, right);
  String not(String arg) => una(BlockIds.logicNot, arg);
  String isNothing(String arg) => una(BlockIds.logicIsNothing, arg, port: 'value');
  String isNotNothing(String arg) => una(BlockIds.logicIsNotNothing, arg, port: 'value');
  String len(String array) => una(BlockIds.arrLen, array, port: 'array');
  String at(String array, String index) => call(BlockIds.arrGet, {'array': array, 'index': index});
  String nodeValue(String node) => una(BlockIds.llValue, node, port: 'node');
  String nextNode(String node) => una(BlockIds.llNext, node, port: 'node');
  String treeValue(String node) => una(BlockIds.treeValue, node, port: 'node');
  String treeLeft(String node) => una(BlockIds.treeLeft, node, port: 'node');
  String treeRight(String node) => una(BlockIds.treeRight, node, port: 'node');
  String neighbors(String graph, String node) =>
      call(BlockIds.graphNeighbors, {'graph': graph, 'node': node});
  String visited(String graph, String node) =>
      call(BlockIds.graphVisited, {'graph': graph, 'node': node});
  String nodeCount(String graph) => una(BlockIds.graphNodeCount, graph, port: 'graph');
  String abs(String arg) => una(BlockIds.arithAbs, arg);
  String mod(String left, String right) => bin(BlockIds.arithMod, left, right);
  String floorDiv(String left, String right) => bin(BlockIds.arithFloorDiv, left, right);
  String ne(String left, String right) => bin(BlockIds.cmpNe, left, right);

  void set(String name, String value) {
    final id = _add(BlockIds.varSet, {'name': name});
    _plug(value, id, 'value');
    _stmt(id);
  }

  void inc(String name) => _stmt(_add(BlockIds.varInc, {'name': name}));

  void dec(String name) => _stmt(_add(BlockIds.varDec, {'name': name}));

  void ret(String value) => _stmt(call(BlockIds.ctrlReturn, {'value': value}));

  void retBool(bool value) => ret(truth(value));

  void retNum(int value) => ret(lit(value));

  void append(String array, String value) =>
      _stmt(call(BlockIds.arrAppend, {'array': get(array), 'value': value}));

  void setAt(String array, String index, String value) =>
      _stmt(call(BlockIds.arrSet, {'array': get(array), 'index': index, 'value': value}));

  void removeAt(String array, String index) =>
      _stmt(call(BlockIds.arrRemove, {'array': get(array), 'index': index}));

  void push(String stack, String value) =>
      _stmt(call(BlockIds.stackPush, {'stack': get(stack), 'value': value}));

  void enq(String queue, String value) =>
      _stmt(call(BlockIds.queueEnq, {'queue': get(queue), 'value': value}));

  void mark(String graph, String node) =>
      _stmt(call(BlockIds.graphMark, {'graph': get(graph), 'node': node}));

  void put(String map, String key, String value) =>
      _stmt(call(BlockIds.mapSet, {'map': get(map), 'key': key, 'value': value}));

  void addSet(String set, String value) =>
      _stmt(call(BlockIds.setAdd, {'set': get(set), 'value': value}));

  String pop(String stack) => una(BlockIds.stackPop, get(stack), port: 'stack');

  String peek(String stack) => una(BlockIds.stackPeek, get(stack), port: 'stack');

  String deq(String queue) => una(BlockIds.queueDeq, get(queue), port: 'queue');

  String front(String queue) => una(BlockIds.queueFront, get(queue), port: 'queue');

  String stackEmpty(String stack) => una(BlockIds.stackEmpty, get(stack), port: 'stack');

  String queueEmpty(String queue) => una(BlockIds.queueEmpty, get(queue), port: 'queue');

  String mapGet(String map, String key) => call(BlockIds.mapGet, {'map': get(map), 'key': key});

  String mapHas(String map, String key) => call(BlockIds.mapHas, {'map': get(map), 'key': key});

  String setHas(String set, String value) => call(BlockIds.setHas, {'set': get(set), 'value': value});

  String setSize(String set) => una(BlockIds.setSize, get(set), port: 'set');

  String freshList() => _add(BlockIds.newArray);

  String freshMap() => _add(BlockIds.newMap);

  String freshSet() => _add(BlockIds.newSet);

  String freshStack() => _add(BlockIds.newStack);

  String freshQueue() => _add(BlockIds.newQueue);

  void iff(String cond, void Function() then, {void Function()? els}) {
    final id = _add(BlockIds.ctrlIf);
    _plug(cond, id, 'condition');
    _stmt(id);
    _wells.add((PortRef(id, 'then'), 0));
    then();
    _wells.removeLast();
    if (els != null) {
      final clause = _add(BlockIds.ctrlElse);
      _must(ConnectCommand(from: PortRef(clause, 'clause'), to: PortRef(id, 'else')));
      _enter(clause);
      _wells.add((PortRef(clause, 'body'), 0));
      els();
      _wells.removeLast();
    }
  }

  void whil(String cond, void Function() body) {
    final id = _add(BlockIds.ctrlWhile);
    _plug(cond, id, 'condition');
    _stmt(id);
    _wells.add((PortRef(id, 'body'), 0));
    body();
    _wells.removeLast();
  }

  void range(String name, String start, String end, void Function() body, {String? step}) {
    final id = _add(BlockIds.ctrlForRange, {'name': name});
    _plug(start, id, 'start');
    _plug(end, id, 'end');
    if (step != null) _plug(step, id, 'step');
    _stmt(id);
    _wells.add((PortRef(id, 'body'), 0));
    body();
    _wells.removeLast();
  }

  void each(String name, String collection, void Function() body) {
    final id = _add(BlockIds.ctrlForEach, {'name': name});
    _plug(collection, id, 'collection');
    _stmt(id);
    _wells.add((PortRef(id, 'body'), 0));
    body();
    _wells.removeLast();
  }

  void _stmt(String id, [Map<String, Object?> extra = const {}]) {
    if (extra.isNotEmpty) {
      _must(SetLiteralsCommand(id, extra));
    }
    final top = _wells.last;
    _must(AttachStatementCommand(blockId: id, to: top.$1, index: top.$2));
    _wells[_wells.length - 1] = (top.$1, top.$2 + 1);
    _enter(id);
  }

  String _add(String catalog, [Map<String, Object?> literals = const {}]) {
    final id = 'b${_seq++}';
    _must(AddBlockCommand(catalogId: catalog, id: id, literals: literals));
    return id;
  }

  final _inTree = <String>{};
  final _pending = <String, List<(String child, String port)>>{};

  void _plug(String child, String parent, String port) {
    if (_inTree.contains(parent)) {
      _connect(child, parent, port);
    } else {
      (_pending[parent] ??= []).add((child, port));
    }
  }

  void _connect(String child, String parent, String port) {
    _fill(child);
    _must(ConnectCommand(from: PortRef(child, 'out'), to: PortRef(parent, port)));
    _enter(child);
  }

  /// Connect children that do not need narrowing, so a generic block's output
  /// type is known before it is plugged into its parent. Children that may be
  /// empty stay pending until the parent sits in the program.
  void _fill(String id) {
    final waiting = _pending[id];
    if (waiting == null || waiting.isEmpty) return;
    _pending[id] = [];
    final later = <(String, String)>[];
    for (final item in waiting) {
      _fill(item.$1);
      final result = history.apply(
        ConnectCommand(from: PortRef(item.$1, 'out'), to: PortRef(id, item.$2)),
      );
      if (result.ok) continue;
      if (result.decision.code == 'may_be_empty') {
        later.add(item);
        continue;
      }
      throw StateError(
        'ConnectCommand refused: ${result.decision.code} ${result.decision.message}\n${StackTrace.current}',
      );
    }
    _pending[id] = later;
  }

  void _enter(String id) {
    if (!_inTree.add(id)) return;
    final waiting = List<(String, String)>.of(_pending.remove(id) ?? const []);
    for (final item in waiting) {
      _connect(item.$1, id, item.$2);
    }
    final block = graph.blocks[id];
    if (block == null) return;
    for (final slot in block.slots.values) {
      switch (slot) {
        case RefBinding(:final blockId):
          if (!_inTree.contains(blockId)) _enter(blockId);
        case ListBinding(:final blockIds):
          for (final blockId in blockIds) {
            if (!_inTree.contains(blockId)) _enter(blockId);
          }
      }
    }
  }

  void _must(GraphCommand command) {
    final result = history.apply(command);
    if (result.ok) return;
    throw StateError('${command.runtimeType} refused: ${result.decision.code} ${result.decision.message}');
  }
}
