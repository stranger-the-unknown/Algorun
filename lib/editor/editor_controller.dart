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
    this.canDelete = true,
    this.canCopy = false,
  });

  final String blockId;

  /// Player words (`WHILE`, `GET ELEMENT`, a variable's name).
  final String label;

  /// Blocks removed by a delete: the block and everything inside it.
  final int size;
  final bool isStatement;
  final bool canDuplicate;
  final Set<MoveDirection> moves;

  /// A FUNCTION comes from the puzzle (L2): it stays where it is.
  final bool canDelete;

  /// Whether the block can go on the clipboard (E1), to be pasted wherever
  /// it fits.
  final bool canCopy;
}

/// What a drop would do (E1): nothing (the block is already there), a move,
/// or a refusal with the reason in player words.
final class DropCheck {
  const DropCheck._(this.allowed, this.reason, {this.stays = false});

  /// The block is already at that place: dropping there changes nothing.
  static const same = DropCheck._(false, null, stays: true);
  static const ok = DropCheck._(true, null);
  const DropCheck.refused(EditorNotice reason) : this._(false, reason);

  final bool allowed;
  final bool stays;

  /// Why not, when the place is refused.
  final EditorNotice? reason;
}

/// A copied block with everything inside it (E1): a snapshot, so later edits
/// to the program do not change what PASTE brings back.
final class BlockClip {
  const BlockClip({
    required this.rootId,
    required this.blocks,
    required this.label,
    required this.isStatement,
    this.folded = const {},
  });

  /// The copied block's id inside [blocks] (ids are renewed on paste).
  final String rootId;

  /// The copied block and everything inside it, as they were when copied.
  final Map<String, BlockInstance> blocks;

  /// Player words for the copied block (`WHILE`, `GET ELEMENT`).
  final String label;
  final bool isStatement;

  /// The C-blocks that were folded when copied.
  final Set<String> folded;

