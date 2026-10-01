/// Canonical JSON for runtime values — the one conversion path between puzzle
/// fixtures and the interpreter.
///
/// Plain JSON is used where it cannot be misread:
///
/// | JSON | Runtime value |
/// |---|---|
/// | `null` | nothing |
/// | a number | `num` |
/// | `true` / `false` | `bool` |
/// | a string | `str` |
/// | an array | `array` |
///
/// Every JSON object is a **tagged** value and must carry `"type"`:
///
/// ```json
/// {"type": "map", "entries": [["a", 1], ["b", 2]]}
/// {"type": "set", "items": [1, 2, 3]}
/// {"type": "stack", "items": [1, 2, 3]}          // bottom → top
/// {"type": "queue", "items": [1, 2, 3]}          // front → back
/// {"type": "deque", "items": [1, 2, 3]}          // front → back
/// {"type": "listNode", "values": [1, 2, 3]}      // head first; empty list is null
/// {"type": "listNode", "values": [3, 2, 0, -4], "cycleTo": 1}
/// {"type": "treeNode", "value": 2, "left": {...}, "right": null}
/// {"type": "graph", "nodes": [{"id": 0, "neighbors": [1]}, {"id": 1, "neighbors": [0]}]}
/// ```
///
/// Nothing is guessed from an object's shape, and nothing in a fixture is ever
/// executed.
library;

import '../types/value_type.dart';
import 'runtime_value.dart';

/// Bounds for one fixture value, so a pathological file cannot exhaust memory
/// or the stack while it is being read or written.
final class FixtureLimits {
  const FixtureLimits({this.maxValues = 10000, this.maxDepth = 1000});

  /// Every value counts once: a container, each element, each tree node.
  final int maxValues;

  /// JSON nesting depth. A skewed tree nests one level per node.
  final int maxDepth;

  static const standard = FixtureLimits();
}

/// A fixture value that is not in the canonical format. [path] points into the
/// value (`$`, `$[2]`, `$.left.value`, `$.nodes[1].neighbors[0]`).
final class FixtureFormatException extends FormatException {
  FixtureFormatException(this.path, String message) : super(message);

  final String path;

  @override
  String toString() => '$path: $message';
}

/// The tags a JSON object may carry, mapped to the type they produce.
const Map<String, TypeAtom> fixtureTags = {
  'map': TypeAtom.map,
  'set': TypeAtom.set,
  'stack': TypeAtom.stack,
  'queue': TypeAtom.queue,
  'deque': TypeAtom.deque,
  'listNode': TypeAtom.listNode,
  'treeNode': TypeAtom.treeNode,
  'graph': TypeAtom.graph,
};

/// Decode canonical fixture JSON.
///
/// With [type], the value is checked against it while it is read, and
/// containers carry the declared element types. Without it, only the format is
/// checked. Throws [FixtureFormatException]; never anything else.
RuntimeValue valueFromJson(
  Object? json, {
  ValueType? type,
  FixtureLimits limits = FixtureLimits.standard,
}) {
  return _Decoder(limits).decode(json, type, r'$', 0);
}

/// Canonical JSON for [value]. `valueFromJson(valueToJson(v))` equals `v`, and
/// `valueToJson(valueFromJson(j))` is the canonical spelling of `j`. A heap
/// is the exception (H): it is written for display — its order and its items
/// in the order TAKE TOP gives them — but never read, so no puzzle takes or
/// returns one.
///
/// Throws [FixtureFormatException] for a value the format cannot hold: a tree
/// that contains itself, a graph that marked a node it does not have, or a
/// value past [limits].
Object? valueToJson(
  RuntimeValue value, {
  FixtureLimits limits = FixtureLimits.standard,
}) {
  return _Encoder(limits).encode(value, r'$', 0);
}

