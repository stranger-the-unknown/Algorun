import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/foundation.dart';

import '../l10n/engine_text.dart';
import '../l10n/l10n.dart';
import '../l10n/terms.dart';

/// Feedback from the last edit. The controller does not know the player's
/// language: the screen renders the notice with its strings.
final class EditorNotice {
  const EditorNotice(this.render);

  /// A message from the engine (a refused connection), in its English.
  factory EditorNotice.engine(String? message) =>
      EditorNotice((l) => message == null ? l.noticePieceDoesNotFit : engineText(message, l));

  final String Function(AppLocalizations l) render;

  @override
  String toString() => render(englishStrings);
}

/// Where a selected instruction can move (MS13). Every move is the engine's
/// own detach + attach, so `GraphTyping.canConnect` decides whether the new
/// place is allowed.
enum MoveDirection {
  /// One place earlier in the same list.
  up,

  /// One place later in the same list.
  down,

  /// Out of the block that holds it, just after that block.
  out,

  /// Into the block just above it, at the end of its body.
  into,
}

/// What the selection bar shows about the selected block.
final class SelectionInfo {
  const SelectionInfo({
    required this.blockId,
    required this.label,
    required this.size,
    required this.isStatement,
    required this.canDuplicate,
    required this.moves,
  });

  final String blockId;

  /// Player words (`WHILE`, `GET ELEMENT`, a variable's name).
  final String label;

  /// Blocks removed by a delete: the block and everything inside it.
  final int size;
  final bool isStatement;
  final bool canDuplicate;
  final Set<MoveDirection> moves;
}

/// Owns [GraphHistory]. Pointer / sheet UI does not go through Riverpod.
final class EditorController extends ChangeNotifier {
  /// [initialGraph] restores a saved program; the puzzle's givens and its
  /// variable pool are always declared with their current types on top of it.
  /// Blocks that are not part of the program (left behind by an older
  /// editor's delete) are dropped: nothing ever ran them, they only counted
  /// against the block budget. Folded C-blocks in it stay folded.
  ///
  /// Every name a player can use comes from the puzzle (givens and
  /// `variables.pool`); there is no free naming. So all of them are declared
  /// from the start (U1) instead of being "created" one by one. Declaring is
  /// only a type for the lowering: no block, no step, no memory.
  EditorController({
    required this.puzzle,
    bool seedExample = false,
    BlockGraph? initialGraph,
  }) : _history = GraphHistory(
          initialGraph == null
              ? BlockGraph(blocks: const {}, variables: _names(puzzle))
              : withoutStrays(initialGraph).copyWith(
                  variables: {...initialGraph.variables, ..._names(puzzle)},
                ),
        ) {
    collapsedIds.addAll(_foldsOf(graph));
    if (seedExample && initialGraph == null) {
      seedWorkingExample();
      markBaseline();
    }
  }

  /// The pool, then the givens: every name the puzzle provides.
  static Map<String, ValueType> _names(Puzzle puzzle) => {
        for (final v in puzzle.variablePool) v.name: v.type,
        for (final input in puzzle.io.inputs) input.name: input.type,
      };

  final Puzzle puzzle;
  final GraphHistory _history;

  PortRef? activeHole;
  String? selectedBlockId;
  EditorNotice? flash;

  /// Folded C-blocks. UI state: never an undo step, saved with the draft.
  final Set<String> collapsedIds = {};

  /// Bumped on every fold change, so autosave can notice one.
  int foldsVersion = 0;

  /// A block the script should scroll into view once it is built.
  String? revealId;

  BlockGraph get graph => _history.current;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// What the block budget counts: every block in the program.
  int get blockCount => graph.blockCount;

  /// Treat the current program as the starting point (clears undo / redo).
  void markBaseline() => _history.markBaseline();

  List<String> get paletteIds => [
        for (final id in puzzle.blocks.allow)
          if (!BlockChrome.hiddenFromEditor(id)) id,
      ];

  List<IoBinding> get givens => puzzle.io.inputs;

  /// The puzzle's working variables (`variables.pool`), declared from the
  /// start.
  List<IoBinding> get poolVariables => puzzle.variablePool;

