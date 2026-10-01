import '../types/parse_type.dart';
import '../types/value_type.dart';
import 'block_graph.dart';
import 'catalog.dart';
import 'ports.dart';

/// One parameter of a player function (L2).
final class FunctionParam {
  const FunctionParam(this.name, this.type);

  final String name;
  final ValueType type;

  @override
  bool operator ==(Object other) => other is FunctionParam && other.name == name && other.type == type;

  @override
  int get hashCode => Object.hash(name, type);
}

/// A function a puzzle asks the player to write (L2): its name, parameters
/// and return type are given; the player builds the body.
///
/// The puzzle declares it (`functions` in the puzzle JSON) and the editor puts
/// a FUNCTION block for it at the top of the program, carrying the signature
/// in its literals, so typing and lowering read it from the graph alone.
final class FunctionSignature {
  const FunctionSignature({required this.name, required this.params, required this.returns});

  /// At most this many parameters (CALL has one block per arity).
  static const maxParams = 3;

  final String name;
  final List<FunctionParam> params;
  final ValueType returns;

  /// `node:treeNode?;depth:num` — `;` because types may hold commas.
  String get paramsLiteral => params.map((p) => '${p.name}:${p.type}').join(';');

  Map<String, Object?> get literals => {'name': name, 'params': paramsLiteral, 'returns': returns.toString()};

  /// The signature a FUNCTION block carries, or null if it is malformed.
  static FunctionSignature? of(BlockInstance block) {
    if (block.catalogId != BlockIds.fnDef) return null;
    final name = block.literals['name'];
    final params = block.literals['params'] ?? '';
    final returns = block.literals['returns'];
    if (name is! String || name.isEmpty || params is! String || returns is! String) return null;
    try {
      return FunctionSignature(
        name: name,
        params: [
          for (final part in params.split(';'))
            if (part.isNotEmpty)
              () {
                final cut = part.indexOf(':');
                if (cut <= 0) throw const FormatException('parameter');
                return FunctionParam(part.substring(0, cut), parseValueType(part.substring(cut + 1)));
              }(),
        ],
        returns: parseValueType(returns),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FunctionSignature &&
      other.name == name &&
      other.returns == returns &&
      other.params.length == params.length &&
      [for (var i = 0; i < params.length; i++) other.params[i] == params[i]].every((same) => same);

  @override
  int get hashCode => Object.hash(name, returns, Object.hashAll(params));
}

/// The functions a graph defines, by name: one per FUNCTION block.
abstract final class FunctionTable {
  static final _cache = Expando<Map<String, FunctionSignature>>();

  static Map<String, FunctionSignature> of(BlockGraph graph) => _cache[graph] ??= {
        for (final sig in graph.blocks.values.map(FunctionSignature.of).nonNulls) sig.name: sig,
      };

  /// The signature a CALL block names, or null.
  static FunctionSignature? called(BlockGraph graph, BlockInstance call) {
    final name = call.literals['name'];
    return name is String ? of(graph)[name] : null;
  }

  /// The FUNCTION block that [blockId] sits in, or null for the main program.
  static BlockInstance? enclosing(BlockGraph graph, String blockId) {
    var id = blockId;
    final seen = <String>{};
    while (id != BlockGraph.mainId && seen.add(id)) {
      final parent = graph.parentOf(id);
      if (parent == null) return null;
      final owner = graph.blocks[parent.blockId];
      if (owner != null && owner.catalogId == BlockIds.fnDef) return owner;
      id = parent.blockId;
    }
    return null;
  }
}

/// Puts the puzzle's functions into a graph: a FUNCTION block per function at
/// the top of the program (in the puzzle's order, before everything else) and
/// its parameters declared as variables. Existing bodies are kept; a changed
/// signature is updated in place. Used when the editor opens a puzzle and by
/// the content tooling's replay, so both build the same graph.
abstract final class FunctionSetup {
  static String idFor(String name) => 'fn_$name';

  static BlockGraph ensure(BlockGraph graph, List<FunctionSignature> functions) {
    if (functions.isEmpty) return graph;
    final blocks = Map<String, BlockInstance>.of(graph.blocks);
    final entries = List<String>.of(graph.entryIds);
    final variables = {
      ...graph.variables,
      for (final f in functions)
        for (final p in f.params) p.name: p.type,
    };
    var at = 0;
    for (final f in functions) {
      final id = idFor(f.name);
      final existing = blocks[id];
      if (existing != null && existing.catalogId == BlockIds.fnDef) {
        if (FunctionSignature.of(existing) != f) {
          blocks[id] = existing.copyWith(literals: f.literals);
        }
        final where = entries.indexOf(id);
        if (where < 0 && graph.parentOf(id) == null) {
          entries.insert(at, id);
          at++;
        } else if (where >= 0) {
          at = where + 1;
        }
        continue;
      }
      blocks[id] = BlockInstance(
        id: id,
        catalogId: BlockIds.fnDef,
        literals: f.literals,
        slots: const {'body': ListBinding([])},
      );
      entries.insert(at, id);
      at++;
    }
    return graph.copyWith(blocks: blocks, entryIds: entries, variables: variables);
  }

  /// Whether [port] on a FUNCTION's body is where its statements go.
  static bool isBody(PortRef port, BlockGraph graph) =>
      port.port == 'body' && graph.blocks[port.blockId]?.catalogId == BlockIds.fnDef;
}
