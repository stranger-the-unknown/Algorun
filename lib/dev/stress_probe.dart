import 'package:algorun_engine/algorun_engine.dart';

import '../editor/editor_controller.dart';

/// The editor stress probe (MS13): an unlisted puzzle whose program is long
/// and deep enough to test scrolling, nesting, folding, selection, moves,
/// deletes, undo / redo and restoring from a save on a phone. Not a campaign
/// puzzle; it opens from Settings → Developer in debug builds and in tests.
const stressProbeId = 'ms13_stress_probe';

/// Builds the probe's program through the editor's own typed placement
/// (`EditorController.place`, the path every tap takes), so building it is
/// itself a test of insertion. 82 blocks: two nested WHILE loops, IF / ELSE
/// three deep, a map, two lists, IS NOTHING narrowing and a long variable
/// name.
///
/// counts = NEW MAP; evens = NEW LIST; odds = NEW LIST
/// echoes = 0; running_total_of_even_readings = 0; i = 0
/// WHILE i < LENGTH readings
///   x = readings[i]; c = GET counts x
///   IF c IS NOTHING: SET counts x TO 1  ELSE: SET counts x TO c + 1
///   IF x MOD 2 = 0: APPEND x TO evens; running… = running… + x
///   ELSE: APPEND x TO odds
///   j = 0
///   WHILE j < i
///     IF readings[j] = x: IF x > 0: INCREMENT echoes
///     INCREMENT j
///   INCREMENT i
/// RETURN echoes + running… + LENGTH odds
void buildStressProgram(EditorController c) {
  for (final v in c.puzzle.variablePool) {
    if (!c.graph.variables.containsKey(v.name)) c.declareVariable(v.name, v.type);
  }
  String put(String id, PortRef to, [Map<String, Object?> literals = const {}]) {
    final placed = c.place(Placement(catalogId: id, literals: literals), to: to);
    if (placed == null) throw StateError('The stress program could not place $id: ${c.flash}');
    return placed;
  }

  void get(String name, String parent, String port) =>
      put(BlockIds.varGet, PortRef(parent, port), {'name': name});
  void number(int value, String parent, String port) =>
      put(BlockIds.litNum, PortRef(parent, port), {'value': value});
  String set(String name, PortRef list) => put(BlockIds.varSet, list, {'name': name});
  const running = 'running_total_of_even_readings';
  const main = PortRef.mainBody;

  put(BlockIds.newMap, PortRef(set('counts', main), 'value'));
  put(BlockIds.newArray, PortRef(set('evens', main), 'value'));
  put(BlockIds.newArray, PortRef(set('odds', main), 'value'));
  number(0, set('echoes', main), 'value');
  number(0, set(running, main), 'value');
  number(0, set('i', main), 'value');

  final outer = put(BlockIds.ctrlWhile, main);
  final more = put(BlockIds.cmpLt, PortRef(outer, 'condition'));
  get('i', more, 'left');
  get('readings', put(BlockIds.arrLen, PortRef(more, 'right')), 'array');
  final body = PortRef(outer, 'body');

  final reading = put(BlockIds.arrGet, PortRef(set('x', body), 'value'));
  get('readings', reading, 'array');
  get('i', reading, 'index');
  final lookup = put(BlockIds.mapGet, PortRef(set('c', body), 'value'));
  get('counts', lookup, 'map');
  get('x', lookup, 'key');

  final firstTime = put(BlockIds.ctrlIf, body);
  get('c', put(BlockIds.logicIsNothing, PortRef(firstTime, 'condition')), 'value');
  final one = put(BlockIds.mapSet, PortRef(firstTime, 'then'));
  get('counts', one, 'map');
  get('x', one, 'key');
  number(1, one, 'value');
  final again = put(BlockIds.ctrlElse, PortRef(firstTime, 'else'));
  final bump = put(BlockIds.mapSet, PortRef(again, 'body'));
  get('counts', bump, 'map');
  get('x', bump, 'key');
  final plusOne = put(BlockIds.arithAdd, PortRef(bump, 'value'));
  get('c', plusOne, 'left'); // a number here: the ELSE of IS NOTHING
  number(1, plusOne, 'right');

  final parity = put(BlockIds.ctrlIf, body);
  final even = put(BlockIds.cmpEq, PortRef(parity, 'condition'));
  final mod = put(BlockIds.arithMod, PortRef(even, 'left'));
  get('x', mod, 'left');
  number(2, mod, 'right');
  number(0, even, 'right');
  final keepEven = put(BlockIds.arrAppend, PortRef(parity, 'then'));
  get('evens', keepEven, 'array');
  get('x', keepEven, 'value');
  final total = put(BlockIds.arithAdd, PortRef(set(running, PortRef(parity, 'then')), 'value'));
  get(running, total, 'left');
  get('x', total, 'right');
  final odd = put(BlockIds.ctrlElse, PortRef(parity, 'else'));
  final keepOdd = put(BlockIds.arrAppend, PortRef(odd, 'body'));
  get('odds', keepOdd, 'array');
  get('x', keepOdd, 'value');

  number(0, set('j', body), 'value');
  final inner = put(BlockIds.ctrlWhile, body);
  final earlier = put(BlockIds.cmpLt, PortRef(inner, 'condition'));
  get('j', earlier, 'left');
  get('i', earlier, 'right');
  final same = put(BlockIds.ctrlIf, PortRef(inner, 'body'));
  final equal = put(BlockIds.cmpEq, PortRef(same, 'condition'));
  final before = put(BlockIds.arrGet, PortRef(equal, 'left'));
  get('readings', before, 'array');
  get('j', before, 'index');
  get('x', equal, 'right');
  final positive = put(BlockIds.ctrlIf, PortRef(same, 'then'));
  final above = put(BlockIds.cmpGt, PortRef(positive, 'condition'));
  get('x', above, 'left');
  number(0, above, 'right');
  put(BlockIds.varInc, PortRef(positive, 'then'), {'name': 'echoes'});
  put(BlockIds.varInc, PortRef(inner, 'body'), {'name': 'j'});
  put(BlockIds.varInc, body, {'name': 'i'});

  final answer = put(BlockIds.ctrlReturn, main);
  final sum = put(BlockIds.arithAdd, PortRef(answer, 'value'));
  final partial = put(BlockIds.arithAdd, PortRef(sum, 'left'));
  get('echoes', partial, 'left');
  get(running, partial, 'right');
  get('odds', put(BlockIds.arrLen, PortRef(sum, 'right')), 'array');

  c.selectBlock(null);
  c.revealId = null;
}
