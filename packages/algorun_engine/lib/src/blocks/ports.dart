import '../types/value_type.dart';

/// How a port participates in the graph. Kind is the first gate: a statement
/// never plugs into an expression hole, regardless of [ValueType].
enum PortKind {
  statement,
  expression,
  elseClause,
}

enum PortDirection { input, output }

enum PortArity { one, many }

/// A named hole or plug on a [BlockDefinition].
final class PortDefinition {
  const PortDefinition({
    required this.name,
    required this.kind,
    required this.direction,
    this.arity = PortArity.one,
    this.type = ValueType.voidType,
  });

  final String name;
  final PortKind kind;
  final PortDirection direction;
  final PortArity arity;

  /// For [PortKind.expression]. Statement / else ports use [ValueType.voidType].
  final ValueType type;

  bool get isInput => direction == PortDirection.input;
  bool get isOutput => direction == PortDirection.output;
  bool get isExpr => kind == PortKind.expression;
  bool get isStmt => kind == PortKind.statement;
}

/// Address of one port on one instance (or [BlockGraph.mainId] for the root).
final class PortRef {
  const PortRef(this.blockId, this.port);

  final String blockId;
  final String port;

  static const mainBody = PortRef(BlockGraphMain.id, 'body');

  @override
  bool operator ==(Object other) =>
      other is PortRef && other.blockId == blockId && other.port == port;

  @override
  int get hashCode => Object.hash(blockId, port);

  @override
  String toString() => '$blockId.$port';
}

/// Synthetic root id for the top-level statement stack (`entryIds`).
abstract final class BlockGraphMain {
  static const id = '@main';
}

/// A directed plug: [from] is an output, [to] is an input.
final class Connection {
  const Connection({
    required this.from,
    required this.to,
    this.index,
  });

  final PortRef from;
  final PortRef to;

  /// Insert index for [PortArity.many] statement lists.
  final int? index;

  @override
  bool operator ==(Object other) =>
      other is Connection &&
      other.from == from &&
      other.to == to &&
      other.index == index;

  @override
  int get hashCode => Object.hash(from, to, index);
}

/// Parent location of a block, if attached.
final class BlockParent {
  const BlockParent({
    required this.blockId,
    required this.port,
    required this.index,
  });

  final String blockId;
  final String port;
  final int index;

  PortRef get portRef => PortRef(blockId, port);
}
