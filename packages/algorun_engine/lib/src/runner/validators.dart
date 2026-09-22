import '../runtime/runtime_value.dart';

/// Named output comparators. JSON must never embed executable predicates: a
/// puzzle picks a comparator by name from this closed registry, and nothing
/// else. Adding a comparator is a change here, never in content.
enum ValidatorId {
  equal,
  unorderedArray,
  setEqual,
  unorderedPairs,
  listEqualByValue,
  treeEqual,
}

ValidatorId parseValidatorId(String raw) {
  return ValidatorId.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => throw FormatException('Unknown validator: $raw'),
  );
}

/// Every comparator is deterministic and free of side effects.
typedef OutputComparator = bool Function(
  RuntimeValue actual,
  RuntimeValue expected,
);

/// The closed registry. `compareOutputs` is the only way in.
const Map<ValidatorId, OutputComparator> outputValidators = {
  ValidatorId.equal: valuesEqual,
  ValidatorId.unorderedArray: unorderedArrayEqual,
  ValidatorId.setEqual: setEqual,
  ValidatorId.unorderedPairs: unorderedPairsEqual,
  ValidatorId.listEqualByValue: sequenceEqual,
  ValidatorId.treeEqual: treeEqual,
};

bool compareOutputs(ValidatorId id, RuntimeValue actual, RuntimeValue expected) {
  return outputValidators[id]!(actual, expected);
}

/// Strict equality. Shapes must match: a linked list is not an array, even
/// when it holds the same values. Use `listEqualByValue` for that.
bool valuesEqual(RuntimeValue a, RuntimeValue b) {
  if (a.runtimeType != b.runtimeType) {
    if (a is NumValue && b is NumValue) {
      return a.value == b.value;
    }
    return false;
  }
  return switch (a) {
    NilValue() => true,
    NumValue(:final value) => value == (b as NumValue).value,
    BoolValue(:final value) => value == (b as BoolValue).value,
    StrValue(:final value) => value == (b as StrValue).value,
    ArrayValue(:final elements) => _listEqual(elements, (b as ArrayValue).elements),
    MapValue(:final entries) => _mapEqual(entries, (b as MapValue).entries),
    SetValue(:final members) => _mapEqual(members, (b as SetValue).members),
    StackValue(:final items) => _listEqual(items, (b as StackValue).items),
    QueueValue(:final items) => _listEqual(items, (b as QueueValue).items),
    DequeValue(:final items) => _listEqual(items, (b as DequeValue).items),
    ListNodeValue() => _chainEqual(a, b as ListNodeValue),
    TreeNodeValue() => _treeNodeEqual(a, b as TreeNodeValue),
    GraphValue() => _graphEqual(a, b as GraphValue),
  };
}

/// Ordered comparison across shapes: an array, stack, queue, deque, set or
/// linked list with the same values in the same order is equal.
bool sequenceEqual(RuntimeValue a, RuntimeValue b) {
  final left = asSequence(a);
  final right = asSequence(b);
  if (left == null || right == null) return valuesEqual(a, b);
  return _listEqual(left, right);
}

/// Order does not matter; how many times a value appears does.
bool unorderedArrayEqual(RuntimeValue a, RuntimeValue b) {
  final left = asSequence(a);
  final right = asSequence(b);
  if (left == null || right == null) return valuesEqual(a, b);
  return _multisetEqual(left, right, valuesEqual);
}

/// Order and repeats do not matter: the same distinct members on both sides.
bool setEqual(RuntimeValue a, RuntimeValue b) {
  final left = asSequence(a);
  final right = asSequence(b);
  if (left == null || right == null) return valuesEqual(a, b);
  final leftDistinct = _distinct(left);
  final rightDistinct = _distinct(right);
  if (leftDistinct.length != rightDistinct.length) return false;
  return _multisetEqual(leftDistinct, rightDistinct, valuesEqual);
}

/// A collection of pairs where neither the order of the pairs nor the order
/// inside a pair matters — index pairs like `[[0,1]]` and `[[1,0]]` match.
bool unorderedPairsEqual(RuntimeValue a, RuntimeValue b) {
  final left = asSequence(a);
  final right = asSequence(b);
  if (left == null || right == null) return valuesEqual(a, b);
  return _multisetEqual(left, right, _pairEqual);
}

/// Structural tree comparison. Accepts a runtime tree on either side, and a
/// `{ "value": …, "left": …, "right": … }` fixture as the expected side.
bool treeEqual(RuntimeValue a, RuntimeValue b) {
  final left = _asTree(a);
  final right = _asTree(b);
  if (left == null || right == null) return valuesEqual(a, b);
  if (left.empty || right.empty) return left.empty && right.empty;
  return left.value == right.value &&
      treeEqual(left.left, right.left) &&
      treeEqual(left.right, right.right);
}

