import '../types/value_type.dart';

/// Sandboxed runtime value. Objects that need identity (nodes, collections)
/// carry an [id] allocated by the VM.
sealed class RuntimeValue {
  const RuntimeValue();

  ValueType get type;

  Object? toJson();
}

final class NilValue extends RuntimeValue {
  const NilValue();

  @override
  ValueType get type => ValueType.nil;

  @override
  Object? toJson() => null;
}

final class NumValue extends RuntimeValue {
  const NumValue(this.value);
  final num value;

  @override
  ValueType get type => ValueType.number;

  @override
  Object? toJson() => value;
}

final class BoolValue extends RuntimeValue {
  const BoolValue(this.value);
  final bool value;

  @override
  ValueType get type => ValueType.boolean;

  @override
  Object? toJson() => value;
}

final class StrValue extends RuntimeValue {
  const StrValue(this.value);
  final String value;

  @override
  ValueType get type => ValueType.string;

  @override
  Object? toJson() => value;
}

final class ArrayValue extends RuntimeValue {
  ArrayValue(this.elements, {this.id = 0, this.elementType = ValueType.number});
  final int id;
  final List<RuntimeValue> elements;
  final ValueType elementType;

  @override
  ValueType get type => ValueType.array(elementType);

  @override
  Object? toJson() => elements.map((e) => e.toJson()).toList();
}

final class MapValue extends RuntimeValue {
  MapValue(
    this.entries, {
    this.id = 0,
    this.keyType = ValueType.number,
    this.valueType = ValueType.number,
  });
  final int id;
  final Map<Object, RuntimeValue> entries;
  final ValueType keyType;
  final ValueType valueType;

  @override
  ValueType get type => ValueType.mapOf(keyType, valueType);

  @override
  Object? toJson() => {
        for (final e in entries.entries) e.key.toString(): e.value.toJson(),
      };
}

/// Decode a JSON fixture into a runtime value. Used by the test runner.
RuntimeValue valueFromJson(Object? json) {
  if (json == null) return const NilValue();
  if (json is bool) return BoolValue(json);
  if (json is num) return NumValue(json);
  if (json is String) return StrValue(json);
  if (json is List) {
    return ArrayValue(json.map(valueFromJson).toList());
  }
  if (json is Map) {
    return MapValue({
      for (final e in json.entries) e.key as Object: valueFromJson(e.value),
    });
  }
  throw FormatException('Unsupported fixture value: $json');
}

/// Insertion-ordered set. Members are keyed by [primitiveKey] so value
/// equality works for numbers, strings, and booleans.
final class SetValue extends RuntimeValue {
  SetValue(this.members, {this.id = 0, this.elementType = ValueType.number});
  final int id;
  final Map<Object, RuntimeValue> members;
  final ValueType elementType;

  @override
  ValueType get type => ValueType.setOf(elementType);

  @override
  Object? toJson() => [for (final v in members.values) v.toJson()];
}

/// LIFO. The top of the stack is the last element of [items].
final class StackValue extends RuntimeValue {
  StackValue(this.items, {this.id = 0, this.elementType = ValueType.number});
  final int id;
  final List<RuntimeValue> items;
  final ValueType elementType;

  @override
  ValueType get type => ValueType.stackOf(elementType);

  @override
  Object? toJson() => [for (final v in items) v.toJson()];
}

/// FIFO. The front of the queue is the first element of [items].
final class QueueValue extends RuntimeValue {
  QueueValue(this.items, {this.id = 0, this.elementType = ValueType.number});
  final int id;
  final List<RuntimeValue> items;
  final ValueType elementType;

  @override
  ValueType get type => ValueType.queueOf(elementType);

  @override
  Object? toJson() => [for (final v in items) v.toJson()];
}

/// Double-ended queue. Front is first, back is last.
final class DequeValue extends RuntimeValue {
  DequeValue(this.items, {this.id = 0, this.elementType = ValueType.number});
  final int id;
  final List<RuntimeValue> items;
  final ValueType elementType;

  @override
  ValueType get type => ValueType.dequeOf(elementType);

  @override
  Object? toJson() => [for (final v in items) v.toJson()];
}

/// Singly linked list node. [next] is mutable so `ll.set_next` can relink.
final class ListNodeValue extends RuntimeValue {
  ListNodeValue(this.value, {this.next, this.id = 0});
  num value;
  ListNodeValue? next;
  final int id;

  @override
  ValueType get type => ValueType.listNode;

  /// Serialized as the chain of values. A cycle terminates with `'...'` so a
  /// relinked list can never hang the UI.
  @override
  Object? toJson() {
    final out = <Object?>[];
    final seen = <ListNodeValue>{};
    ListNodeValue? cursor = this;
    while (cursor != null) {
      if (!seen.add(cursor)) {
        out.add('...');
        break;
      }
      out.add(cursor.value);
      cursor = cursor.next;
    }
    return out;
  }
}

/// Binary tree node.
final class TreeNodeValue extends RuntimeValue {
  TreeNodeValue(this.value, {this.left, this.right, this.id = 0});
  num value;
  TreeNodeValue? left;
  TreeNodeValue? right;
  final int id;

  @override
  ValueType get type => ValueType.treeNode;

  @override
  Object? toJson() => _json(<TreeNodeValue>{});

  Object? _json(Set<TreeNodeValue> seen) {
    if (!seen.add(this)) return '...';
    return {
      'value': value,
      'left': left?._json(seen),
      'right': right?._json(seen),
    };
  }
}

/// Adjacency-list graph with a visited set the VM can mark.
final class GraphValue extends RuntimeValue {
  GraphValue(this.adjacency, {Set<num>? visited, this.id = 0})
      : visited = visited ?? <num>{};
  final Map<num, List<num>> adjacency;
  final Set<num> visited;
  final int id;

  @override
  ValueType get type => ValueType.graph;

  @override
  Object? toJson() => {
        'nodes': {
          for (final e in adjacency.entries) e.key.toString(): e.value,
        },
        'visited': visited.toList(),
      };
}

/// Map and set key for a runtime value, or `null` when the value cannot be a
/// key. Numbers, strings, and booleans compare by value; nothing else does.
Object? primitiveKey(RuntimeValue value) => switch (value) {
      NumValue(:final value) => value,
      StrValue(:final value) => value,
      BoolValue(:final value) => value,
      _ => null,
    };
