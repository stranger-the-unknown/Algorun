import '../types/value_type.dart';
import 'block_graph.dart';
import 'catalog.dart';
import 'ports.dart';
import 'typing.dart';

final class GraphMutationResult {
  const GraphMutationResult({
    required this.graph,
    required this.decision,
  });

  factory GraphMutationResult.ok(BlockGraph graph) => GraphMutationResult(
        graph: graph,
        decision: const ConnectDecision.allow(),
      );

  factory GraphMutationResult.denied(BlockGraph graph, ConnectDecision decision) =>
      GraphMutationResult(graph: graph, decision: decision);

  final BlockGraph graph;
  final ConnectDecision decision;
  bool get ok => decision.allowed;
}

/// Reversible mutation. [execute] records enough to [undo].
abstract class GraphCommand {
  GraphMutationResult execute(BlockGraph graph);
  BlockGraph undo(BlockGraph graph);
}

final class GraphHistory {
  GraphHistory([BlockGraph initial = BlockGraph.empty]) : _current = initial;

  BlockGraph _current;
  final List<GraphCommand> _undo = [];
  final List<GraphCommand> _redo = [];

  BlockGraph get current => _current;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Treat the current graph as the starting point (clears undo/redo).
  void markBaseline() {
    _undo.clear();
    _redo.clear();
  }

  void forgetRedo() {
    _redo.clear();
  }

  GraphMutationResult apply(GraphCommand command) {
    final result = command.execute(_current);
    if (!result.ok) return result;
    _current = result.graph;
    _undo.add(command);
    _redo.clear();
    return result;
  }

  BlockGraph undo() {
    if (_undo.isEmpty) return _current;
    final cmd = _undo.removeLast();
    _current = cmd.undo(_current);
    _redo.add(cmd);
    return _current;
  }

  BlockGraph redo() {
    if (_redo.isEmpty) return _current;
    final cmd = _redo.removeLast();
    final result = cmd.execute(_current);
    if (!result.ok) return _current;
    _current = result.graph;
    _undo.add(cmd);
    return _current;
  }
}

final class AddBlockCommand implements GraphCommand {
  AddBlockCommand({
    required this.catalogId,
    this.id,
    this.literals = const {},
    this.x = 0,
    this.y = 0,
  });

  final String catalogId;
  final String? id;
  final Map<String, Object?> literals;
  final double x;
  final double y;
  String? _addedId;

  String? get addedId => _addedId;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    if (!BlockIds.exists(catalogId)) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('unknown_block', 'Unknown block.'),
      );
    }
    final newId = id ?? _addedId ?? graph.allocId();
    if (graph.blocks.containsKey(newId)) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('duplicate', 'That block already exists.'),
      );
    }
    _addedId = newId;
    final next = Map<String, BlockInstance>.of(graph.blocks);
    next[newId] = BlockInstance(
      id: newId,
      catalogId: catalogId,
      literals: literals,
      x: x,
      y: y,
    );
    return GraphMutationResult.ok(graph.copyWith(blocks: next));
  }

  @override
  BlockGraph undo(BlockGraph graph) {
    final id = _addedId;
    if (id == null) return graph;
    return graph.removeBlock(id);
  }
}

final class RemoveBlockCommand implements GraphCommand {
  RemoveBlockCommand(this.blockId);

  final String blockId;
  BlockGraph? _before;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    if (!graph.blocks.containsKey(blockId)) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('missing_block', 'That block is gone.'),
      );
    }
    _before = graph;
    return GraphMutationResult.ok(graph.removeBlock(blockId));
  }

  @override
  BlockGraph undo(BlockGraph graph) => _before ?? graph;
}

final class MoveBlockCommand implements GraphCommand {
  MoveBlockCommand(this.blockId, {required this.x, required this.y});

  final String blockId;
  final double x;
  final double y;
  double? _oldX;
  double? _oldY;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    final block = graph.blocks[blockId];
    if (block == null) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('missing_block', 'That block is gone.'),
      );
    }
    _oldX = block.x;
    _oldY = block.y;
    return GraphMutationResult.ok(
      graph.replaceBlock(block.copyWith(x: x, y: y)),
    );
  }

  @override
  BlockGraph undo(BlockGraph graph) {
    final block = graph.blocks[blockId];
    if (block == null || _oldX == null || _oldY == null) return graph;
    return graph.replaceBlock(block.copyWith(x: _oldX, y: _oldY));
  }
}

final class ConnectCommand implements GraphCommand {
  ConnectCommand({
    required this.from,
    required this.to,
    this.index,
    this.allowReparent = false,
  });