  List<IoBinding> get unusedPool => [
        for (final v in puzzle.variablePool)
          if (!graph.variables.containsKey(v.name)) v,
      ];

  List<Placement> placementsFor(PortRef hole, {int? index}) {
    return GraphTyping.compatiblePlacements(
      graph,
      to: hole,
      allow: paletteIds,
      index: index,
    );
  }

  void showFlash(EditorNotice notice) {
    flash = notice;
    notifyListeners();
  }

  void dismissFlash() {
    if (flash == null) return;
    flash = null;
    notifyListeners();
  }

  void selectHole(PortRef? hole) {
    activeHole = hole;
    selectedBlockId = null;
    notifyListeners();
  }

  void selectBlock(String? id) {
    selectedBlockId = id;
    activeHole = null;
    notifyListeners();
  }

  void clearSelection() {
    if (activeHole == null && selectedBlockId == null) return;
    _clearSelection();
    notifyListeners();
  }

  // ---- folds ------------------------------------------------------------

  static bool isCBlock(String catalogId) =>
      BlockChrome.of(catalogId).layout == BlockLayout.cBlock;

  static Iterable<String> _foldsOf(BlockGraph graph) => [
        for (final b in graph.blocks.values)
          if (b.collapsed && isCBlock(b.catalogId)) b.id,
      ];

  void toggleCollapsed(String id) {
    if (!collapsedIds.add(id)) collapsedIds.remove(id);
    foldsVersion++;
    notifyListeners();
  }

  bool isCollapsed(String id) => collapsedIds.contains(id);

  /// Every C-block in the program.
  List<String> get cBlockIds => [
        for (final b in graph.blocks.values)
          if (isCBlock(b.catalogId)) b.id,
      ];

  void collapseAll() {
    collapsedIds
      ..clear()
      ..addAll(cBlockIds);
    foldsVersion++;
    notifyListeners();
  }

  void expandAll() {
    if (collapsedIds.isEmpty) return;
    collapsedIds.clear();
    foldsVersion++;
    notifyListeners();
  }

  /// The program as saved: the folds are written into the blocks' own
  /// `collapsed` field (ignored by execution).
  BlockGraph get graphForSave {
    final g = graph;
    final changed = <String, BlockInstance>{};
    for (final b in g.blocks.values) {
      final folded = collapsedIds.contains(b.id) && isCBlock(b.catalogId);
      if (b.collapsed != folded) changed[b.id] = b.copyWith(collapsed: folded);
    }
    if (changed.isEmpty) return g;
    return g.copyWith(blocks: {...g.blocks, ...changed});
  }

  // ---- history ----------------------------------------------------------

  void undo() {
    _history.undo();
    _clearSelection();
    _dropStaleFolds();
    flash = null;
    notifyListeners();
  }

  void redo() {
    _history.redo();
    _clearSelection();
    _dropStaleFolds();
    flash = null;
    notifyListeners();
  }

  void _clearSelection() {
    activeHole = null;
    selectedBlockId = null;
  }

  void _dropStaleFolds() {
    final before = collapsedIds.length;
    collapsedIds.removeWhere((id) => !graph.blocks.containsKey(id));
    if (collapsedIds.length != before) foldsVersion++;
  }

  bool apply(GraphCommand command) {
    final result = _history.apply(command);
    if (!result.ok) {
      flash = EditorNotice.engine(result.decision.message);
      notifyListeners();
      return false;
    }
    flash = null;
    notifyListeners();
    return true;
  }

  /// Adds a block and plugs it into [to], as one undo step (before MS13 it
  /// was two, and one UNDO left the block behind, unseen but counted).
  String? place(Placement placement, {required PortRef to, int? index}) {
    final def = BlockCatalog.of(placement.catalogId);
    final id = graph.allocId();
    final out = def?.outputs.firstOrNull?.name;
    final ok = apply(_Batch([
      AddBlockCommand(
        catalogId: placement.catalogId,
        id: id,
        literals: _withDefaults(placement),
      ),
      if (out != null) ConnectCommand(from: PortRef(id, out), to: to, index: index),
    ]));
    if (!ok) return null;
    selectedBlockId = id;
    activeHole = null;
    flash = null;
    _reveal(id);
    notifyListeners();
    return id;
  }