/// Why [type] cannot be written as a fixture, or null when it can. Puzzle io
/// types go through this before any fixture is read.
String? fixtureTypeProblem(ValueType type) {
  switch (type.atom) {
    case TypeAtom.voidType:
      return 'void is not a value.';
    case TypeAtom.generic:
      return 'A fixture needs a concrete type, not ${type.genericName}.';
    case TypeAtom.heap || TypeAtom.pair:
      return '${type.atom.name} has no fixture format yet.';
    case TypeAtom.set:
      final element = type.param;
      if (element == null || !_isKeyType(element)) {
        return 'Set items must be num, str or bool.';
      }
      return null;
    case TypeAtom.map:
      final key = type.param;
      final value = type.param2;
      if (key == null || !_isKeyType(key)) {
        return 'Map keys must be num, str or bool.';
      }
      return value == null ? 'A map needs a value type.' : fixtureTypeProblem(value);
    case TypeAtom.array || TypeAtom.stack || TypeAtom.queue || TypeAtom.deque:
      final element = type.param;
      return element == null
          ? '${type.atom.name} needs an element type.'
          : fixtureTypeProblem(element);
    case TypeAtom.number ||
          TypeAtom.boolean ||
          TypeAtom.string ||
          TypeAtom.nil ||
          TypeAtom.listNode ||
          TypeAtom.treeNode ||
          TypeAtom.graph:
      return null;
  }
}

bool _isKeyType(ValueType type) =>
    !type.nullable &&
    (type.atom == TypeAtom.number ||
        type.atom == TypeAtom.string ||
        type.atom == TypeAtom.boolean);

// --- decoding ---------------------------------------------------------------

final class _Decoder {
  _Decoder(this.limits);

  final FixtureLimits limits;
  int _count = 0;

  RuntimeValue decode(Object? json, ValueType? type, String path, int depth) {
    if (depth > limits.maxDepth) {
      throw FixtureFormatException(
        path,
        'Nested deeper than ${limits.maxDepth} levels.',
      );
    }
    if (++_count > limits.maxValues) {
      throw FixtureFormatException(
        path,
        'More than ${limits.maxValues} values in one fixture.',
      );
    }

    if (json == null) {
      if (type != null && !type.nullable && type.atom != TypeAtom.nil) {
        throw FixtureFormatException(path, 'Expected $type, got null.');
      }
      return const NilValue();
    }
    if (type != null && type.atom == TypeAtom.nil) {
      throw FixtureFormatException(path, 'Expected null, got ${_describe(json)}.');
    }

    switch (json) {
      case final num n:
        _expect(type, TypeAtom.number, json, path);
        if (!n.isFinite) {
          throw FixtureFormatException(path, 'Numbers must be finite.');
        }
        return NumValue(n);
      case final bool b:
        _expect(type, TypeAtom.boolean, json, path);
        return BoolValue(b);
      case final String s:
        _expect(type, TypeAtom.string, json, path);
        return StrValue(s);
      case final List<Object?> list:
        _expect(type, TypeAtom.array, json, path);
        final element = type?.param;
        return ArrayValue(
          [
            for (var i = 0; i < list.length; i++)
              decode(list[i], element, '$path[$i]', depth + 1),
          ],
          elementType: element ?? ValueType.number,
        );
      case final Map<String, Object?> object:
        return _tagged(object, type, path, depth);
      default:
        throw FixtureFormatException(path, 'Not a JSON value.');
    }
  }

  RuntimeValue _tagged(
    Map<String, Object?> object,
    ValueType? type,
    String path,
    int depth,
  ) {
    final tag = object['type'];
    if (tag is! String) {
      throw FixtureFormatException(
        path,
        'An object must name its "type": one of ${fixtureTags.keys.join(', ')}. '
        'Write a list as a plain JSON array.',
      );
    }
    final atom = fixtureTags[tag];
    if (atom == null) {
      throw FixtureFormatException(
        '$path.type',
        'Unknown type "$tag". Use one of ${fixtureTags.keys.join(', ')}.',
      );
    }
    if (type != null && type.atom != atom) {
      throw FixtureFormatException(path, 'Expected $type, got a $tag.');
    }
    return switch (atom) {
      TypeAtom.map => _map(object, type, path, depth),
      TypeAtom.set => _set(object, type, path, depth),
      TypeAtom.stack || TypeAtom.queue || TypeAtom.deque =>
        _sequence(object, atom, type, path, depth),
      TypeAtom.listNode => _list(object, path),
      TypeAtom.treeNode => _tree(object, path, depth),
      TypeAtom.graph => _graph(object, path),
      _ => throw StateError('unreachable tag $tag'),
    };
  }

