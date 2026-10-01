import '../types/parse_type.dart';
import '../types/value_type.dart';
import 'block_graph.dart';
import 'catalog.dart';
import 'definition.dart';
import 'functions.dart';
import 'narrowing.dart';
import 'ports.dart';

/// Game-facing snap decision. Milestone 3 must call this — never reimplement.
final class ConnectDecision {
  const ConnectDecision._(this.allowed, this.code, this.message);

  const ConnectDecision.allow() : this._(true, null, null);

  const ConnectDecision.deny(String code, String message)
      : this._(false, code, message);

  final bool allowed;
  final String? code;
  final String? message;
}

/// A picker row: a catalog block, optionally bound to a variable name.
final class Placement {
  const Placement({
    required this.catalogId,
    this.literals = const {},
  });

  final String catalogId;
  final Map<String, Object?> literals;
}

/// Single source of truth for port compatibility.
abstract final class GraphTyping {
  /// [from] must be an output, [to] an input.
  ///
  /// Set [allowReparent] when a live drag should detach an already-attached
  /// block and move it (Milestone 3 snap). Tests for duplicate connections
  /// leave it false.
  static ConnectDecision canConnect(
    BlockGraph graph, {
    required PortRef from,
    required PortRef to,
    int? index,
    bool allowReparent = false,
  }) {
    final fromPort = _outputPort(graph, from);
    if (fromPort == null) {
      return const ConnectDecision.deny(
        'wrong_direction',
        'These pieces do not attach that way.',
      );
    }
    final toPort = _inputPort(graph, to);
    if (toPort == null) {
      return const ConnectDecision.deny(
        'wrong_direction',
        'These pieces do not attach that way.',
      );
    }
    if (from.blockId == to.blockId) {
      return const ConnectDecision.deny(
        'cycle',
        'This would loop back on itself.',
      );
    }
    if (fromPort.kind != toPort.kind) {
      return ConnectDecision.deny('wrong_kind', _kindMessage(toPort));
    }
    if (fromPort.direction != PortDirection.output ||
        toPort.direction != PortDirection.input) {
      return const ConnectDecision.deny(
        'wrong_direction',
        'These pieces do not attach that way.',
      );
    }
    if (_wouldCycle(graph, from.blockId, to.blockId)) {
      return const ConnectDecision.deny(
        'cycle',
        'This would loop back on itself.',
      );
    }

    final parent = graph.parentOf(from.blockId);
    if (parent != null) {
      final sameHole = parent.blockId == to.blockId && parent.port == to.port;
      if (sameHole && toPort.arity == PortArity.one) {
        return const ConnectDecision.deny(
          'duplicate',
          'Something is already plugged in here.',
        );
      }
      if (!allowReparent && !sameHole) {
        return const ConnectDecision.deny(
          'already_attached',
          'This block is already attached somewhere else.',
        );
      }
    }

    if (toPort.arity == PortArity.one) {
      final filled = graph.slotList(to.blockId, to.port);
      if (filled.isNotEmpty && filled.first != from.blockId) {
        return const ConnectDecision.deny(
          'duplicate',
          'Something is already plugged in here.',
        );
      }
    } else {
      final list = graph.slotList(to.blockId, to.port);
      if (list.contains(from.blockId)) {
        return const ConnectDecision.deny(
          'duplicate',
          'This block is already in that stack.',
        );
      }
      if (index != null && (index < 0 || index > list.length)) {
        return const ConnectDecision.deny(
          'bad_index',
          'That stack position does not exist.',
        );
      }
    }

    if (fromPort.kind == PortKind.statement) {
      return _statementRules(graph, from, to);
    }
    if (fromPort.kind == PortKind.elseClause) {
      return const ConnectDecision.allow();
    }
    return _expressionRules(graph, from, to, toPort);
  }