/// The values of an ordered collection, or null when the value is not one.
/// A cycle in a linked list stops the walk instead of hanging.
List<RuntimeValue>? asSequence(RuntimeValue value) {
  return switch (value) {
    ArrayValue(:final elements) => elements,
    StackValue(:final items) => items,
    QueueValue(:final items) => items,
    DequeValue(:final items) => items,
    SetValue(:final members) => members.values.toList(),
    ListNodeValue() => _chainValues(value),
    _ => null,
  };
}

bool _pairEqual(RuntimeValue a, RuntimeValue b) {
  final left = asSequence(a);
  final right = asSequence(b);
  if (left == null || right == null) return valuesEqual(a, b);
  return _multisetEqual(left, right, valuesEqual);
}

List<RuntimeValue> _distinct(List<RuntimeValue> values) {
  final out = <RuntimeValue>[];
  for (final value in values) {
    if (!out.any((seen) => valuesEqual(seen, value))) out.add(value);
  }
  return out;
}

bool _multisetEqual(
  List<RuntimeValue> a,
  List<RuntimeValue> b,
  OutputComparator equal,
) {
  if (a.length != b.length) return false;
  final used = List<bool>.filled(b.length, false);
  for (final item in a) {
    var found = false;
    for (var i = 0; i < b.length; i++) {
      if (!used[i] && equal(item, b[i])) {
        used[i] = true;
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}

List<RuntimeValue> _chainValues(ListNodeValue head) {
  final out = <RuntimeValue>[];
  final seen = <ListNodeValue>{};
  ListNodeValue? cursor = head;
  while (cursor != null && seen.add(cursor)) {
    out.add(NumValue(cursor.value));
    cursor = cursor.next;
  }
  return out;
}

/// A tree node, or a fixture object shaped like one. `empty` is the null leaf.
final class _TreeShape {
  const _TreeShape.empty()
      : value = 0,
        left = const NilValue(),
        right = const NilValue(),
        empty = true;

  const _TreeShape(this.value, this.left, this.right) : empty = false;

  final num value;
  final RuntimeValue left;
  final RuntimeValue right;
  final bool empty;
}

_TreeShape? _asTree(RuntimeValue value) {
  if (value is NilValue) return const _TreeShape.empty();
  if (value is TreeNodeValue) {
    return _TreeShape(
      value.value,
      value.left ?? const NilValue(),
      value.right ?? const NilValue(),
    );
  }
  if (value is MapValue) {
    final node = value.entries['value'];
    if (node is! NumValue) return null;
    return _TreeShape(
      node.value,
      value.entries['left'] ?? const NilValue(),
      value.entries['right'] ?? const NilValue(),
    );
  }
  return null;
}

/// Linked lists compare by the values in the chain. A cycle on one side only
/// is a difference, not a hang.
bool _chainEqual(ListNodeValue? a, ListNodeValue? b) {
  final seenA = <ListNodeValue>{};
  final seenB = <ListNodeValue>{};
  var left = a;
  var right = b;
  while (left != null && right != null) {
    final cycleA = !seenA.add(left);
    final cycleB = !seenB.add(right);
    if (cycleA || cycleB) return cycleA && cycleB;
    if (left.value != right.value) return false;
    left = left.next;
    right = right.next;
  }
  return left == null && right == null;
}

bool _treeNodeEqual(TreeNodeValue? a, TreeNodeValue? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.value == b.value &&
      _treeNodeEqual(a.left, b.left) &&
      _treeNodeEqual(a.right, b.right);
}

bool _graphEqual(GraphValue a, GraphValue b) {
  if (a.adjacency.length != b.adjacency.length) return false;
  for (final e in a.adjacency.entries) {
    final other = b.adjacency[e.key];
    if (other == null || other.length != e.value.length) return false;
    for (var i = 0; i < e.value.length; i++) {
      if (e.value[i] != other[i]) return false;
    }
  }
  return a.visited.length == b.visited.length &&
      a.visited.every(b.visited.contains);
}

bool _listEqual(List<RuntimeValue> a, List<RuntimeValue> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!valuesEqual(a[i], b[i])) return false;
  }
  return true;
}

bool _mapEqual(Map<Object, RuntimeValue> a, Map<Object, RuntimeValue> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final other = b[e.key];
    if (other == null || !valuesEqual(e.value, other)) return false;
  }
  return true;
}
