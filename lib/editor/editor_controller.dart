import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/foundation.dart';

/// Owns [GraphHistory]. Pointer / sheet UI does not go through Riverpod.
final class EditorController extends ChangeNotifier {
  EditorController({
    required this.puzzle,
    bool seedExample = false,
  }) : _history = GraphHistory(
          BlockGraph(
            blocks: const {},
            variables: {
              for (final input in puzzle.io.inputs) input.name: input.type,
            },
          ),
        ) {
    if (seedExample) {
      seedWorkingExample();
      _history.markBaseline();
    }
  }

  final Puzzle puzzle;
  final GraphHistory _history;

  PortRef? activeHole;
  String? selectedBlockId;
  String? flash;
  final Set<String> collapsedIds = {};

  BlockGraph get graph => _history.current;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  List<String> get paletteIds => [
        for (final id in puzzle.blocks.allow)
          if (!BlockChrome.hiddenFromEditor(id)) id,
      ];

  List<IoBinding> get givens => puzzle.io.inputs;

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

  void showFlash(String message) {
    flash = message;
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

  void toggleCollapsed(String id) {
    if (!collapsedIds.add(id)) collapsedIds.remove(id);
    notifyListeners();
  }

  bool isCollapsed(String id) => collapsedIds.contains(id);

  void undo() {
    _history.undo();
    _clearSelection();
    notifyListeners();
  }

  void redo() {
    _history.redo();
    _clearSelection();
    notifyListeners();
  }

  void _clearSelection() {
    activeHole = null;
    selectedBlockId = null;
  }

  bool apply(GraphCommand command) {
    final result = _history.apply(command);
    if (!result.ok) {
      flash = result.decision.message;
      notifyListeners();
      return false;
    }
    flash = null;
    notifyListeners();
    return true;
  }

  String? place(Placement placement, {required PortRef to, int? index}) {
    final add = AddBlockCommand(
      catalogId: placement.catalogId,
      literals: _withDefaults(placement),
    );
    if (!apply(add)) return null;
    final id = add.addedId;
    if (id == null) return null;
    final def = BlockCatalog.of(placement.catalogId);
    final out = def?.outputs.firstOrNull?.name;
    if (out == null) return id;
    final connected = _history.apply(
      ConnectCommand(
        from: PortRef(id, out),
        to: to,
        index: index,
      ),
    );
    if (!connected.ok) {
      _history.undo();
      _history.forgetRedo();
      flash = connected.decision.message;
      notifyListeners();
      return null;
    }
    selectedBlockId = id;
    activeHole = null;
    flash = null;
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
        flash = 'Tap a value slot first.';
        notifyListeners();
        return;
      }
      final allowed = placementsFor(hole);
      final hit = allowed.where((p) => p.catalogId == catalogId).toList();
      if (hit.isEmpty) {
        flash = 'This piece does not fit here.';
        notifyListeners();
        return;
      }
      place(hit.first, to: hole);
      return;
    }
    final well = _activeWell();
    place(Placement(catalogId: catalogId), to: well);
  }

  PortRef _activeWell() {
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

  void detachSelected() {
    final id = selectedBlockId;
    if (id == null) return;
    apply(RemoveBlockCommand(id));
    selectedBlockId = null;
  }

  void setLiteral(String blockId, String key, Object? value) {
    apply(SetLiteralsCommand(blockId, {key: value}));
  }

  void declareVariable(String name, ValueType type) {
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
  }
}
