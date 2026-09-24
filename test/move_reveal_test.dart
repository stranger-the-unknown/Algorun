import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/editor/statement_tile.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "reveal_probe", "title": "Reveal", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Scroll follow.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.if", "ctrl.else", "ctrl.while", "ctrl.return", "var.set", "var.get", "var.inc",
              "lit.num", "cmp.lt", "arith.add", "arr.len"],
    "maxBlocks": 120
  },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2] }, "out": 2 }],
    "hidden": [{ "id": "h1", "in": { "nums": [] }, "out": 0 }]
  },
  "variables": { "pool": [{ "name": "i", "type": "num" }, { "name": "total", "type": "num" }] }
}
''');

/// A tall program: many top-level INCREMENT steps, then a folded WHILE, then RETURN.
({EditorController c, String first, String last, String loop, String nested}) _tall() {
  final c = EditorController(puzzle: _puzzle());
  c.declareVariable('i', ValueType.number);
  c.declareVariable('total', ValueType.number);
  String put(String id, PortRef to, [Map<String, Object?> lit = const {}]) =>
      c.place(Placement(catalogId: id, literals: lit), to: to)!;
  final first = put(BlockIds.varInc, PortRef.mainBody, {'name': 'i'});
  String last = first;
  for (var n = 0; n < 24; n++) {
    last = put(BlockIds.varInc, PortRef.mainBody, {'name': 'i'});
  }
  final loop = put(BlockIds.ctrlWhile, PortRef.mainBody);
  final lt = put(BlockIds.cmpLt, PortRef(loop, 'condition'));
  put(BlockIds.varGet, PortRef(lt, 'left'), {'name': 'i'});
  put(BlockIds.litNum, PortRef(lt, 'right'), {'value': 1});
  final nested = put(BlockIds.varInc, PortRef(loop, 'body'), {'name': 'total'});
  put(BlockIds.ctrlReturn, PortRef.mainBody);
  c.toggleCollapsed(loop);
  c.selectBlock(null);
  c.revealId = null;
  return (c: c, first: first, last: last, loop: loop, nested: nested);
}

void main() {
  test('UP/DOWN keeps selection on the moved block and requests a reveal', () {
    final p = _tall();
    p.c.selectBlock(p.last);
    final before = p.c.graph.entryIds.indexOf(p.last);
    expect(p.c.moveSelected(MoveDirection.up), isTrue);
    expect(p.c.selectedBlockId, p.last);
    expect(p.c.revealId, p.last);
    expect(p.c.graph.entryIds.indexOf(p.last), before - 1);
    final epoch = p.c.revealEpoch;
    expect(p.c.moveSelected(MoveDirection.down), isTrue);
    expect(p.c.selectedBlockId, p.last);
    expect(p.c.revealId, p.last);
    expect(p.c.revealEpoch, greaterThan(epoch));
    expect(p.c.graph.entryIds.indexOf(p.last), before);
  });

  test('reveal inside a folded C-block unfolds it and keeps selection', () {
    final p = _tall();
    expect(p.c.isCollapsed(p.loop), isTrue);
    p.c.showProblem(p.nested, EditorNotice.engine('Needs a value.'));
    expect(p.c.selectedBlockId, p.nested);
    expect(p.c.isCollapsed(p.loop), isFalse, reason: 'reveal unfolds the fold');
    expect(p.c.revealId, p.nested);
  });

  test('UP inside a nested body keeps selection and requests reveal', () {
    final p = _tall();
    p.c.expandAll();
    final lower = p.c.place(
      const Placement(catalogId: BlockIds.varInc, literals: {'name': 'i'}),
      to: PortRef(p.loop, 'body'),
    )!;
    p.c.selectBlock(lower);
    expect(p.c.moveSelected(MoveDirection.up), isTrue);
    expect(p.c.selectedBlockId, lower);
    expect(p.c.revealId, lower);
    expect(p.c.graph.slotList(p.loop, 'body').first, lower);
  });

  test('undo/redo clear selection and do not leave a stale reveal', () {
    final p = _tall();
    p.c.selectBlock(p.last);
    p.c.moveSelected(MoveDirection.up);
    expect(p.c.revealId, p.last);
    p.c.undo();
    expect(p.c.selectedBlockId, isNull);
    expect(p.c.revealId, isNull, reason: 'clearSelection path resets reveal via replace?');
    // undo clears selection but may leave revealId - check actual behavior
  });

  test('stale takeReveal does not consume a newer reveal', () {
    final p = _tall();
    p.c.selectBlock(p.last);
    p.c.moveSelected(MoveDirection.up);
    final staleEpoch = p.c.revealEpoch;
    final id = p.c.revealId!;
    p.c.moveSelected(MoveDirection.up);
    expect(p.c.takeReveal(id, staleEpoch), isFalse);
    expect(p.c.revealId, id);
    expect(p.c.takeReveal(id, p.c.revealEpoch), isTrue);
    expect(p.c.revealId, isNull);
  });

  testWidgets('ScriptView stays mounted and selection survives UP moves', (tester) async {
    final p = _tall();
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: p.c,
            builder: (context, child) => ScriptView(controller: p.c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScriptView), findsOneWidget);
    expect(find.byType(StatementTile), findsWidgets);

    p.c.selectBlock(p.last);
    for (var i = 0; i < 8; i++) {
      expect(p.c.moveSelected(MoveDirection.up), isTrue);
      await tester.pump();
      await tester.pump();
      expect(p.c.selectedBlockId, p.last);
    }
    expect(find.byType(StatementTile), findsWidgets);
  });
}