  /// Catalog ids (plus GET literals) that [canConnect] would accept on [to].
  ///
  /// The picker must call this. It never invents a second type checker.
  static List<Placement> compatiblePlacements(
    BlockGraph graph, {
    required PortRef to,
    required Iterable<String> allow,
    int? index,
  }) {
    final out = <Placement>[];
    for (final catalogId in allow) {
      final def = BlockCatalog.of(catalogId);
      if (def == null) continue;
      // GET, INCREMENT and DECREMENT name their variable, and the rules
      // depend on it: offer one placement per variable the rules accept
      // (MS13 — INCREMENT / DECREMENT without a name were never accepted, so
      // the picker never offered them).
      if (catalogId == BlockIds.varGet ||
          catalogId == BlockIds.varInc ||
          catalogId == BlockIds.varDec) {
        for (final name in graph.variables.keys) {
          final decision = _previewConnect(
            graph,
            catalogId: catalogId,
            literals: {'name': name},
            to: to,
            index: index,
          );
          if (decision.allowed) {
            out.add(Placement(catalogId: catalogId, literals: {'name': name}));
          }
        }
        continue;
      }
      // CALL names its function (L2): one placement per function with as many
      // parameters as this CALL passes values.
      if (BlockIds.isCall(catalogId)) {
        final arity = BlockIds.callArity(catalogId);
        for (final sig in FunctionTable.of(graph).values) {
          if (sig.params.length != arity) continue;
          final decision = _previewConnect(
            graph,
            catalogId: catalogId,
            literals: {'name': sig.name},
            to: to,
            index: index,
          );
          if (decision.allowed) {
            out.add(Placement(catalogId: catalogId, literals: {'name': sig.name}));
          }
        }
        continue;
      }
      final decision = _previewConnect(
        graph,
        catalogId: catalogId,
        to: to,
        index: index,
      );
      if (decision.allowed) {
        out.add(Placement(catalogId: catalogId));
      }
    }
    return out;
  }

  /// Resolve the effective type of an expression output (for tests / MS3).
  static ValueType? resolveOutput(BlockGraph graph, String blockId) {
    return _outputType(graph, blockId, {});
  }

  /// Resolve the effective type of an expression input hole.
  static ValueType? resolveInput(BlockGraph graph, PortRef to) {
    return _holeType(graph, to);
  }

  /// If exactly one of [a]/[b] is an output, return oriented from→to.
  static Connection? orient(BlockGraph graph, PortRef a, PortRef b) {
    final aOut = _outputPort(graph, a) != null;
    final bOut = _outputPort(graph, b) != null;
    final aIn = _inputPort(graph, a) != null;
    final bIn = _inputPort(graph, b) != null;
    if (aOut && bIn) return Connection(from: a, to: b);
    if (bOut && aIn) return Connection(from: b, to: a);
    return null;
  }
}

ConnectDecision _previewConnect(
  BlockGraph graph, {
  required String catalogId,
  Map<String, Object?> literals = const {},
  required PortRef to,
  int? index,
}) {
  final def = BlockCatalog.of(catalogId);
  if (def == null) {
    return const ConnectDecision.deny('unknown_block', 'Unknown block.');
  }
  final out = def.outputOfKind(PortKind.expression) ??
      def.outputOfKind(PortKind.statement) ??
      def.outputOfKind(PortKind.elseClause);
  if (out == null) {
    return const ConnectDecision.deny(
      'wrong_direction',
      'These pieces do not attach that way.',
    );
  }
  final trialId = graph.allocId('preview');
  final next = Map<String, BlockInstance>.of(graph.blocks);
  next[trialId] = BlockInstance(
    id: trialId,
    catalogId: catalogId,
    literals: literals,
  );
  return GraphTyping.canConnect(
    graph.copyWith(blocks: next),
    from: PortRef(trialId, out.name),
    to: to,
    index: index,
  );
}

PortDefinition? _outputPort(BlockGraph graph, PortRef ref) {
  if (ref.blockId == BlockGraph.mainId) return null;
  final block = graph.blocks[ref.blockId];
  if (block == null) return null;
  final def = BlockCatalog.of(block.catalogId);
  final port = def?.port(ref.port);
  if (port == null || !port.isOutput) return null;
  return port;
}

PortDefinition? _inputPort(BlockGraph graph, PortRef ref) {
  if (ref.blockId == BlockGraph.mainId) {
    if (ref.port != 'body') return null;
    return stmtList('body');
  }
  final block = graph.blocks[ref.blockId];
  if (block == null) return null;
  final def = BlockCatalog.of(block.catalogId);
  final port = def?.port(ref.port);
  if (port == null || !port.isInput) return null;
  return port;
}

ConnectDecision _statementRules(BlockGraph graph, PortRef from, PortRef to) {
  final fromBlock = graph.blocks[from.blockId];
  if (fromBlock == null) {
    return const ConnectDecision.deny('missing_block', 'That block is gone.');
  }
  if (fromBlock.catalogId == BlockIds.ctrlBreak ||
      fromBlock.catalogId == BlockIds.ctrlContinue) {
    if (!_insideLoop(graph, to)) {
      return const ConnectDecision.deny(
        'break_outside_loop',
        'Break and continue only work inside a loop.',
      );
    }
  }
  if (fromBlock.catalogId == BlockIds.varInc ||
      fromBlock.catalogId == BlockIds.varDec) {
    final name = fromBlock.literals['name'] as String?;
    final type = name == null ? null : graph.variables[name];
    if (type == null) {
      return const ConnectDecision.deny(
        'undefined_variable',
        'This variable is not defined.',
      );
    }
    if (type.atom != TypeAtom.number) {
      return const ConnectDecision.deny(
        'type_mismatch',
        'This variable is not a number.',
      );
    }
  }
  return const ConnectDecision.allow();
}

