import '../types/value_type.dart';
import 'block_graph.dart';
import 'catalog.dart';
import 'ports.dart';

/// Where a variable that may be empty is known to hold something (L1).
///
/// A variable of a type that may be empty (`listNode?`, `treeNode?`, `num?`)
/// reads as its plain type — it is *narrowed* — only where a check on that
/// very variable proved it is not empty:
///
/// - `IF x IS NOT NOTHING`: in THEN;
/// - `IF x IS NOTHING`: in ELSE;
/// - `WHILE x IS NOT NOTHING`: in the body, until the body writes `x`;
/// - `A AND B`: B sees what A proved, and THEN / the loop body see what both
///   proved (AND stops at a false A, so B never runs unproven).
///
/// Nothing else narrows. OR, NOT, EQUAL NOTHING and the ELSE of IS NOT NOTHING
/// prove nothing. Only a plain variable is narrowed: `LEFT x IS NOT NOTHING`
/// says nothing about a later `LEFT x`. No fact outlives the branch or loop
/// that proved it — after the IF or the loop the variable may be empty again.
///
/// A statement that writes a variable (SET, INCREMENT, DECREMENT, SWAP, COPY,
/// a FOR / FOR EACH counter) ends its narrowing for the rest of that flow; the
/// new value is not inspected, it has to be checked again. A loop keeps a fact
/// from outside only if nothing in the loop writes that variable, so every
/// iteration is as safe as the first.
///
/// This is the one implementation. `GraphTyping` reads it for the editor
/// (picker and snap), the lowerer reads it before a program can run, so the
/// phone and RUN always agree. The runtime never narrows: IS NOTHING is a
/// real check on the value.
final class Narrowing {
  Narrowing._(this._at);

  static final _cache = Expando<Narrowing>();

  /// Narrowing for [graph]. A graph is a value (every edit makes a new one),
  /// so the walk runs once per graph.
  static Narrowing of(BlockGraph graph) =>
      _cache[graph] ??= _Walk(graph).run();

  /// The game's words for a value that may be empty where it must not be.
  static const mayBeEmptyMessage =
      'This value may be empty here. Check that it is not empty first.';

  final Map<String, Set<String>> _at;

  /// Variables known to hold something where block [blockId] is evaluated
  /// (for a statement: its own value holes; for WHILE: its condition). Empty
  /// for a block that is not attached to the program.
  Set<String> at(String blockId) => _at[blockId] ?? const {};

  /// Variables known to hold something in the value hole [to] — where a block
  /// dropped into that hole would be evaluated.
  Set<String> atInput(BlockGraph graph, PortRef to) {
    final base = at(to.blockId);
    if (to.port == 'right' &&
        graph.blocks[to.blockId]?.catalogId == BlockIds.logicAnd) {
      return {...base, ..._whenTrue(graph, _single(graph, to.blockId, 'left'))};
    }
    return base;
  }

  /// [declared] as read by a GET of [name] where [facts] hold.
  static ValueType read(ValueType declared, String name, Set<String> facts) =>
      facts.contains(name) ? declared.asNonNullable : declared;

  /// Why [value] cannot go into IS NOTHING / IS NOT NOTHING, or null when it
  /// can. Only a value that may be empty can be checked; an unfinished
  /// generic block is decided once its type is known.
  static String? checkProblem(ValueType value) {
    if (value.atom == TypeAtom.nil) {
      return 'Check a value that may be empty, not NOTHING itself.';
    }
    if (value.isGeneric && !value.nullable) return null;
    if (!value.nullable) {
      return 'This value is never empty here, so there is nothing to check.';
    }
    return null;
  }

  /// Whether [plug] fails [accepts] only because it may be empty.
  static bool onlyMayBeEmpty(
    ValueType plug,
    bool Function(ValueType) accepts,
  ) =>
      plug.nullable && plug.atom != TypeAtom.nil && accepts(plug.asNonNullable);
}

String? _single(BlockGraph graph, String blockId, String port) {
  final ids = graph.slotList(blockId, port);
  return ids.isEmpty ? null : ids.first;
}

/// Variables proven to hold something when condition [id] is true.
Set<String> _whenTrue(BlockGraph graph, String? id, [Set<String>? seen]) {
  if (id == null) return const {};
  final block = graph.blocks[id];
  if (block == null || !(seen ??= {}).add(id)) return const {};
  return switch (block.catalogId) {
    BlockIds.logicIsNotNothing => _checked(graph, id),
    BlockIds.logicAnd => {
        ..._whenTrue(graph, _single(graph, id, 'left'), seen),
        ..._whenTrue(graph, _single(graph, id, 'right'), seen),
      },
    _ => const {},
  };
}

/// Variables proven to hold something when condition [id] is false.
Set<String> _whenFalse(BlockGraph graph, String? id) {
  if (id == null) return const {};
  final block = graph.blocks[id];
  if (block == null || block.catalogId != BlockIds.logicIsNothing) {
    return const {};
  }
  return _checked(graph, id);
}

