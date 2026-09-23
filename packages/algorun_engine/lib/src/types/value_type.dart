/// Closed type system for the block language.
///
/// There is no player-facing `any`. Implicit `num` → `bool` conversion is
/// forbidden: an `if` hole only accepts [ValueType.boolean].
enum TypeAtom {
  voidType,
  number,
  boolean,
  string,
  nil,
  array,
  map,
  set,
  stack,
  queue,
  deque,
  heap,
  listNode,
  treeNode,
  graph,
  pair,
  generic,
}

/// A typed port / value sort.
///
/// Generics: `array<num>` uses [param]; `map<str,num>` uses [param] and
/// [param2]; `pair<T,U>` likewise. Unbound parameters use [TypeAtom.generic]
/// with [genericName] (`T`, `K`, `V`).
final class ValueType {
  const ValueType(
    this.atom, {
    this.param,
    this.param2,
    this.nullable = false,
    this.genericName,
  });

  final TypeAtom atom;
  final ValueType? param;
  final ValueType? param2;
  final bool nullable;
  final String? genericName;

  static const voidType = ValueType(TypeAtom.voidType);
  static const number = ValueType(TypeAtom.number);
  static const boolean = ValueType(TypeAtom.boolean);
  static const string = ValueType(TypeAtom.string);
  static const nil = ValueType(TypeAtom.nil);
  static const listNode = ValueType(TypeAtom.listNode);
  static const treeNode = ValueType(TypeAtom.treeNode);
  static const graph = ValueType(TypeAtom.graph);

  static const t = ValueType(TypeAtom.generic, genericName: 'T');
  static const k = ValueType(TypeAtom.generic, genericName: 'K');
  static const v = ValueType(TypeAtom.generic, genericName: 'V');

  static ValueType generic(String name, {bool nullable = false}) =>
      ValueType(TypeAtom.generic, genericName: name, nullable: nullable);

  static ValueType array(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.array, param: element, nullable: nullable);

  static ValueType mapOf(
    ValueType key,
    ValueType value, {
    bool nullable = false,
  }) =>
      ValueType(TypeAtom.map, param: key, param2: value, nullable: nullable);

  static ValueType setOf(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.set, param: element, nullable: nullable);

  static ValueType stackOf(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.stack, param: element, nullable: nullable);

  static ValueType queueOf(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.queue, param: element, nullable: nullable);

  static ValueType dequeOf(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.deque, param: element, nullable: nullable);

  static ValueType heapOf(ValueType element, {bool nullable = false}) =>
      ValueType(TypeAtom.heap, param: element, nullable: nullable);

  static ValueType pairOf(
    ValueType a,
    ValueType b, {
    bool nullable = false,
  }) =>
      ValueType(TypeAtom.pair, param: a, param2: b, nullable: nullable);

  bool get isGeneric => atom == TypeAtom.generic;

  ValueType get asNullable => nullable
      ? this
      : ValueType(
          atom,
          param: param,
          param2: param2,
          nullable: true,
          genericName: genericName,
        );

  /// The same type without NOTHING: what a value that may be empty is known to
  /// hold once a check proved it is not empty (L1 narrowing).
  ValueType get asNonNullable => nullable
      ? ValueType(
          atom,
          param: param,
          param2: param2,
          genericName: genericName,
        )
      : this;

  ValueType subst(Map<String, ValueType> env) {
    if (atom == TypeAtom.generic) {
      final hit = env[genericName];
      if (hit == null) return this;
      return nullable ? hit.asNullable : hit;
    }
    return ValueType(
      atom,
      param: param?.subst(env),
      param2: param2?.subst(env),
      nullable: nullable,
    );
  }

  /// Whether a value of [other] may be dropped into a hole of this type.
  bool accepts(ValueType other) {
    if (atom == TypeAtom.generic || other.atom == TypeAtom.generic) {
      return atom == TypeAtom.generic &&
          other.atom == TypeAtom.generic &&
          genericName == other.genericName &&
          (nullable || !other.nullable);
    }
    if (atom == TypeAtom.voidType) {
      return other.atom == TypeAtom.voidType;
    }
    if (other.atom == TypeAtom.nil) {
      return nullable;
    }
    if (atom != other.atom) return false;
    if (!nullable && other.nullable) return false;
    if (param != null) {
      final op = other.param;
      if (op == null) return false;
      if (!param!.accepts(op)) return false;
    }
    if (param2 != null) {
      final op2 = other.param2;
      if (op2 == null) return false;
      if (!param2!.accepts(op2)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ValueType &&
      other.atom == atom &&
      other.param == param &&
      other.param2 == param2 &&
      other.nullable == nullable &&
      other.genericName == genericName;

  @override
  int get hashCode => Object.hash(atom, param, param2, nullable, genericName);

  @override
  String toString() {
    if (atom == TypeAtom.generic) {
      return nullable ? '$genericName?' : (genericName ?? 'T');
    }
    final name = _atomName(atom);
    String core;
    if (param != null && param2 != null) {
      core = '$name<$param,$param2>';
    } else if (param != null) {
      core = '$name<$param>';
    } else {
      core = name;
    }
    return nullable ? '$core?' : core;
  }

  static String _atomName(TypeAtom atom) {
    return switch (atom) {
      TypeAtom.voidType => 'void',
      TypeAtom.number => 'num',
      TypeAtom.boolean => 'bool',
      TypeAtom.string => 'str',
      TypeAtom.nil => 'null',
      TypeAtom.array => 'array',
      TypeAtom.map => 'map',
      TypeAtom.set => 'set',
      TypeAtom.stack => 'stack',
      TypeAtom.queue => 'queue',
      TypeAtom.deque => 'deque',
      TypeAtom.heap => 'heap',
      TypeAtom.listNode => 'listNode',
      TypeAtom.treeNode => 'treeNode',
      TypeAtom.graph => 'graph',
      TypeAtom.pair => 'pair',
      TypeAtom.generic => 'T',
    };
  }
}