bool _insideLoop(BlockGraph graph, PortRef to) {
  var id = to.blockId;
  if (id == BlockGraph.mainId) return false;
  final seen = <String>{};
  while (id != BlockGraph.mainId) {
    if (!seen.add(id)) return false;
    final cat = graph.blocks[id]?.catalogId;
    if (cat == BlockIds.ctrlWhile ||
        cat == BlockIds.ctrlForRange ||
        cat == BlockIds.ctrlForEach) {
      return true;
    }
    final parent = graph.parentOf(id);
    if (parent == null) return false;
    id = parent.blockId;
  }
  return false;
}

ConnectDecision _expressionRules(
  BlockGraph graph,
  PortRef from,
  PortRef to,
  PortDefinition toPort,
) {
  final hole = _holeType(graph, to);
  if (hole == null) {
    if (_isVarValueHole(graph, to)) {
      return const ConnectDecision.deny(
        'undefined_variable',
        'This variable is not defined.',
      );
    }
    return const ConnectDecision.deny(
      'unknown_port',
      'This piece does not fit here.',
    );
  }
  final plug = _plugType(graph, from.blockId, to);
  if (plug == null) {
    return const ConnectDecision.deny(
      'unknown_port',
      'This piece does not fit here.',
    );
  }
  final env = <String, ValueType>{};
  if (!_bind(hole, plug, env)) {
    return ConnectDecision.deny('type_mismatch', _typeMessage(toPort, hole));
  }
  final hole2 = hole.subst(env);
  final plug2 = plug.subst(env);
  if (!hole2.accepts(plug2)) {
    if (Narrowing.onlyMayBeEmpty(plug2, hole2.accepts)) {
      return const ConnectDecision.deny(
        'may_be_empty',
        Narrowing.mayBeEmptyMessage,
      );
    }
    return ConnectDecision.deny('type_mismatch', _typeMessage(toPort, hole));
  }
  final owner = graph.blocks[to.blockId];
  if (owner != null && BlockIds.isNothingCheck(owner.catalogId)) {
    final problem = Narrowing.checkProblem(plug2);
    if (problem != null) return ConnectDecision.deny('type_mismatch', problem);
  }
  return const ConnectDecision.allow();
}

/// The type [blockId] would have once plugged into [to]. A GET reads its
/// variable as narrowed where the hole is, not where the block sits now.
ValueType? _plugType(BlockGraph graph, String blockId, PortRef to) {
  final block = graph.blocks[blockId];
  if (block != null && block.catalogId == BlockIds.varGet) {
    final name = block.literals['name'];
    if (name is! String) return null;
    final declared = graph.variables[name];
    if (declared == null) return null;
    return Narrowing.read(
      declared,
      name,
      Narrowing.of(graph).atInput(graph, to),
    );
  }
  return _outputType(graph, blockId, {});
}

bool _isVarValueHole(BlockGraph graph, PortRef to) {
  final block = graph.blocks[to.blockId];
  return block != null &&
      block.catalogId == BlockIds.varSet &&
      to.port == 'value';
}

ValueType? _holeType(BlockGraph graph, PortRef to) {
  if (to.blockId == BlockGraph.mainId) return ValueType.voidType;
  final block = graph.blocks[to.blockId];
  if (block == null) return null;
  if (block.catalogId == BlockIds.varSet && to.port == 'value') {
    final name = block.literals['name'] as String?;
    if (name == null) return null;
    return graph.variables[name];
  }
  // A value passed to a function has its parameter's type (L2).
  if (BlockIds.isCall(block.catalogId) && to.port.startsWith('a')) {
    final sig = FunctionTable.called(graph, block);
    final index = int.tryParse(to.port.substring(1));
    if (sig == null || index == null || index < 1 || index > sig.params.length) return null;
    return sig.params[index - 1].type;
  }
  // RETURN inside a FUNCTION gives back that function's type (L2).
  if (block.catalogId == BlockIds.ctrlReturn && to.port == 'value') {
    final fn = FunctionTable.enclosing(graph, block.id);
    final sig = fn == null ? null : FunctionSignature.of(fn);
    if (sig != null) return sig.returns;
  }
  final def = BlockCatalog.of(block.catalogId);
  final port = def?.port(to.port);
  if (port == null) return null;
  if (!port.isExpr) return port.type;
  final env = _infer(graph, to.blockId, {});
  return port.type.subst(env);
}

