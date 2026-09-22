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