  Map<String, Object?> _withDefaults(Placement placement) {
    final next = Map<String, Object?>.of(placement.literals);
    if (placement.catalogId == BlockIds.litNum && !next.containsKey('value')) {
      next['value'] = 0;
    }
    if (placement.catalogId == BlockIds.litBool && !next.containsKey('value')) {
      next['value'] = false;
    }
    return next;
  }

  void addFromPalette(String catalogId) {
    final def = BlockCatalog.of(catalogId);
    if (def == null) return;
    if (def.role == BlockRole.expression) {
      final hole = activeHole;
      if (hole == null) {
        flash = EditorNotice((l) => l.noticeTapSlotFirst);
        notifyListeners();
        return;
      }
      final allowed = placementsFor(hole);
      final hit = allowed.where((p) => p.catalogId == catalogId).toList();
      if (hit.isEmpty) {
        flash = EditorNotice((l) => l.noticePieceDoesNotFit);
        notifyListeners();
        return;
      }
      place(hit.first, to: hole);
      return;
    }
    final well = activeWell;
    place(Placement(catalogId: catalogId), to: well);
  }

  /// Whether a palette tap on [catalogId] needs a name chosen first
  /// (INCREMENT / DECREMENT): the palette then opens the picker instead.
  static bool needsName(String catalogId) =>
      catalogId == BlockIds.varInc || catalogId == BlockIds.varDec;

  /// Where a palette instruction goes: the selected list, else the end of
  /// the program.
  PortRef get activeWell {
    final hole = activeHole;
    if (hole != null) {
      final def = hole.blockId == BlockGraph.mainId
          ? null
          : BlockCatalog.of(graph.blocks[hole.blockId]?.catalogId ?? '');
      final port = def?.port(hole.port);
      if (hole.blockId == BlockGraph.mainId ||
          port?.kind == PortKind.statement ||
          port?.kind == PortKind.elseClause) {
        return hole;
      }
    }
    return PortRef.mainBody;
  }

  // ---- the program as a tree ---------------------------------------------

  /// Blocks plugged into [id], in port order.
  List<String> childrenOf(String id) {
    final block = graph.blocks[id];
    if (block == null) return const [];
    return [
      for (final slot in block.slots.values)
        ...switch (slot) {
          RefBinding(:final blockId) => [blockId],
          ListBinding(:final blockIds) => blockIds,
        },
    ];
  }

  /// [id] and everything inside it, parents before children.
  List<String> subtreeOf(String id) {
    final out = <String>[];
    void walk(String b) {
      if (!graph.blocks.containsKey(b) || out.contains(b)) return;
      out.add(b);
      childrenOf(b).forEach(walk);
    }

    walk(id);
    return out;
  }