  RuntimeValue _map(
    Map<String, Object?> object,
    ValueType? type,
    String path,
    int depth,
  ) {
    _closed(object, const {'type', 'entries'}, path);
    final entries = _requireList(object, 'entries', path);
    final keyType = type?.param;
    final valueType = type?.param2;
    final out = <Object, RuntimeValue>{};
    for (var i = 0; i < entries.length; i++) {
      final at = '$path.entries[$i]';
      final pair = entries[i];
      if (pair is! List<Object?> || pair.length != 2) {
        throw FixtureFormatException(at, 'A map entry is a [key, value] pair.');
      }
      final key = _key(decode(pair[0], keyType, '$at[0]', depth + 2), '$at[0]');
      if (out.containsKey(key)) {
        throw FixtureFormatException('$at[0]', 'Duplicate key $key.');
      }
      out[key] = decode(pair[1], valueType, '$at[1]', depth + 2);
    }
    return MapValue(
      out,
      keyType: keyType ?? ValueType.number,
      valueType: valueType ?? ValueType.number,
    );
  }

  RuntimeValue _set(
    Map<String, Object?> object,
    ValueType? type,
    String path,
    int depth,
  ) {
    _closed(object, const {'type', 'items'}, path);
    final items = _requireList(object, 'items', path);
    final element = type?.param;
    final out = <Object, RuntimeValue>{};
    for (var i = 0; i < items.length; i++) {
      final at = '$path.items[$i]';
      final value = decode(items[i], element, at, depth + 2);
      final key = _key(value, at);
      if (out.containsKey(key)) {
        throw FixtureFormatException(at, 'Duplicate set item $key.');
      }
      out[key] = value;
    }
    return SetValue(out, elementType: element ?? ValueType.number);
  }

  RuntimeValue _sequence(
    Map<String, Object?> object,
    TypeAtom atom,
    ValueType? type,
    String path,
    int depth,
  ) {
    _closed(object, const {'type', 'items'}, path);
    final raw = _requireList(object, 'items', path);
    final element = type?.param;
    final items = [
      for (var i = 0; i < raw.length; i++)
        decode(raw[i], element, '$path.items[$i]', depth + 2),
    ];
    final elementType = element ?? ValueType.number;
    return switch (atom) {
      TypeAtom.stack => StackValue(items, elementType: elementType),
      TypeAtom.queue => QueueValue(items, elementType: elementType),
      _ => DequeValue(items, elementType: elementType),
    };
  }

  RuntimeValue _list(Map<String, Object?> object, String path) {
    _closed(object, const {'type', 'values', 'cycleTo'}, path);
    final raw = _requireList(object, 'values', path);
    if (raw.isEmpty) {
      throw FixtureFormatException(
        '$path.values',
        'A linked list needs at least one value. An empty list is null.',
      );
    }
    final nodes = <ListNodeValue>[];
    for (var i = 0; i < raw.length; i++) {
      _countValue('$path.values[$i]');
      nodes.add(ListNodeValue(_number(raw[i], '$path.values[$i]')));
    }
    for (var i = 0; i + 1 < nodes.length; i++) {
      nodes[i].next = nodes[i + 1];
    }
    if (object.containsKey('cycleTo')) {
      final cycleTo = object['cycleTo'];
      if (cycleTo is! int || cycleTo < 0 || cycleTo >= nodes.length) {
        throw FixtureFormatException(
          '$path.cycleTo',
          'cycleTo is the index the last node links back to: '
          'a whole number from 0 to ${nodes.length - 1}.',
        );
      }
      nodes.last.next = nodes[cycleTo];
    }
    return nodes.first;
  }

  TreeNodeValue _tree(Map<String, Object?> object, String path, int depth) {
    _closed(object, const {'type', 'value', 'left', 'right'}, path);
    if (!object.containsKey('value')) {
      throw FixtureFormatException('$path.value', 'A tree node needs a value.');
    }
    final node = TreeNodeValue(_number(object['value'], '$path.value'));
    node.left = _child(object['left'], '$path.left', depth);
    node.right = _child(object['right'], '$path.right', depth);
    return node;
  }

  TreeNodeValue? _child(Object? json, String path, int depth) {
    if (json == null) return null;
    final value = decode(json, ValueType.treeNode, path, depth + 1);
    return value as TreeNodeValue;
  }