ValueType? _outputType(
  BlockGraph graph,
  String blockId,
  Set<String> stack,
) {
  final block = graph.blocks[blockId];
  if (block == null) return null;
  if (block.catalogId == BlockIds.varGet) {
    final name = block.literals['name'] as String?;
    if (name == null) return null;
    final declared = graph.variables[name];
    if (declared == null) return null;
    return Narrowing.read(declared, name, Narrowing.of(graph).at(blockId));
  }
  if (BlockIds.isCall(block.catalogId)) {
    return FunctionTable.called(graph, block)?.returns;
  }
  if (block.catalogId == BlockIds.newArray) {
    final of = block.literals['of'] as String?;
    if (of != null) {
      try {
        return ValueType.array(parseValueType(of));
      } catch (_) {
        return ValueType.array(ValueType.t);
      }
    }
  }
  final def = BlockCatalog.of(block.catalogId);
  final out = def?.outputOfKind(PortKind.expression);
  if (out == null) return null;
  final env = _infer(graph, blockId, stack);
  return out.type.subst(env);
}

Map<String, ValueType> _infer(
  BlockGraph graph,
  String blockId,
  Set<String> stack,
) {
  if (!stack.add(blockId)) return {};
  final block = graph.blocks[blockId];
  if (block == null) return {};
  final def = BlockCatalog.of(block.catalogId);
  if (def == null) return {};
  final env = <String, ValueType>{};
  for (final port in def.inputs) {
    if (!port.isExpr) continue;
    final slot = block.slots[port.name];
    if (slot is! RefBinding) continue;
    final child = _outputType(graph, slot.blockId, stack);
    if (child == null) continue;
    _bind(port.type, child, env);
  }
  return env;
}

bool _bind(ValueType a, ValueType b, Map<String, ValueType> env) {
  a = a.subst(env);
  b = b.subst(env);
  if (a.atom == TypeAtom.generic) {
    final name = a.genericName;
    if (name == null) return false;
    final existing = env[name];
    if (existing != null) {
      return existing == b || existing.accepts(b);
    }
    env[name] = b;
    return true;
  }
  if (b.atom == TypeAtom.generic) {
    final name = b.genericName;
    if (name == null) return false;
    final existing = env[name];
    if (existing != null) {
      return existing == a || a.accepts(existing);
    }
    env[name] = a;
    return true;
  }
  if (b.atom == TypeAtom.nil) {
    return true;
  }
  if (a.atom != b.atom) return false;
  if (a.param != null && b.param != null) {
    if (!_bind(a.param!, b.param!, env)) return false;
  }
  if (a.param2 != null && b.param2 != null) {
    if (!_bind(a.param2!, b.param2!, env)) return false;
  }
  return true;
}

bool _wouldCycle(BlockGraph graph, String movingId, String targetId) {
  if (targetId == BlockGraph.mainId) return false;
  var id = targetId;
  final seen = <String>{};
  while (true) {
    if (id == movingId) return true;
    if (!seen.add(id)) return false;
    final parent = graph.parentOf(id);
    if (parent == null) return false;
    id = parent.blockId;
    if (id == BlockGraph.mainId) return false;
  }
}

String _kindMessage(PortDefinition hole) {
  return switch (hole.kind) {
    PortKind.expression => 'This spot needs a value, not a full instruction.',
    PortKind.statement => 'This spot needs an instruction, not a value.',
    PortKind.elseClause => 'Only an else branch fits here.',
  };
}

String _typeMessage(PortDefinition hole, ValueType type) {
  return switch (hole.name) {
    'condition' => 'This block needs a condition.',
    'index' || 'i' || 'j' || 'start' || 'end' || 'step' =>
      'This block needs a number.',
    'array' => 'This block needs a list.',
    'map' => 'This block needs a map.',
    'set' => 'This block needs a set.',
    'stack' => 'This block needs a stack.',
    'queue' => 'This block needs a queue.',
    _ => switch (type.atom) {
        TypeAtom.boolean => 'This block needs a condition.',
        TypeAtom.number => 'This block needs a number.',
        TypeAtom.array => 'This block needs a list.',
        _ => 'This piece does not fit here.',
      },
  };
}