/// The variable an IS (NOT) NOTHING block checks, when it checks a plain GET.
Set<String> _checked(BlockGraph graph, String checkId) {
  final valueId = _single(graph, checkId, 'value');
  final value = valueId == null ? null : graph.blocks[valueId];
  if (value == null || value.catalogId != BlockIds.varGet) return const {};
  final name = value.literals['name'];
  return name is String && name.isNotEmpty ? {name} : const {};
}

/// Names a statement block writes itself.
Set<String> _writes(BlockInstance block) {
  final keys = switch (block.catalogId) {
    BlockIds.varSet ||
    BlockIds.varInc ||
    BlockIds.varDec ||
    BlockIds.varCopy ||
    BlockIds.ctrlForRange ||
    BlockIds.ctrlForEach =>
      const ['name'],
    BlockIds.varSwap => const ['name', 'other', 'b'],
    _ => const <String>[],
  };
  return {
    for (final key in keys)
      if (block.literals[key] case final String name) name,
  };
}

final class _Walk {
  _Walk(this.graph);

  final BlockGraph graph;
  final _at = <String, Set<String>>{};
  final _seen = <String>{};

  Narrowing run() {
    _list(graph.entryIds, const {});
    return Narrowing._(_at);
  }

  Set<String> _list(List<String> ids, Set<String> facts) {
    for (final id in ids) {
      facts = _stmt(id, facts);
    }
    return facts;
  }

  /// Facts after statement [id], given [facts] before it.
  Set<String> _stmt(String id, Set<String> facts) {
    final block = graph.blocks[id];
    // A missing or doubly placed block is reported by structure validation.
    if (block == null || !_seen.add(id)) return facts;
    final after = facts.difference(_written(id));
    switch (block.catalogId) {
      case BlockIds.ctrlIf:
        _at[id] = facts;
        final cond = _single(graph, id, 'condition');
        if (cond != null) _expr(cond, facts);
        _list(graph.slotList(id, 'then'), {...facts, ..._whenTrue(graph, cond)});
        final elseId = _single(graph, id, 'else');
        if (elseId != null && graph.blocks[elseId] != null && _seen.add(elseId)) {
          _at[elseId] = facts;
          _list(
            graph.slotList(elseId, 'body'),
            {...facts, ..._whenFalse(graph, cond)},
          );
        }
      case BlockIds.ctrlWhile:
        // The condition runs before every iteration: only facts the body
        // cannot break hold there, on the first iteration and every later one.
        _at[id] = after;
        final cond = _single(graph, id, 'condition');
        if (cond != null) _expr(cond, after);
        _list(graph.slotList(id, 'body'), {...after, ..._whenTrue(graph, cond)});
      case BlockIds.ctrlForRange || BlockIds.ctrlForEach:
        // Bounds and the collection are read once, before the loop.
        _at[id] = facts;
        _inputs(block, facts);
        _list(graph.slotList(id, 'body'), after);
      default:
        _at[id] = facts;
        _inputs(block, facts);
        // Any other instruction list (FUNCTION is unsupported) proves nothing.
        final def = BlockCatalog.of(block.catalogId);
        for (final port in def?.inputs ?? const <PortDefinition>[]) {
          if (port.isStmt) _list(graph.slotList(id, port.name), const {});
        }
    }
    return after;
  }

  void _expr(String id, Set<String> facts) {
    final block = graph.blocks[id];
    if (block == null || !_seen.add(id)) return;
    _at[id] = facts;
    if (block.catalogId == BlockIds.logicAnd) {
      final left = _single(graph, id, 'left');
      final right = _single(graph, id, 'right');
      if (left != null) _expr(left, facts);
      if (right != null) _expr(right, {...facts, ..._whenTrue(graph, left)});
      return;
    }
    _inputs(block, facts);
  }

  void _inputs(BlockInstance block, Set<String> facts) {
    final def = BlockCatalog.of(block.catalogId);
    if (def == null) return;
    for (final port in def.inputs) {
      if (!port.isExpr) continue;
      for (final child in graph.slotList(block.id, port.name)) {
        _expr(child, facts);
      }
    }
  }

  /// Every name written anywhere in statement [id], its branches and bodies.
  Set<String> _written(String id) {
    final out = <String>{};
    final seen = <String>{};
    void visit(String blockId) {
      if (!seen.add(blockId)) return;
      final block = graph.blocks[blockId];
      if (block == null) return;
      out.addAll(_writes(block));
      for (final slot in block.slots.values) {
        switch (slot) {
          case RefBinding(:final blockId):
            visit(blockId);
          case ListBinding(:final blockIds):
            blockIds.forEach(visit);
        }
      }
    }

    visit(id);
    return out;
  }
}