  RuntimeValue _graph(Map<String, Object?> object, String path) {
    _closed(object, const {'type', 'nodes', 'visited'}, path);
    final raw = _requireList(object, 'nodes', path);
    final adjacency = <num, List<num>>{};
    final pending = <(String, List<Object?>)>[];
    for (var i = 0; i < raw.length; i++) {
      final at = '$path.nodes[$i]';
      _countValue(at);
      final node = raw[i];
      if (node is! Map<String, Object?>) {
        throw FixtureFormatException(at, 'A graph node is {"id": …, "neighbors": […]}.');
      }
      _closed(node, const {'id', 'neighbors'}, at);
      if (!node.containsKey('id')) {
        throw FixtureFormatException('$at.id', 'A graph node needs an id.');
      }
      final id = _number(node['id'], '$at.id');
      if (adjacency.containsKey(id)) {
        throw FixtureFormatException('$at.id', 'Duplicate node id $id.');
      }
      final neighbors = node['neighbors'] ?? const <Object?>[];
      if (neighbors is! List<Object?>) {
        throw FixtureFormatException('$at.neighbors', 'neighbors is a list of node ids.');
      }
      adjacency[id] = [];
      pending.add((at, neighbors));
    }
    // Neighbors may point forward, so they are resolved once every id is known.
    // Cycles and self-loops are legal: many graph puzzles depend on them.
    final ids = adjacency.keys.toList();
    for (var i = 0; i < pending.length; i++) {
      final (at, neighbors) = pending[i];
      for (var j = 0; j < neighbors.length; j++) {
        final ref = '$at.neighbors[$j]';
        _countValue(ref);
        final target = _number(neighbors[j], ref);
        if (!adjacency.containsKey(target)) {
          throw FixtureFormatException(ref, 'No node has id $target.');
        }
        adjacency[ids[i]]!.add(target);
      }
    }
    final visited = <num>{};
    if (object.containsKey('visited')) {
      final marks = object['visited'];
      if (marks is! List<Object?>) {
        throw FixtureFormatException('$path.visited', 'visited is a list of node ids.');
      }
      for (var i = 0; i < marks.length; i++) {
        final ref = '$path.visited[$i]';
        _countValue(ref);
        final id = _number(marks[i], ref);
        if (!adjacency.containsKey(id)) {
          throw FixtureFormatException(ref, 'No node has id $id.');
        }
        if (!visited.add(id)) {
          throw FixtureFormatException(ref, 'Node $id is marked twice.');
        }
      }
    }
    return GraphValue(adjacency, visited: visited);
  }

  // --- helpers --------------------------------------------------------------

  void _countValue(String path) {
    if (++_count > limits.maxValues) {
      throw FixtureFormatException(
        path,
        'More than ${limits.maxValues} values in one fixture.',
      );
    }
  }

  void _expect(ValueType? type, TypeAtom atom, Object json, String path) {
    if (type != null && type.atom != atom) {
      throw FixtureFormatException(path, 'Expected $type, got ${_describe(json)}.');
    }
  }

  num _number(Object? json, String path) {
    if (json is num && json.isFinite) return json;
    throw FixtureFormatException(path, 'Expected a number, got ${_describe(json)}.');
  }

  Object _key(RuntimeValue value, String path) {
    final key = primitiveKey(value);
    if (key == null) {
      throw FixtureFormatException(path, 'Keys and set items must be a number, text or true/false.');
    }
    return key;
  }

  List<Object?> _requireList(Map<String, Object?> object, String key, String path) {
    final value = object[key];
    if (value is! List<Object?>) {
      throw FixtureFormatException('$path.$key', '"$key" must be a list.');
    }
    return value;
  }

  void _closed(Map<String, Object?> object, Set<String> allowed, String path) {
    for (final key in object.keys) {
      if (!allowed.contains(key)) {
        throw FixtureFormatException(
          '$path.$key',
          'Unknown field "$key". A ${object['type'] ?? 'value'} has: ${allowed.join(', ')}.',
        );
      }
    }
  }
}

String _describe(Object? json) {
  return switch (json) {
    null => 'null',
    final num n => 'the number $n',
    final bool b => '$b',
    final String s =>
      'the text "${s.length > 24 ? '${s.substring(0, 24)}…' : s}"',
    List<Object?>() => 'a list',
    final Map<String, Object?> m when m['type'] is String => 'a ${m['type']}',
    Map<String, Object?>() => 'an object without a "type"',
    _ => 'something that is not JSON',
  };
}

// --- encoding ---------------------------------------------------------------