  /// The blocks that hold [id], innermost first (else clauses included).
  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var parent = graph.parentOf(id);
    while (parent != null && parent.blockId != BlockGraph.mainId) {
      out.add(parent.blockId);
      parent = graph.parentOf(parent.blockId);
    }
    return out;
  }

  bool isStatement(String id) {
    final def = BlockCatalog.of(graph.blocks[id]?.catalogId ?? '');
    return def?.role == BlockRole.statement;
  }

  /// Scroll [id] into view once built, unfolding what hides it.
  void _reveal(String id) {
    revealId = id;
    var unfolded = false;
    for (final a in ancestorsOf(id)) {
      unfolded = collapsedIds.remove(a) || unfolded;
    }
    if (unfolded) foldsVersion++;
  }

  /// A tile calls this once it is on screen; true means scroll to it.
  bool takeReveal(String id) {
    if (revealId != id) return false;
    revealId = null;
    return true;
  }

  // ---- the selection -----------------------------------------------------

  SelectionInfo? get selection {
    final id = selectedBlockId;
    final block = id == null ? null : graph.blocks[id];
    if (id == null || block == null) return null;
    final statement = isStatement(id);
    return SelectionInfo(
      blockId: id,
      label: _labelOf(block),
      size: subtreeOf(id).length,
      isStatement: statement,
      canDuplicate: statement,
      moves: statement ? _moves(id) : const {},
    );
  }

  String _labelOf(BlockInstance block) {
    final name = block.literals['name'];
    if (block.catalogId == BlockIds.varGet && name is String) return name;
    if (block.catalogId == BlockIds.litNum) return '${block.literals['value'] ?? 0}';
    final label = BlockChrome.labelOf(block.catalogId);
    return name is String ? '$label $name' : label;
  }

  Set<MoveDirection> _moves(String id) {
    final at = graph.parentOf(id);
    if (at == null) return const {};
    final list = graph.slotList(at.blockId, at.port);
    return {
      if (at.index > 0) MoveDirection.up,
      if (at.index < list.length - 1) MoveDirection.down,
      if (at.blockId != BlockGraph.mainId) MoveDirection.out,
      if (at.index > 0 && _bodyOf(list[at.index - 1]) != null) MoveDirection.into,
    };
  }

  /// The first instruction list of a C-block (THEN / DO).
  PortRef? _bodyOf(String id) {
    final def = BlockCatalog.of(graph.blocks[id]?.catalogId ?? '');
    if (def == null) return null;
    for (final port in def.inputs) {
      if (port.kind == PortKind.statement) return PortRef(id, port.name);
    }
    return null;
  }

  /// Deletes the selected block and everything inside it, as one undo step.
  /// A value leaves its slot empty again.
  bool deleteSelected() {
    final id = selectedBlockId;
    if (id == null || !graph.blocks.containsKey(id)) return false;
    return deleteTree(id);
  }

  bool deleteTree(String id) {
    final tree = subtreeOf(id);
    final label = _labelOf(graph.blocks[id]!);
    final ok = apply(_Batch([
      for (final b in tree.reversed) RemoveBlockCommand(b),
    ]));
    if (!ok) return false;
    _clearSelection();
    collapsedIds.removeAll(tree);
    final inside = tree.length - 1;
    flash = EditorNotice((l) => inside == 0
        ? l.noticeRemoved(label)
        : l.noticeRemovedWithInside(label, blocksText(inside, l)));
    notifyListeners();
    return true;
  }

  /// Copies the selected instruction (and everything inside it) just below
  /// itself, as one undo step. Every connection goes through the engine's
  /// typed connect, like a placement.
  String? duplicateSelected() {
    final id = selectedBlockId;
    if (id == null || !isStatement(id)) return null;
    final at = graph.parentOf(id);
    if (at == null) return null;
    final tree = subtreeOf(id);
    final ids = <String, String>{};
    final taken = {...graph.blocks.keys};
    var n = 1;
    for (final b in tree) {
      while (taken.contains('b$n')) {
        n++;
      }
      ids[b] = 'b$n';
      taken.add('b$n');
    }
    final commands = <GraphCommand>[];
    void copy(String b) {
      final block = graph.blocks[b]!;
      commands.add(AddBlockCommand(
        catalogId: block.catalogId,
        id: ids[b],
        literals: block.literals,
      ));
    }

    void fill(String b) {
      final block = graph.blocks[b]!;
      final def = BlockCatalog.of(block.catalogId)!;
      for (final port in def.inputs) {
        final children = graph.slotList(b, port.name);
        for (final (k, child) in children.indexed) {
          final childDef = BlockCatalog.of(graph.blocks[child]!.catalogId)!;
          copy(child);
          commands.add(ConnectCommand(
            from: PortRef(ids[child]!, childDef.outputs.first.name),
            to: PortRef(ids[b]!, port.name),
            index: port.kind == PortKind.statement ? k : null,
          ));
          fill(child);
        }
      }
    }

    copy(id);
    commands.add(AttachStatementCommand(
      blockId: ids[id]!,
      to: PortRef(at.blockId, at.port),
      index: at.index + 1,
    ));
    fill(id);
    if (!apply(_Batch(commands))) return null;
    final copyId = ids[id]!;
    for (final b in tree) {
      if (collapsedIds.contains(b)) collapsedIds.add(ids[b]!);
    }
    selectedBlockId = copyId;
    final copied = _labelOf(graph.blocks[copyId]!);
    final inside = tree.length - 1;
    flash = EditorNotice((l) => inside == 0
        ? l.noticeCopied(copied)
        : l.noticeCopiedWithInside(copied, blocksText(inside, l)));
    _reveal(copyId);
    notifyListeners();
    return copyId;
  }

  /// Moves the selected instruction, as one undo step.
  bool moveSelected(MoveDirection direction) {
    final id = selectedBlockId;
    if (id == null || !(selection?.moves.contains(direction) ?? false)) {
      return false;
    }
    final at = graph.parentOf(id)!;
    final list = graph.slotList(at.blockId, at.port);
    final PortRef to;
    final int index;
    switch (direction) {
      case MoveDirection.up:
        to = PortRef(at.blockId, at.port);
        index = at.index - 1;
      case MoveDirection.down:
        to = PortRef(at.blockId, at.port);
        index = at.index + 1;
      case MoveDirection.out:
        // An ELSE list belongs to its IF: step out past the IF.
        var holder = at.blockId;
        if (graph.blocks[holder]?.catalogId == BlockIds.ctrlElse) {
          holder = graph.parentOf(holder)?.blockId ?? holder;
        }
        final outer = graph.parentOf(holder);
        if (outer == null) return false;
        to = PortRef(outer.blockId, outer.port);
        index = outer.index + 1;
      case MoveDirection.into:
        final body = _bodyOf(list[at.index - 1]);
        if (body == null) return false;
        to = body;
        index = graph.slotList(body.blockId, body.port).length;
    }
    final ok = apply(_Batch([
      DisconnectCommand(id),
      AttachStatementCommand(blockId: id, to: to, index: index),
    ]));
    if (!ok) return false;
    selectedBlockId = id;
    _reveal(id);
    notifyListeners();
    return true;
  }

  /// After a RUN that stopped on a block: select it, bring it into view and
  /// say why.
  void showProblem(String blockId, EditorNotice message) {
    if (!graph.blocks.containsKey(blockId)) {
      showFlash(message);
      return;
    }
    selectedBlockId = blockId;
    activeHole = null;
    flash = message;
    _reveal(blockId);
    notifyListeners();
  }

  // ---- the rest ------------------------------------------------------------

  /// Replace the whole program (e.g. with the saved best solution). One undo
  /// step brings the previous program back.
  void replaceGraph(BlockGraph graph) {
    apply(_ReplaceGraphCommand(
      withoutStrays(graph).copyWith(variables: {...graph.variables, ..._names(puzzle)}),
    ));
    _clearSelection();
    collapsedIds
      ..clear()
      ..addAll(_foldsOf(this.graph));
    foldsVersion++;
    notifyListeners();
  }

  void setLiteral(String blockId, String key, Object? value) {
    apply(SetLiteralsCommand(blockId, {key: value}));
  }

  /// Declares a name that is not declared yet (tests, custom puzzles); the
  /// puzzle's own names already are.
  void declareVariable(String name, ValueType type) {
    if (graph.variables.containsKey(name)) return;
    apply(DeclareVariableCommand(name: name, type: type));
  }

  /// Required first example: IF / GREATER THAN / GET ELEMENT / NUMBER,
  /// WHILE + nested SET, IF THEN + ELSE.
  void seedWorkingExample() {
    declareVariable('i', ValueType.number);
    declareVariable('found', ValueType.boolean);

    final ifId = place(
      const Placement(catalogId: BlockIds.ctrlIf),
      to: PortRef.mainBody,
    );
    if (ifId == null) return;
    final gt = place(
      const Placement(catalogId: BlockIds.cmpGt),
      to: PortRef(ifId, 'condition'),
    );
    if (gt == null) return;
    final getEl = place(
      const Placement(catalogId: BlockIds.arrGet),
      to: PortRef(gt, 'left'),
    );
    if (getEl == null) return;
    place(
      const Placement(catalogId: BlockIds.varGet, literals: {'name': 'nums'}),
      to: PortRef(getEl, 'array'),
    );
    place(
      const Placement(catalogId: BlockIds.litNum, literals: {'value': 0}),
      to: PortRef(getEl, 'index'),
    );
    place(
      const Placement(catalogId: BlockIds.litNum, literals: {'value': 3}),
      to: PortRef(gt, 'right'),
    );

    final setTrue = place(
      const Placement(catalogId: BlockIds.varSet, literals: {'name': 'found'}),
      to: PortRef(ifId, 'then'),
    );
    if (setTrue != null) {
      place(
        const Placement(
          catalogId: BlockIds.litBool,
          literals: {'value': true},
        ),
        to: PortRef(setTrue, 'value'),
      );
    }

    final elseId = place(
      const Placement(catalogId: BlockIds.ctrlElse),
      to: PortRef(ifId, 'else'),
    );
    if (elseId != null) {
      final setFalse = place(
        const Placement(
          catalogId: BlockIds.varSet,
          literals: {'name': 'found'},
        ),
        to: PortRef(elseId, 'body'),
      );
      if (setFalse != null) {
        place(
          const Placement(
            catalogId: BlockIds.litBool,
            literals: {'value': false},
          ),
          to: PortRef(setFalse, 'value'),
        );
      }
    }

    final whileId = place(
      const Placement(catalogId: BlockIds.ctrlWhile),
      to: PortRef.mainBody,
    );
    if (whileId == null) return;
    final lt = place(
      const Placement(catalogId: BlockIds.cmpLt),
      to: PortRef(whileId, 'condition'),
    );
    if (lt == null) return;
    place(
      const Placement(catalogId: BlockIds.varGet, literals: {'name': 'i'}),
      to: PortRef(lt, 'left'),
    );
    place(
      const Placement(catalogId: BlockIds.varGet, literals: {'name': 'target'}),
      to: PortRef(lt, 'right'),
    );
    final setI = place(
      const Placement(catalogId: BlockIds.varSet, literals: {'name': 'i'}),
      to: PortRef(whileId, 'body'),
    );
    if (setI == null) return;
    final plus = place(
      const Placement(catalogId: BlockIds.arithAdd),
      to: PortRef(setI, 'value'),
    );
    if (plus == null) return;
    place(
      const Placement(catalogId: BlockIds.varGet, literals: {'name': 'i'}),
      to: PortRef(plus, 'left'),
    );
    place(
      const Placement(catalogId: BlockIds.litNum, literals: {'value': 1}),
      to: PortRef(plus, 'right'),
    );
    revealId = null;
    selectedBlockId = null;
  }
}

