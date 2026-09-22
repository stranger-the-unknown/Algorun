import '../runtime/runtime_value.dart';

/// Named output comparators. JSON must never embed executable predicates.
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
  };
}

bool unorderedArrayEqual(RuntimeValue a, RuntimeValue b) {
  if (a is! ArrayValue || b is! ArrayValue) return valuesEqual(a, b);
  if (a.elements.length != b.elements.length) return false;
  final used = List<bool>.filled(b.elements.length, false);
  for (final item in a.elements) {
    var found = false;
    for (var i = 0; i < b.elements.length; i++) {
      if (!used[i] && valuesEqual(item, b.elements[i])) {
        used[i] = true;
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}

bool compareOutputs(ValidatorId id, RuntimeValue actual, RuntimeValue expected) {
  return switch (id) {
    ValidatorId.equal ||
    ValidatorId.listEqualByValue ||
    ValidatorId.treeEqual =>
      valuesEqual(actual, expected),
    ValidatorId.unorderedArray ||
    ValidatorId.setEqual ||
    ValidatorId.unorderedPairs =>
      unorderedArrayEqual(actual, expected),
  };
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
