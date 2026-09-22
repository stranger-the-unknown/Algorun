import '../types/value_type.dart';
import 'ports.dart';

enum BlockRole {
  statement,
  expression,
  elseClause,
}

/// Closed description of a catalog block. Instances never invent extra ports.
final class BlockDefinition {
  const BlockDefinition({
    required this.id,
    required this.role,
    required this.ports,
    this.typeParams = const [],
  });

  final String id;
  final BlockRole role;
  final List<String> typeParams;
  final List<PortDefinition> ports;

  PortDefinition? port(String name) {
    for (final p in ports) {
      if (p.name == name) return p;
    }
    return null;
  }

  Iterable<PortDefinition> get inputs => ports.where((p) => p.isInput);

  Iterable<PortDefinition> get outputs => ports.where((p) => p.isOutput);

  PortDefinition? outputOfKind(PortKind kind) {
    for (final p in ports) {
      if (p.isOutput && p.kind == kind) return p;
    }
    return null;
  }
}

PortDefinition exprOut(ValueType type) => PortDefinition(
      name: 'out',
      kind: PortKind.expression,
      direction: PortDirection.output,
      type: type,
    );

PortDefinition exprIn(String name, ValueType type) => PortDefinition(
      name: name,
      kind: PortKind.expression,
      direction: PortDirection.input,
      type: type,
    );

const stmtOut = PortDefinition(
  name: 'stmt',
  kind: PortKind.statement,
  direction: PortDirection.output,
);

PortDefinition stmtList(String name) => PortDefinition(
      name: name,
      kind: PortKind.statement,
      direction: PortDirection.input,
      arity: PortArity.many,
    );

const elseOut = PortDefinition(
  name: 'clause',
  kind: PortKind.elseClause,
  direction: PortDirection.output,
);

const elseIn = PortDefinition(
  name: 'else',
  kind: PortKind.elseClause,
  direction: PortDirection.input,
);

BlockDefinition stackBlock(String id, List<PortDefinition> extra) =>
    BlockDefinition(
      id: id,
      role: BlockRole.statement,
      ports: [stmtOut, ...extra],
    );

BlockDefinition reporter(
  String id,
  ValueType out,
  List<PortDefinition> inputs, {
  List<String> typeParams = const [],
}) =>
    BlockDefinition(
      id: id,
      role: BlockRole.expression,
      typeParams: typeParams,
      ports: [exprOut(out), ...inputs],
    );