/// [graph] without the blocks the program does not reach from its top-level
/// list. Returns [graph] itself when every block is part of the program.
BlockGraph withoutStrays(BlockGraph graph) {
  final reached = <String>{};
  void walk(String id) {
    final block = graph.blocks[id];
    if (block == null || !reached.add(id)) return;
    for (final slot in block.slots.values) {
      switch (slot) {
        case RefBinding(:final blockId):
          walk(blockId);
        case ListBinding(:final blockIds):
          blockIds.forEach(walk);
      }
    }
  }

  graph.entryIds.forEach(walk);
  if (reached.length == graph.blocks.length) return graph;
  return graph.copyWith(blocks: {
    for (final e in graph.blocks.entries)
      if (reached.contains(e.key)) e.key: e.value,
  });
}

/// Engine commands applied as one step: all of them, or none.
final class _Batch implements GraphCommand {
  _Batch(this.commands);

  final List<GraphCommand> commands;
  BlockGraph? _before;

  @override
  GraphMutationResult execute(BlockGraph current) {
    var next = current;
    for (final command in commands) {
      final result = command.execute(next);
      if (!result.ok) return GraphMutationResult.denied(current, result.decision);
      next = result.graph;
    }
    _before = current;
    return GraphMutationResult.ok(next);
  }

  @override
  BlockGraph undo(BlockGraph current) => _before ?? current;
}

final class _ReplaceGraphCommand implements GraphCommand {
  _ReplaceGraphCommand(this.graph);

  final BlockGraph graph;
  BlockGraph? _before;

  @override
  GraphMutationResult execute(BlockGraph current) {
    _before = current;
    return GraphMutationResult.ok(graph);
  }

  @override
  BlockGraph undo(BlockGraph current) => _before ?? current;
}