final class _Encoder {
  _Encoder(this.limits);

  final FixtureLimits limits;
  int _count = 0;

  Object? encode(RuntimeValue value, String path, int depth) {
    if (depth > limits.maxDepth) {
      throw FixtureFormatException(path, 'Nested deeper than ${limits.maxDepth} levels.');
    }
    _counted(path);
    return switch (value) {
      NilValue() => null,
      NumValue(:final value) => value,
      BoolValue(:final value) => value,
      StrValue(:final value) => value,
      ArrayValue(:final elements) => [
          for (var i = 0; i < elements.length; i++)
            encode(elements[i], '$path[$i]', depth + 1),
        ],
      MapValue(:final entries) => {
          'type': 'map',
          'entries': [
            for (final (i, entry) in entries.entries.indexed)
              [entry.key, encode(entry.value, '$path.entries[$i][1]', depth + 2)],
          ],
        },
      SetValue(:final members) => {
          'type': 'set',
          'items': [
            for (final (i, item) in members.values.indexed)
              encode(item, '$path.items[$i]', depth + 2),
          ],
        },
      StackValue(:final items) => _items('stack', items, path, depth),
      QueueValue(:final items) => _items('queue', items, path, depth),
      DequeValue(:final items) => _items('deque', items, path, depth),
      final HeapValue heap => {
          'type': 'heap',
          'order': heap.isMax ? 'max' : 'min',
          'items': heap.inTakeOrder(),
        },
      final ListNodeValue head => _list(head, path),
      final TreeNodeValue root => _tree(root, path, depth, <TreeNodeValue>{}),
      final GraphValue graph => _graph(graph, path),
    };
  }

  Map<String, Object?> _items(
    String tag,
    List<RuntimeValue> items,
    String path,
    int depth,
  ) {
    return {
      'type': tag,
      'items': [
        for (var i = 0; i < items.length; i++)
          encode(items[i], '$path.items[$i]', depth + 2),
      ],
    };
  }

  Map<String, Object?> _list(ListNodeValue head, String path) {
    final index = <ListNodeValue, int>{};
    final values = <num>[];
    int? cycleTo;
    ListNodeValue? cursor = head;
    while (cursor != null) {
      final seen = index[cursor];
      if (seen != null) {
        cycleTo = seen;
        break;
      }
      _counted('$path.values[${values.length}]');
      index[cursor] = values.length;
      values.add(cursor.value);
      cursor = cursor.next;
    }
    return {
      'type': 'listNode',
      'values': values,
      'cycleTo': ?cycleTo,
    };
  }

  Map<String, Object?> _tree(
    TreeNodeValue node,
    String path,
    int depth,
    Set<TreeNodeValue> onPath,
  ) {
    if (depth > limits.maxDepth) {
      throw FixtureFormatException(path, 'Nested deeper than ${limits.maxDepth} levels.');
    }
    if (!onPath.add(node)) {
      throw FixtureFormatException(path, 'A tree cannot contain itself.');
    }
    Object? child(TreeNodeValue? next, String at) {
      if (next == null) return null;
      _counted(at);
      return _tree(next, at, depth + 1, onPath);
    }

    final json = {
      'type': 'treeNode',
      'value': node.value,
      'left': child(node.left, '$path.left'),
      'right': child(node.right, '$path.right'),
    };
    onPath.remove(node);
    return json;
  }

  Map<String, Object?> _graph(GraphValue graph, String path) {
    final nodes = <Object?>[];
    for (final entry in graph.adjacency.entries) {
      _counted('$path.nodes[${nodes.length}]');
      nodes.add({'id': entry.key, 'neighbors': List<num>.of(entry.value)});
    }
    for (final mark in graph.visited) {
      if (!graph.adjacency.containsKey(mark)) {
        throw FixtureFormatException(
          '$path.visited',
          'Node $mark is marked but is not in the graph.',
        );
      }
    }
    // Sorted so two graphs with the same marks always write the same JSON.
    final visited = graph.visited.toList()..sort();
    return {
      'type': 'graph',
      'nodes': nodes,
      if (visited.isNotEmpty) 'visited': visited,
    };
  }

  void _counted(String path) {
    if (++_count > limits.maxValues) {
      throw FixtureFormatException(
        path,
        'More than ${limits.maxValues} values in one value.',
      );
    }
  }
}
