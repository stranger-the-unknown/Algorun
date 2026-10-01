import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rebuilds [target] the way a player's taps do: every block is chosen from
/// what the picker offers for its slot (`EditorController.placementsFor`,
/// i.e. `GraphTyping.compatiblePlacements` within the allowlist) and placed
/// with `EditorController.place`, top-down; names and numbers are then set
/// the way the name sheet and number pad set them.
EditorController buildThroughEditor(Puzzle puzzle, BlockGraph target) {
  final c = EditorController(puzzle: puzzle);
  for (final e in target.variables.entries) {
    if (!c.graph.variables.containsKey(e.key)) c.declareVariable(e.key, e.value);
  }

  void placeTree(String id, PortRef to, {int? index}) {
    final block = target.blocks[id]!;
    final offered = c.placementsFor(to, index: index);
    final named = block.catalogId == BlockIds.varGet || BlockIds.isCall(block.catalogId);
    final pick = offered.where((p) =>
        p.catalogId == block.catalogId && (!named || p.literals['name'] == block.literals['name']));
    if (pick.isEmpty) {
      fail('${puzzle.id}: the picker for ${to.port} does not offer ${block.catalogId} '
          '${block.literals['name'] ?? ''} (offers ${offered.map((p) => p.catalogId).toSet()})');
    }
    final placed = c.place(pick.first, to: to, index: index);
    if (placed == null) fail('${puzzle.id}: placing ${block.catalogId} was refused: ${c.flash}');
    if (block.catalogId != BlockIds.varGet) {
      for (final e in block.literals.entries) {
        c.setLiteral(placed, e.key, e.value);
      }
    }
    final def = BlockCatalog.of(block.catalogId)!;
    for (final port in def.inputs) {
      for (final (k, child) in target.slotList(id, port.name).indexed) {
        placeTree(child, PortRef(placed, port.name), index: port.kind == PortKind.statement ? k : null);
      }
    }
  }

  for (final (i, id) in target.entryIds.indexed) {
    // The puzzle's FUNCTION blocks are already there (L2): build their bodies.
    if (target.blocks[id]?.catalogId == BlockIds.fnDef) {
      if (c.graph.entryIds.indexOf(id) != i) fail('${puzzle.id}: FUNCTION $id is not where the editor puts it');
      for (final (k, child) in target.slotList(id, 'body').indexed) {
        placeTree(child, PortRef(id, 'body'), index: k);
      }
      continue;
    }
    placeTree(id, PortRef.mainBody, index: i);
  }
  return c;
}