  int get size => blocks.length;
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
  }) : _history = GraphHistory(FunctionSetup.ensure(
          initialGraph == null
              ? BlockGraph(blocks: const {}, variables: _names(puzzle))
              : withoutStrays(initialGraph).copyWith(
                  variables: {...initialGraph.variables, ..._names(puzzle)},
                ),
          puzzle.functions,
        )) {
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

  /// The instruction being dragged (E1), from the moment the finger moves
  /// after a long press until it lifts. UI state, like the selection.
  String? draggingId;

  /// The drop places already asked about during this drag.
  final Map<(PortRef, int), DropCheck> _dropChecks = {};
  Map<String, String>? _misfitsBeforeDrag;

  /// What COPY took (E1). It belongs to this editor, so it only ever holds
  /// blocks of this puzzle; it is not saved and is not an undo step.
  BlockClip? clipboard;

  /// Folded C-blocks. UI state: never an undo step, saved with the draft.
  final Set<String> collapsedIds = {};

  /// Bumped on every fold change, so autosave can notice one.
  int foldsVersion = 0;

  /// A block the script should scroll into view once it is built.
  String? revealId;

  /// Bumped on every [_reveal], so a stale post-frame callback cannot steal
  /// a newer reveal (rapid UP/DOWN taps).
  int revealEpoch = 0;

  BlockGraph get graph => _history.current;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// What the block budget counts: every block in the program.
  int get blockCount => graph.playerBlockCount;

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
    final all = GraphTyping.compatiblePlacements(
      graph,
      to: hole,
      allow: paletteIds,
      index: index,
    );
    // Inside a FUNCTION only its own values are known (L2): a given that is
    // not one of its parameters is not offered there.
    final owner = graph.blocks[hole.blockId];
    final fn = owner?.catalogId == BlockIds.fnDef ? owner : FunctionTable.enclosing(graph, hole.blockId);
    final sig = fn == null ? null : FunctionSignature.of(fn);
    if (sig == null) return all;
    final unseen = {
      for (final input in puzzle.io.inputs)
        if (!sig.params.any((p) => p.name == input.name)) input.name,
    };
    return [
      for (final p in all)
        if (p.catalogId != BlockIds.varGet || !unseen.contains(p.literals['name'])) p,
    ];
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
    _selectionOutOfFolds();
    foldsVersion++;
    notifyListeners();
  }

  /// A fold never leaves the selection on a block the player cannot see
  /// (E1): the selection moves to the outermost folded block that hides it,
  /// so the selection bar always acts on something on screen.
  void _selectionOutOfFolds() {
    final id = selectedBlockId;
    if (id == null) return;
    final hiding = ancestorsOf(id).where(collapsedIds.contains);
    if (hiding.isEmpty) return;
    // An ELSE is drawn as part of its IF and folds with it.
    selectedBlockId = hiding.last;
  }

  /// The blocks a folded [id] hides: everything inside it.
  int hiddenCount(String id) => subtreeOf(id).length - 1;

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
    _selectionOutOfFolds();
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
    revealId = null;
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
    revealEpoch++;
    var unfolded = false;
    for (final a in ancestorsOf(id)) {
      unfolded = collapsedIds.remove(a) || unfolded;
    }
    if (unfolded) foldsVersion++;
  }

  /// A tile calls this once it is on screen; true means scroll to it.
  /// [epoch] must match the [_reveal] that asked for this id.
  bool takeReveal(String id, int epoch) {
    if (revealId != id || revealEpoch != epoch) return false;
    revealId = null;
    return true;
  }

  // ---- the selection -----------------------------------------------------

  SelectionInfo? get selection {
    final id = selectedBlockId;
    final block = id == null ? null : graph.blocks[id];
    if (id == null || block == null) return null;
    final statement = isStatement(id);
    final given = isFunction(id);
    return SelectionInfo(
      blockId: id,
      label: _labelOf(block),
      size: subtreeOf(id).length,
      isStatement: statement,
      canDuplicate: statement && !given && _allAllowed(subtreeOf(id)),
      moves: statement && !given ? _moves(id) : const {},
      canDelete: !given,
      canCopy: canCopy(id),
    );
  }

  String _labelOf(BlockInstance block) {
    final name = block.literals['name'];
    if (block.catalogId == BlockIds.fnDef && name is String) return 'FUNCTION $name';
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

  /// A FUNCTION block the puzzle gave (L2).
  bool isFunction(String id) => graph.blocks[id]?.catalogId == BlockIds.fnDef;

  bool deleteTree(String id) {
    if (isFunction(id)) return false;
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
    if (id == null || !isStatement(id) || isFunction(id)) return null;
    final at = graph.parentOf(id);
    if (at == null) return null;
    final tree = subtreeOf(id);
    if (!_allAllowed(tree)) return null;
    final blocks = {for (final b in tree) b: graph.blocks[b]!};
    final ids = _freshIds(tree);
    final commands = _cloneCommands(blocks, id, ids, to: PortRef(at.blockId, at.port), index: at.index + 1);
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

  // ---- copy and paste (E1) -------------------------------------------------

  /// Every block of [tree] is one the puzzle lets the player add. A block a
  /// puzzle gave without allowing it (a FUNCTION, a starter block) cannot be
  /// multiplied by copying.
  bool _allAllowed(Iterable<String> tree) {
    final allow = puzzle.blocks.allow;
    return tree.every((b) => allow.contains(graph.blocks[b]?.catalogId));
  }

  /// A new id for each of [tree], none of them in the program.
  Map<String, String> _freshIds(Iterable<String> tree) {
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
    return ids;
  }

  static List<String> _slotIds(BlockInstance block, String port) => switch (block.slots[port]) {
        RefBinding(:final blockId) => [blockId],
        ListBinding(:final blockIds) => blockIds,
        null => const [],
      };

  /// The engine commands that rebuild [rootId] of [source] under new [ids]
  /// at [to]: the block is plugged in first and filled from the top down, so
  /// every connection is typed by `GraphTyping` in the place it lands in.
  List<GraphCommand> _cloneCommands(
    Map<String, BlockInstance> source,
    String rootId,
    Map<String, String> ids, {
    required PortRef to,
    int? index,
  }) {
    final commands = <GraphCommand>[];
    void add(String b, PortRef to, int? index) {
      final block = source[b]!;
      final def = BlockCatalog.of(block.catalogId)!;
      commands.add(AddBlockCommand(catalogId: block.catalogId, id: ids[b], literals: block.literals));
      commands.add(ConnectCommand(from: PortRef(ids[b]!, def.outputs.first.name), to: to, index: index));
      for (final port in def.inputs) {
        for (final (k, child) in _slotIds(block, port.name).indexed) {
          if (!source.containsKey(child)) continue;
          add(child, PortRef(ids[b]!, port.name), port.kind == PortKind.statement ? k : null);
        }
      }
    }

    add(rootId, to, index);
    return commands;
  }

  /// Whether [id] can go on the clipboard: any instruction or value except
  /// what the puzzle gave without allowing it.
  bool canCopy(String id) {
    final block = graph.blocks[id];
    if (block == null || isFunction(id)) return false;
    final def = BlockCatalog.of(block.catalogId);
    if (def == null || def.outputs.isEmpty) return false;
    // An ELSE is part of its IF; it is copied with it, never alone.
    if (def.outputs.first.kind == PortKind.elseClause) return false;
    return _allAllowed(subtreeOf(id));
  }

  /// Puts the selected block, with everything inside it, on the clipboard.
  /// The program does not change.
  bool copySelected() {
    final id = selectedBlockId;
    return id != null && copyTree(id);
  }

  bool copyTree(String id) {
    if (!canCopy(id)) return false;
    final tree = subtreeOf(id);
    final label = _labelOf(graph.blocks[id]!);
    clipboard = BlockClip(
      rootId: id,
      blocks: {for (final b in tree) b: graph.blocks[b]!},
      label: label,
      isStatement: isStatement(id),
      folded: {
        for (final b in tree)
          if (collapsedIds.contains(b)) b,
      },
    );
    final inside = tree.length - 1;
    flash = EditorNotice((l) => inside == 0
        ? l.noticeClipCopied(label)
        : l.noticeClipCopiedWithInside(label, blocksText(inside, l)));
    notifyListeners();
    return true;
  }

  /// The givens a block at [hole] cannot see: inside a FUNCTION only its own
  /// values are known (L2). Empty anywhere else.
  Set<String> _unseenAt(PortRef hole) {
    final owner = graph.blocks[hole.blockId];
    final fn = owner?.catalogId == BlockIds.fnDef ? owner : FunctionTable.enclosing(graph, hole.blockId);
    final sig = fn == null ? null : FunctionSignature.of(fn);
    if (sig == null) return const {};
    return {
      for (final input in puzzle.io.inputs)
        if (!sig.params.any((p) => p.name == input.name)) input.name,
    };
  }

  /// Whether none of [blocks] reads a given that is unknown at [hole].
  bool _seesItsNames(Iterable<BlockInstance> blocks, PortRef hole) {
    final unseen = _unseenAt(hole);
    if (unseen.isEmpty) return true;
    return blocks.every((b) => b.catalogId != BlockIds.varGet || !unseen.contains(b.literals['name']));
  }

  _Batch? _pasteBatch(PortRef to, int? index, [Map<String, String>? ids]) {
    final clip = clipboard;
    if (clip == null) return null;
    if (!clip.blocks.values.every((b) => puzzle.blocks.allow.contains(b.catalogId))) return null;
    if (!_seesItsNames(clip.blocks.values, to)) return null;
    return _Batch(_cloneCommands(clip.blocks, clip.rootId, ids ?? _freshIds(clip.blocks.keys), to: to, index: index));
  }

  /// Whether PASTE would be accepted at [to]: the clipboard is rebuilt there
  /// by the engine's own typed commands, without keeping the result.
  bool canPaste(PortRef to, {int? index}) => _pasteBatch(to, index)?.execute(graph).ok ?? false;

  /// Pastes the clipboard at [to], as one undo step. The copy is selected
  /// and scrolled into view. Returns the new block's id, or null when the
  /// clipboard does not fit there (nothing changes then).
  String? paste(PortRef to, {int? index}) {
    final clip = clipboard;
    if (clip == null) return null;
    final ids = _freshIds(clip.blocks.keys);
    final batch = _pasteBatch(to, index, ids);
    if (batch == null) {
      flash = EditorNotice((l) => l.noticePieceDoesNotFit);
      notifyListeners();
      return null;
    }
    if (!apply(batch)) return null;
    final id = ids[clip.rootId]!;
    for (final b in clip.folded) {
      collapsedIds.add(ids[b]!);
    }
    selectedBlockId = id;
    activeHole = null;
    final inside = clip.size - 1;
    flash = EditorNotice((l) => inside == 0
        ? l.noticePasted(clip.label)
        : l.noticePastedWithInside(clip.label, blocksText(inside, l)));
    _reveal(id);
    notifyListeners();
    return id;
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

  // ---- drag to move (E1) ----------------------------------------------------

  /// Whether [id] can be picked up: an instruction of the player's own.
  bool canDrag(String id) => isStatement(id) && !isFunction(id) && graph.parentOf(id) != null;

  /// The finger started moving [id]. The block is selected; nothing changes
  /// in the program until [moveTo].
  void beginDrag(String id) {
    if (!canDrag(id)) return;
    draggingId = id;
    selectedBlockId = id;
    activeHole = null;
    _dropChecks.clear();
    _misfitsBeforeDrag = null;
    notifyListeners();
  }

  void endDrag() {
    if (draggingId == null) return;
    draggingId = null;
    _dropChecks.clear();
    _misfitsBeforeDrag = null;
    notifyListeners();
  }

  /// The connections inside [tree] that the engine would refuse to make
  /// again where they are in [g], with the engine's reason: a value that may
  /// be empty outside its check, a BREAK outside a loop.
  Map<String, String> _misfits(BlockGraph g, Iterable<String> tree, {String? except}) {
    final out = <String, String>{};
    for (final b in tree) {
      if (b == except) continue;
      final block = g.blocks[b];
      final at = g.parentOf(b);
      final def = block == null ? null : BlockCatalog.of(block.catalogId);
      if (at == null || def == null || def.outputs.isEmpty) continue;
      final decision = GraphTyping.canConnect(
        g.detach(b),
        from: PortRef(b, def.outputs.first.name),
        to: PortRef(at.blockId, at.port),
        index: def.outputs.first.kind == PortKind.statement ? at.index : null,
      );
      if (!decision.allowed) out[b] = decision.message ?? '';
    }
    return out;
  }

  ({_Batch batch, PortRef to, int index})? _moveBatch(String id, PortRef to, int index) {
    final at = graph.parentOf(id);
    if (at == null) return null;
    final same = at.blockId == to.blockId && at.port == to.port;
    if (same && (index == at.index || index == at.index + 1)) return null;
    // [index] counts the list as it is shown; taking the block out of the
    // same list first moves everything after it one place up.
    final landing = same && index > at.index ? index - 1 : index;
    return (
      batch: _Batch([
        DisconnectCommand(id),
        AttachStatementCommand(blockId: id, to: to, index: landing),
      ]),
      to: to,
      index: landing,
    );
  }

  /// What dropping [id] before position [index] of the list [to] would do.
  /// [index] counts the list as it is shown now, the dragged block included.
  ///
  /// The engine decides: the move is its own detach + attach, and then every
  /// connection inside the moved block is asked again in the new place. A
  /// connection that was fine before and is refused there (a value that may
  /// be empty outside its check, a BREAK outside its loop) refuses the drop.
  DropCheck checkMove(String id, PortRef to, int index) {
    final cached = draggingId == id ? _dropChecks[(to, index)] : null;
    if (cached != null) return cached;
    final check = _checkMove(id, to, index);
    if (draggingId == id) _dropChecks[(to, index)] = check;
    return check;
  }

  DropCheck _checkMove(String id, PortRef to, int index) {
    if (!canDrag(id)) return DropCheck.refused(EditorNotice((l) => l.noticePieceDoesNotFit));
    final move = _moveBatch(id, to, index);
    if (move == null) return DropCheck.same;
    final tree = subtreeOf(id);
    if (tree.contains(to.blockId)) {
      return DropCheck.refused(EditorNotice((l) => l.noticeNotInsideItself));
    }
    final result = move.batch.execute(graph);
    if (!result.ok) return DropCheck.refused(EditorNotice.engine(result.decision.message));
    if (!_seesItsNames([for (final b in tree) graph.blocks[b]!], to)) {
      return DropCheck.refused(EditorNotice((l) => l.noticePieceDoesNotFit));
    }
    final before = draggingId == id
        ? (_misfitsBeforeDrag ??= _misfits(graph, tree, except: id))
        : _misfits(graph, tree, except: id);
    final after = _misfits(result.graph, tree, except: id);
    for (final entry in after.entries) {
      if (!before.containsKey(entry.key)) {
        final message = entry.value;
        return DropCheck.refused(EditorNotice.engine(message.isEmpty ? null : message));
      }
    }
    return DropCheck.ok;
  }

  /// Moves [id] before position [index] of the list [to] (see [checkMove]),
  /// as one undo step. A refused place changes nothing and says why.
  bool moveTo(String id, PortRef to, int index) {
    final check = _checkMove(id, to, index);
    if (!check.allowed) {
      if (check.reason != null) {
        flash = check.reason;
        notifyListeners();
      }
      return false;
    }
    final move = _moveBatch(id, to, index)!;
    if (!apply(move.batch)) return false;
    selectedBlockId = id;
    activeHole = null;
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
    apply(_ReplaceGraphCommand(FunctionSetup.ensure(
      withoutStrays(graph).copyWith(variables: {...graph.variables, ..._names(puzzle)}),
      puzzle.functions,
    )));
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
