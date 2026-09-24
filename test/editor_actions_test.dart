import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/l10n/terms.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/progress_fixtures.dart';

/// The MS13 editor actions, through the controller the screen uses: one
/// undo step each, never a block left behind, typing decided by the engine.
Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "actions_probe", "title": "Actions", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Editor actions.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.if", "ctrl.else", "ctrl.while", "ctrl.return", "var.set", "var.get", "var.inc",
              "lit.num", "cmp.lt", "arith.add", "arr.len"],
    "maxBlocks": 60
  },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2] }, "out": 2 }],
    "hidden": [{ "id": "h1", "in": { "nums": [] }, "out": 0 }]
  },
  "variables": { "pool": [{ "name": "i", "type": "num" }, { "name": "total", "type": "num" }] }
}
''');

/// i = 0; WHILE i < LENGTH nums { total = total + 1; INCREMENT i }; IF i < 1 { … } ELSE { … }; RETURN total
({EditorController c, String loop, String setTotal, String inc, String ifId, String elseId, String ret}) _program() {
  final c = EditorController(puzzle: _puzzle());
  c.declareVariable('i', ValueType.number);
  c.declareVariable('total', ValueType.number);
  String put(String id, PortRef to, [Map<String, Object?> lit = const {}]) =>
      c.place(Placement(catalogId: id, literals: lit), to: to)!;
  final setI = put(BlockIds.varSet, PortRef.mainBody, {'name': 'i'});
  put(BlockIds.litNum, PortRef(setI, 'value'));
  final loop = put(BlockIds.ctrlWhile, PortRef.mainBody);
  final lt = put(BlockIds.cmpLt, PortRef(loop, 'condition'));
  put(BlockIds.varGet, PortRef(lt, 'left'), {'name': 'i'});
  final len = put(BlockIds.arrLen, PortRef(lt, 'right'));
  put(BlockIds.varGet, PortRef(len, 'array'), {'name': 'nums'});
  final setTotal = put(BlockIds.varSet, PortRef(loop, 'body'), {'name': 'total'});
  final plus = put(BlockIds.arithAdd, PortRef(setTotal, 'value'));
  put(BlockIds.varGet, PortRef(plus, 'left'), {'name': 'total'});
  put(BlockIds.litNum, PortRef(plus, 'right'), {'value': 1});
  final inc = put(BlockIds.varInc, PortRef(loop, 'body'), {'name': 'i'});
  final ifId = put(BlockIds.ctrlIf, PortRef.mainBody);
  final cond = put(BlockIds.cmpLt, PortRef(ifId, 'condition'));
  put(BlockIds.varGet, PortRef(cond, 'left'), {'name': 'i'});
  put(BlockIds.litNum, PortRef(cond, 'right'), {'value': 1});
  put(BlockIds.varInc, PortRef(ifId, 'then'), {'name': 'total'});
  final elseId = put(BlockIds.ctrlElse, PortRef(ifId, 'else'));
  put(BlockIds.varInc, PortRef(elseId, 'body'), {'name': 'i'});
  final ret = put(BlockIds.ctrlReturn, PortRef.mainBody);
  put(BlockIds.varGet, PortRef(ret, 'value'), {'name': 'total'});
  c.selectBlock(null);
  return (c: c, loop: loop, setTotal: setTotal, inc: inc, ifId: ifId, elseId: elseId, ret: ret);
}

/// Every block the program reaches from its top-level list.
int _reachable(BlockGraph g) => withoutStrays(g).blockCount;

void main() {
  test('a placement is one undo step and leaves nothing behind', () {
    final c = EditorController(puzzle: _puzzle());
    final id = c.place(const Placement(catalogId: BlockIds.ctrlWhile), to: PortRef.mainBody)!;
    expect(c.blockCount, 1);
    c.undo();
    expect(c.graph.blocks, isEmpty, reason: 'one UNDO removes the block, not just its connection');
    c.redo();
    expect(c.graph.entryIds, [id]);
    expect(c.blockCount, 1);
  });

  test('delete takes the block and everything inside it; one undo brings it all back', () {
    final p = _program();
    final before = graphText(p.c.graph);
    final size = p.c.subtreeOf(p.loop).length;
    expect(size, 10);
    p.c.selectBlock(p.loop);
    expect(p.c.selection!.size, size);
    expect(p.c.deleteSelected(), isTrue);
    expect(p.c.blockCount, _reachable(p.c.graph), reason: 'no unseen blocks count against the budget');
    expect('${p.c.flash}', 'Removed WHILE and 9 blocks inside. UNDO brings them back.');
    expect(p.c.flash!.render(stringsFor('tr')), 'WHILE ve içindeki 9 blok silindi. GERİ AL onları geri getirir.');
    p.c.undo();
    expect(graphText(p.c.graph), before);
    expect(p.c.flash, isNull, reason: 'an undone message does not linger');
  });

  test('deleting a value empties its slot', () {
    final p = _program();
    final plus = p.c.graph.slotList(p.setTotal, 'value').single;
    p.c.selectBlock(plus);
    expect(p.c.selection!.isStatement, isFalse);
    expect(p.c.selection!.moves, isEmpty);
    p.c.deleteSelected();
    expect(p.c.graph.slotList(p.setTotal, 'value'), isEmpty);
    expect(p.c.blockCount, _reachable(p.c.graph));
  });

  test('duplicate copies an instruction with its contents just below it, as one step', () {
    final p = _program();
    final before = graphText(p.c.graph);
    p.c.selectBlock(p.ifId);
    final copy = p.c.duplicateSelected()!;
    expect(p.c.graph.entryIds.indexOf(copy), p.c.graph.entryIds.indexOf(p.ifId) + 1);
    expect(p.c.subtreeOf(copy).length, p.c.subtreeOf(p.ifId).length, reason: 'ELSE included');
    expect(p.c.blockCount, _reachable(p.c.graph));
    expect(p.c.selectedBlockId, copy);
    p.c.undo();
    expect(graphText(p.c.graph), before);
  });

  test('moves: up, down, out of a block, into the block above — each one undo step', () {
    final p = _program();
    p.c.selectBlock(p.inc);
    expect(p.c.selection!.moves, {MoveDirection.up, MoveDirection.out});
    p.c.moveSelected(MoveDirection.up);
    expect(p.c.graph.slotList(p.loop, 'body').first, p.inc);
    p.c.moveSelected(MoveDirection.out);
    expect(p.c.graph.entryIds.indexOf(p.inc), p.c.graph.entryIds.indexOf(p.loop) + 1);
    expect(p.c.selection!.moves, containsAll([MoveDirection.up, MoveDirection.down, MoveDirection.into]));
    p.c.moveSelected(MoveDirection.into);
    expect(p.c.graph.slotList(p.loop, 'body').last, p.inc);
    p.c.undo();
    expect(p.c.graph.entryIds.indexOf(p.inc), p.c.graph.entryIds.indexOf(p.loop) + 1);
  });

  test('moving out of ELSE lands after its IF', () {
    final p = _program();
    final inElse = p.c.graph.slotList(p.elseId, 'body').single;
    p.c.selectBlock(inElse);
    p.c.moveSelected(MoveDirection.out);
    expect(p.c.graph.entryIds.indexOf(inElse), p.c.graph.entryIds.indexOf(p.ifId) + 1);
  });

  test('the first and top-level instructions offer only the moves that exist', () {
    final p = _program();
    p.c.selectBlock(p.c.graph.entryIds.first);
    expect(p.c.selection!.moves, {MoveDirection.down});
    p.c.selectBlock(p.ret);
    expect(p.c.selection!.moves, {MoveDirection.up, MoveDirection.into});
  });

  test('folds are saved with the program, never as an undo step, and restored', () {
    final p = _program();
    final graph = p.c.graph;
    p.c.toggleCollapsed(p.loop);
    expect(identical(p.c.graph, graph), isTrue, reason: 'folding is not an edit');
    expect(p.c.canUndo, isTrue);
    final saved = reloaded(PlayerSave.fresh.withPuzzle(
      'x',
      PuzzleProgress(puzzleVersion: 1, draft: p.c.graphForSave),
    ))['x']!.draft!;
    expect(saved.blocks[p.loop]!.collapsed, isTrue);
    expect(saved.blocks[p.ifId]!.collapsed, isFalse);
    final again = EditorController(puzzle: _puzzle(), initialGraph: saved);
    expect(again.isCollapsed(p.loop), isTrue);
    expect(again.isCollapsed(p.ifId), isFalse);
  });

  test('fold all / unfold all, and a placement inside a fold unfolds it', () {
    final p = _program();
    p.c.collapseAll();
    expect(p.c.collapsedIds, {p.loop, p.ifId});
    p.c.place(const Placement(catalogId: BlockIds.varInc, literals: {'name': 'i'}), to: PortRef(p.loop, 'body'));
    expect(p.c.isCollapsed(p.loop), isFalse, reason: 'the new block is revealed');
    expect(p.c.isCollapsed(p.ifId), isTrue);
    p.c.expandAll();
    expect(p.c.collapsedIds, isEmpty);
  });

  test('a restored program drops blocks it does not reach; a clean one is kept as is', () {
    final p = _program();
    final clean = p.c.graph;
    expect(identical(withoutStrays(clean), clean), isTrue);
    final stray = clean.copyWith(blocks: {
      ...clean.blocks,
      'lost': const BlockInstance(id: 'lost', catalogId: BlockIds.litNum, literals: {'value': 4}),
    });
    final restored = EditorController(puzzle: _puzzle(), initialGraph: stray);
    expect(restored.graph.blocks.containsKey('lost'), isFalse);
    expect(restored.blockCount, clean.blockCount);
  });

  test('a fold-only change keeps "edited since the last run" as it was', () {
    final campaign = tinyCampaign([('world_01', ['variables'], [], ['p1'])]);
    final puzzle = campaign.puzzles['p1']!;
    var save = PlayerSave.fresh.withPuzzle('p1', const PuzzleProgress(puzzleVersion: 1));
    save = saveDraft(save, campaign, puzzle, lengthGraph(), edited: false);
    expect(save['p1']!.editedSinceRun, isFalse);
    save = saveDraft(save, campaign, puzzle, lengthGraph());
    expect(save['p1']!.editedSinceRun, isTrue);
  });

  test('one block inside is said in the singular', () {
    final p = _program();
    p.c.selectBlock(p.ret);
    expect(p.c.selection!.size, 2);
    p.c.deleteSelected();
    expect('${p.c.flash}', 'Removed RETURN and 1 block inside. UNDO brings them back.');
    expect(blocksText(1, englishStrings), '1 block');
    expect(blocksText(3, englishStrings), '3 blocks');
  });

  test('a problem after RUN is selected, revealed and explained', () {
    final p = _program();
    p.c.collapseAll();
    final inc = p.inc;
    p.c.showProblem(inc, EditorNotice.engine('This block needs a value.'));
    expect(p.c.selectedBlockId, inc);
    expect('${p.c.flash}', 'This block needs a value.');
    expect(p.c.isCollapsed(p.loop), isFalse, reason: 'the folded loop around it opens');
    expect(p.c.revealId, inc);
  });
}