  final PortRef from;
  final PortRef to;
  final int? index;
  final bool allowReparent;
  BlockGraph? _before;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    final decision = GraphTyping.canConnect(
      graph,
      from: from,
      to: to,
      index: index,
      allowReparent: allowReparent,
    );
    if (!decision.allowed) {
      return GraphMutationResult.denied(graph, decision);
    }
    _before = graph;
    var next = graph;
    if (allowReparent) {
      next = next.detach(from.blockId);
    }
    return GraphMutationResult.ok(_apply(next, from, to, index));
  }

  @override
  BlockGraph undo(BlockGraph graph) => _before ?? graph;
}

final class DisconnectCommand implements GraphCommand {
  DisconnectCommand(this.blockId);

  final String blockId;
  BlockGraph? _before;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    if (graph.parentOf(blockId) == null) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny(
          'not_attached',
          'This block is not attached.',
        ),
      );
    }
    _before = graph;
    return GraphMutationResult.ok(graph.detach(blockId));
  }

  @override
  BlockGraph undo(BlockGraph graph) => _before ?? graph;
}

final class AttachStatementCommand extends ConnectCommand {
  AttachStatementCommand({
    required String blockId,
    required super.to,
    super.index,
    super.allowReparent,
  }) : super(from: PortRef(blockId, 'stmt'));
}

final class DetachStatementCommand extends DisconnectCommand {
  DetachStatementCommand(super.blockId);
}

final class DeclareVariableCommand implements GraphCommand {
  DeclareVariableCommand({required this.name, required this.type});

  final String name;
  final ValueType type;
  Map<String, ValueType>? _before;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    if (name.isEmpty) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny(
          'undefined_variable',
          'This variable is not defined.',
        ),
      );
    }
    if (graph.variables.containsKey(name)) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('duplicate', 'That name is already in use.'),
      );
    }
    _before = Map<String, ValueType>.of(graph.variables);
    final next = Map<String, ValueType>.of(graph.variables);
    next[name] = type;
    return GraphMutationResult.ok(graph.copyWith(variables: next));
  }

  @override
  BlockGraph undo(BlockGraph graph) {
    if (_before == null) return graph;
    return graph.copyWith(variables: _before);
  }
}

final class SetLiteralsCommand implements GraphCommand {
  SetLiteralsCommand(this.blockId, this.literals);

  final String blockId;
  final Map<String, Object?> literals;
  Map<String, Object?>? _before;

  @override
  GraphMutationResult execute(BlockGraph graph) {
    final block = graph.blocks[blockId];
    if (block == null) {
      return GraphMutationResult.denied(
        graph,
        const ConnectDecision.deny('missing_block', 'That block is gone.'),
      );
    }
    _before = Map<String, Object?>.of(block.literals);
    final next = Map<String, Object?>.of(block.literals)..addAll(literals);
    return GraphMutationResult.ok(
      graph.replaceBlock(block.copyWith(literals: next)),
    );
  }

  @override
  BlockGraph undo(BlockGraph graph) {
    final block = graph.blocks[blockId];
    if (block == null || _before == null) return graph;
    return graph.replaceBlock(block.copyWith(literals: _before));
  }
}

BlockGraph _apply(BlockGraph graph, PortRef from, PortRef to, int? index) {
  if (to.blockId == BlockGraph.mainId) {
    final list = List<String>.of(graph.entryIds);
    list.remove(from.blockId);
    final i = index ?? list.length;
    final clamped = i < 0 ? 0 : (i > list.length ? list.length : i);
    list.insert(clamped, from.blockId);
    return graph.copyWith(entryIds: list);
  }
  final target = graph.blocks[to.blockId]!;
  final def = BlockCatalog.of(target.catalogId)!;
  final port = def.port(to.port)!;
  final slots = Map<String, SlotBinding>.of(target.slots);
  if (port.kind == PortKind.expression) {
    slots[to.port] = RefBinding(from.blockId);
  } else if (port.arity == PortArity.one) {
    slots[to.port] = ListBinding([from.blockId]);
  } else {
    final existing = slots[to.port];
    final ids = [
      if (existing is ListBinding) ...existing.blockIds,
    ]..remove(from.blockId);
    final i = index ?? ids.length;
    final clamped = i < 0 ? 0 : (i > ids.length ? ids.length : i);
    ids.insert(clamped, from.blockId);
    slots[to.port] = ListBinding(ids);
  }
  return graph.replaceBlock(target.copyWith(slots: slots));
}
