import 'dart:io';

import 'package:algorun/dev/stress_probe.dart';
import 'package:algorun/editor/block_drag.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/statement_tile.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/editor_harness.dart';
import 'support/progress_fixtures.dart';

/// E1: long press, then drag, to move an instruction. The drop place is the
/// engine's to accept; a move is one undo step; UP / DOWN / OUT / IN stay.
Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "drag_probe", "title": "Drag", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Drag and drop.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.if", "ctrl.else", "ctrl.while", "ctrl.break", "ctrl.return", "var.set", "var.get", "var.inc",
              "lit.num", "cmp.lt", "arith.add", "arr.len", "logic.is_not_nothing"],
    "maxBlocks": 80
  },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2] }, "out": 2 }],
    "hidden": [{ "id": "h1", "in": { "nums": [] }, "out": 0 }]
  },
  "variables": { "pool": [{ "name": "i", "type": "num" }, { "name": "total", "type": "num" },
                           { "name": "c", "type": "num?" }] }
}
''');

typedef _Program = ({
  EditorController c,
  String setI,
  String loop,
  String inc,
  String stop,
  String brk,
  String ifId,
  String guarded,
  String elseId,
  String ret,
});

/// SET i TO 0
/// WHILE i < LENGTH nums { INCREMENT i; IF i < 1 { BREAK } }
/// IF c IS NOT NOTHING { SET total TO c + 1 } ELSE { }
/// RETURN total
_Program _program() {
  final c = EditorController(puzzle: _puzzle());
  String put(String id, PortRef to, [Map<String, Object?> lit = const {}]) =>
      c.place(Placement(catalogId: id, literals: lit), to: to)!;
  final setI = put(BlockIds.varSet, PortRef.mainBody, {'name': 'i'});
  put(BlockIds.litNum, PortRef(setI, 'value'));
  final loop = put(BlockIds.ctrlWhile, PortRef.mainBody);
  final lt = put(BlockIds.cmpLt, PortRef(loop, 'condition'));
  put(BlockIds.varGet, PortRef(lt, 'left'), {'name': 'i'});
  final len = put(BlockIds.arrLen, PortRef(lt, 'right'));
  put(BlockIds.varGet, PortRef(len, 'array'), {'name': 'nums'});
  final inc = put(BlockIds.varInc, PortRef(loop, 'body'), {'name': 'i'});
  final stop = put(BlockIds.ctrlIf, PortRef(loop, 'body'));
  final small = put(BlockIds.cmpLt, PortRef(stop, 'condition'));
  put(BlockIds.varGet, PortRef(small, 'left'), {'name': 'i'});
  put(BlockIds.litNum, PortRef(small, 'right'), {'value': 1});
  final brk = put(BlockIds.ctrlBreak, PortRef(stop, 'then'));
  final ifId = put(BlockIds.ctrlIf, PortRef.mainBody);
  final check = put(BlockIds.logicIsNotNothing, PortRef(ifId, 'condition'));
  put(BlockIds.varGet, PortRef(check, 'value'), {'name': 'c'});
  final guarded = put(BlockIds.varSet, PortRef(ifId, 'then'), {'name': 'total'});
  final sum = put(BlockIds.arithAdd, PortRef(guarded, 'value'));
  put(BlockIds.varGet, PortRef(sum, 'left'), {'name': 'c'});
  put(BlockIds.litNum, PortRef(sum, 'right'), {'value': 1});
  final elseId = put(BlockIds.ctrlElse, PortRef(ifId, 'else'));
  final ret = put(BlockIds.ctrlReturn, PortRef.mainBody);
  put(BlockIds.varGet, PortRef(ret, 'value'), {'name': 'total'});
  c.selectBlock(null);
  c.markBaseline();
  return (
    c: c,
    setI: setI,
    loop: loop,
    inc: inc,
    stop: stop,
    brk: brk,
    ifId: ifId,
    guarded: guarded,
    elseId: elseId,
    ret: ret,
  );
}

/// An instruction's tile. Built but off screen counts: during a drag the
/// whole program is built, and a finder skips what is not painted by default.
Finder _tile(String id) => find.byWidgetPredicate((w) => w is DropAnchor && w.blockId == id, skipOffstage: false);
Finder _grip(String id) =>
    find.descendant(of: _tile(id), matching: find.byType(BlockLabel, skipOffstage: false), skipOffstage: false).first;
BlockDragLayerState _layer(WidgetTester tester) => tester.state<BlockDragLayerState>(find.byType(BlockDragLayer));

/// Long-presses [id] and leaves the finger down.
Future<TestGesture> _hold(WidgetTester tester, String id) async {
  final gesture = await tester.startGesture(tester.getCenter(_grip(id)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
  return gesture;
}

/// Drags the held finger to [to] in a few steps, as a hand would.
Future<void> _dragTo(WidgetTester tester, TestGesture gesture, Offset from, Offset to) async {
  for (var step = 1; step <= 4; step++) {
    await gesture.moveTo(Offset.lerp(from, to, step / 4)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Rect _layerRect(WidgetTester tester) => tester.getRect(find.byType(BlockDragLayer));
ScrollPosition _position(WidgetTester tester) => tester.state<ScrollableState>(scriptScrollable).position;

/// Picks [id] up and carries it to the height [y] gives (a gap between two
/// instructions, in screen coordinates), the way a hand does: when that
/// place is off screen the finger rests at the edge and the program scrolls
/// to it. The finger is still down when this returns.
Future<TestGesture> _carry(WidgetTester tester, String id, double Function() y) async {
  if (_tile(id).evaluate().isEmpty) {
    await tester.scrollUntilVisible(_tile(id), 200, scrollable: scriptScrollable);
  }
  await tester.ensureVisible(_grip(id));
  await tester.pumpAndSettle();
  var at = tester.getCenter(_grip(id));
  final gesture = await _hold(tester, id);
  // Past the slop: the drag starts, and with it every instruction is built.
  final nudge = at.dy > _layerRect(tester).center.dy ? -12.0 : 12.0;
  at = at.translate(0, nudge);
  await gesture.moveTo(at);
  await tester.pump(const Duration(milliseconds: 16));
  final position = _position(tester);
  var still = 0;
  for (var frame = 0; frame < 1200 && still < 3; frame++) {
    final layer = _layerRect(tester);
    final target = y();
    if (target > layer.bottom - 90) {
      at = Offset(at.dx, layer.bottom - 6);
    } else if (target < layer.top + 90) {
      at = Offset(at.dx, layer.top + 6);
    } else {
      break;
    }
    final before = position.pixels;
    await gesture.moveTo(at);
    await tester.pump(const Duration(milliseconds: 16));
    still = position.pixels == before ? still + 1 : 0;
  }
  await tester.pump(const Duration(milliseconds: 16));
  await _dragTo(tester, gesture, at, Offset(at.dx, y()));
  return gesture;
}

double Function() _above(WidgetTester tester, String id) => () => tester.getRect(_tile(id)).top - 2;
double Function() _onRow(WidgetTester tester, Key key) =>
    () => tester.getRect(find.byKey(key, skipOffstage: false)).top + 4;
Color? _lineColour(WidgetTester tester) => (tester
        .widget<DecoratedBox>(
            find.descendant(of: find.byKey(const Key('drop-line')), matching: find.byType(DecoratedBox)))
        .decoration as BoxDecoration)
    .color;

void main() {
  group('controller', () {
    test('a move is the engine\'s detach + attach: one undo step, the same blocks', () {
      final p = _program();
      final c = p.c;
      final before = graphText(c.graph);
      final count = c.blockCount;

      // RETURN up to the top: before position 0 of the program.
      expect(c.checkMove(p.ret, PortRef.mainBody, 0).allowed, isTrue);
      expect(c.moveTo(p.ret, PortRef.mainBody, 0), isTrue);
      expect(c.graph.entryIds, [p.ret, p.setI, p.loop, p.ifId]);
      expect(c.selectedBlockId, p.ret);
      expect(c.blockCount, count);
      c.undo();
      expect(graphText(c.graph), before, reason: 'one UNDO');
      expect(c.canUndo, isFalse);
      c.redo();
      expect(c.graph.entryIds, [p.ret, p.setI, p.loop, p.ifId]);
      expect(c.canRedo, isFalse);
    });

    test('positions count the list as it is shown, the dragged block included', () {
      final p = _program();
      final c = p.c;
      // SET i is at 0. Before 0 or before 1 is where it already is.
      expect(c.checkMove(p.setI, PortRef.mainBody, 0).stays, isTrue);
      expect(c.checkMove(p.setI, PortRef.mainBody, 1).stays, isTrue);
      expect(c.moveTo(p.setI, PortRef.mainBody, 1), isFalse);
      expect(c.canUndo, isFalse, reason: 'dropping a block where it is changes nothing');
      expect(c.flash, isNull);
      // Before 3 (RETURN) puts it between IF and RETURN.
      expect(c.moveTo(p.setI, PortRef.mainBody, 3), isTrue);
      expect(c.graph.entryIds, [p.loop, p.ifId, p.setI, p.ret]);
      // Past the end.
      expect(c.moveTo(p.setI, PortRef.mainBody, 4), isTrue);
      expect(c.graph.entryIds, [p.loop, p.ifId, p.ret, p.setI]);
    });

    test('into a body, into ELSE, and out again', () {
      final p = _program();
      final c = p.c;
      expect(c.moveTo(p.setI, PortRef(p.loop, 'body'), 1), isTrue);
      expect(c.graph.slotList(p.loop, 'body'), [p.inc, p.setI, p.stop]);
      expect(c.moveTo(p.setI, PortRef(p.elseId, 'body'), 0), isTrue);
      expect(c.graph.slotList(p.elseId, 'body'), [p.setI]);
      expect(c.graph.slotList(p.loop, 'body'), [p.inc, p.stop]);
      expect(c.moveTo(p.setI, PortRef.mainBody, 0), isTrue);
      expect(c.graph.entryIds, [p.setI, p.loop, p.ifId, p.ret]);
      // A whole block with its body.
      final size = c.subtreeOf(p.loop).length;
      expect(c.moveTo(p.loop, PortRef(p.ifId, 'then'), 0), isTrue);
      expect(c.graph.slotList(p.ifId, 'then'), [p.loop, p.guarded]);
      expect(c.subtreeOf(p.loop).length, size);
    });

    test('a block does not go inside itself', () {
      final p = _program();
      final check = p.c.checkMove(p.loop, PortRef(p.stop, 'then'), 0);
      expect(check.allowed, isFalse);
      expect(check.reason.toString(), 'A block cannot go inside itself.');
      final before = p.c.graph;
      expect(p.c.moveTo(p.loop, PortRef(p.loop, 'body'), 0), isFalse);
      expect(identical(p.c.graph, before), isTrue);
      expect(p.c.canUndo, isFalse);
      expect(p.c.flash.toString(), 'A block cannot go inside itself.');
    });

    test('the engine refuses a place where the block does not type: BREAK outside a loop', () {
      final p = _program();
      final c = p.c;
      final direct = c.checkMove(p.brk, PortRef.mainBody, 0);
      expect(direct.allowed, isFalse);
      expect(direct.reason.toString(), 'Break and continue only work inside a loop.');
      // The IF that holds the BREAK: its own attach is fine anywhere, the
      // BREAK inside it is not.
      final holder = c.checkMove(p.stop, PortRef.mainBody, 0);
      expect(holder.allowed, isFalse);
      expect(holder.reason.toString(), 'Break and continue only work inside a loop.');
      // Inside the loop it may go anywhere.
      expect(c.checkMove(p.stop, PortRef(p.loop, 'body'), 0).allowed, isTrue);
      final before = c.graph;
      expect(c.moveTo(p.stop, PortRef.mainBody, 0), isFalse);
      expect(identical(c.graph, before), isTrue);
      expect(c.canUndo, isFalse);
    });

    test('a value that may be empty outside its check refuses the drop', () {
      final p = _program();
      final c = p.c;
      // total = c + 1 needs IF c IS NOT NOTHING around it.
      for (final (to, index) in [(PortRef.mainBody, 0), (PortRef(p.loop, 'body'), 0), (PortRef(p.elseId, 'body'), 0)]) {
        final check = c.checkMove(p.guarded, to, index);
        expect(check.allowed, isFalse, reason: '$to');
        expect(check.reason.toString(), 'This value may be empty here. Check that it is not empty first.');
      }
      // Something else may join it inside the check.
      expect(c.checkMove(p.setI, PortRef(p.ifId, 'then'), 0).allowed, isTrue);
    });

    test('a FUNCTION, a value and an ELSE are not picked up', () {
      final coins = shippedCampaign().puzzles['coin_stack']!;
      final f = EditorController(puzzle: coins);
      expect(f.canDrag('fn_sum_from'), isFalse);
      f.beginDrag('fn_sum_from');
      expect(f.draggingId, isNull);

      final p = _program();
      expect(p.c.canDrag(p.elseId), isFalse);
      expect(p.c.canDrag(p.c.graph.slotList(p.ret, 'value').single), isFalse);
      expect(p.c.canDrag(p.ret), isTrue);
    });

    test('dragging is not an edit: begin and end leave the program and its history alone', () {
      final p = _program();
      final before = p.c.graph;
      p.c.beginDrag(p.ret);
      expect(p.c.draggingId, p.ret);
      expect(p.c.selectedBlockId, p.ret);
      p.c.checkMove(p.ret, PortRef.mainBody, 0);
      p.c.endDrag();
      expect(p.c.draggingId, isNull);
      expect(identical(p.c.graph, before), isTrue);
      expect(p.c.canUndo, isFalse);
    });

    test('on the longest program: every accepted drop is a sound program, and one UNDO restores it', () {
      final c = EditorController(
        puzzle: shippedPuzzle('world_09', 'cheapest_crossing'),
        initialGraph: referenceSolution('world_09', 'cheapest_crossing'),
      );
      c.markBaseline();
      final before = graphText(c.graph);
      final statements = [
        for (final b in c.graph.blocks.keys)
          if (c.canDrag(b)) b,
      ];
      final lists = <PortRef>{PortRef.mainBody};
      for (final b in statements) {
        final at = c.graph.parentOf(b)!;
        lists.add(PortRef(at.blockId, at.port));
      }
      var accepted = 0;
      var refused = 0;
      var n = 0;
      for (final id in statements) {
        for (final list in lists) {
          final length = c.graph.slotList(list.blockId, list.port).length;
          for (var index = 0; index <= length; index++) {
            if (n++ % 11 != 0) continue; // a spread sample: the full product is slow
            final check = c.checkMove(id, list, index);
            if (check.stays) continue;
            if (!check.allowed) {
              refused++;
              expect(c.moveTo(id, list, index), isFalse);
              expect(graphText(c.graph), before);
              continue;
            }
            accepted++;
            expect(c.moveTo(id, list, index), isTrue, reason: '$id → $list @ $index');
            expect(GraphStructure.validate(c.graph).messages.map((m) => m.code).toSet().difference({'empty_hole'}),
                isEmpty);
            expect(c.graph.blocks.length, referenceSolution('world_09', 'cheapest_crossing').blocks.length);
            c.undo();
            expect(graphText(c.graph), before);
          }
        }
      }
      expect(accepted, greaterThan(50));
      expect(refused, greaterThan(0), reason: 'a block is never dropped inside itself');
    });
  });

  group('on a 360 × 800 phone', () {
    Future<_Program> open(WidgetTester tester, {String? language}) async {
      final p = _program();
      await openEditor(tester, p.c.puzzle, initial: p.c.graph, language: language);
      return p;
    }

    testWidgets('a long press alone still only selects', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final before = c.graph;
      final gesture = await _hold(tester, p.setI);
      await tester.pump();
      expect(c.selectedBlockId, p.setI);
      expect(c.draggingId, isNull);
      expect(find.byKey(const Key('drag-tag')), findsNothing);
      // A tremble of the finger is not a drag.
      await gesture.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(c.draggingId, isNull);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.selectedBlockId, p.setI);
      expect(identical(c.graph, before), isTrue);
      expect(find.text('UP'), findsOneWidget, reason: 'the step buttons are still there');
      expect(find.text('DOWN'), findsOneWidget);
      expect(find.text('OUT'), findsOneWidget);
      expect(find.text('IN'), findsOneWidget);
    });

    testWidgets('drag an instruction down the program: the line shows the place; one UNDO takes it back',
        (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);

      // Just above RETURN: between IF and RETURN.
      final gesture = await _carry(tester, p.setI, _above(tester, p.ret));
      expect(c.draggingId, p.setI);
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, 3));
      expect(_layer(tester).targetAllowed, isTrue);
      expect(find.byKey(const Key('drop-line')), findsOneWidget);
      expect(find.byKey(const Key('drag-tag')), findsOneWidget);
      expect(_lineColour(tester), AppPalette.dark.accent);
      final dimmed = tester.widget<Opacity>(find.descendant(of: _tile(p.setI), matching: find.byType(Opacity, skipOffstage: false), skipOffstage: false).first);
      expect(dimmed.opacity, lessThan(1), reason: 'the block being moved is dimmed in its old place');
      expect(c.graph.entryIds, [p.setI, p.loop, p.ifId, p.ret], reason: 'nothing moves before the finger lifts');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.entryIds, [p.loop, p.ifId, p.setI, p.ret]);
      expect(c.draggingId, isNull);
      expect(c.selectedBlockId, p.setI);
      expect(find.byKey(const Key('drop-line')), findsNothing);
      expect(find.byKey(const Key('drag-tag')), findsNothing);
      final restored = tester.widget<Opacity>(find.descendant(of: _tile(p.setI), matching: find.byType(Opacity, skipOffstage: false), skipOffstage: false).first);
      expect(restored.opacity, 1);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(c.graph.entryIds, [p.setI, p.loop, p.ifId, p.ret]);
      expect(c.canUndo, isFalse, reason: 'the drag was one step');
      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(c.graph.entryIds, [p.loop, p.ifId, p.setI, p.ret]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drop into a body: on its "add step" row, or between its instructions', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      // Onto the empty ELSE.
      var gesture = await _carry(tester, p.setI, _onRow(tester, ValueKey('add-step:${p.elseId}.body')));
      expect(_layer(tester).target, DropTarget(PortRef(p.elseId, 'body'), 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.slotList(p.elseId, 'body'), [p.setI]);
      expect(c.graph.entryIds, [p.loop, p.ifId, p.ret]);

      // RETURN up into the loop, between INCREMENT and the inner IF.
      gesture = await _carry(tester, p.ret, _above(tester, p.stop));
      expect(_layer(tester).target, DropTarget(PortRef(p.loop, 'body'), 1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.slotList(p.loop, 'body'), [p.inc, p.ret, p.stop]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a place the engine refuses is red while the finger is on it, says why, and takes no drop',
        (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final before = c.graph;

      // Out of its IF, to the top of the program.
      final gesture = await _carry(tester, p.guarded, _above(tester, p.setI));
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, 0));
      expect(_layer(tester).targetAllowed, isFalse);
      expect(_lineColour(tester), AppPalette.dark.danger);
      const why = 'This value may be empty here. Check that it is not empty first.';
      expect(find.descendant(of: find.byKey(const Key('drag-tag')), matching: find.text(why)), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(identical(c.graph, before), isTrue, reason: 'a refused drop moves nothing');
      expect(c.canUndo, isFalse);
      expect(find.text(why), findsOneWidget, reason: 'the feedback line says why');
      expect(c.draggingId, isNull);
    });

    testWidgets('the line follows the finger from a refused place to a good one', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      // BREAK out of the loop is refused…
      final gesture = await _carry(tester, p.brk, _above(tester, p.loop));
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, 1));
      expect(_lineColour(tester), AppPalette.dark.danger);
      // …but the top of the loop's own body takes it.
      final x = tester.getCenter(_tile(p.inc)).dx;
      await _dragTo(tester, gesture, Offset(x, _above(tester, p.loop)()), Offset(x, _above(tester, p.inc)()));
      expect(_layer(tester).target, DropTarget(PortRef(p.loop, 'body'), 0));
      expect(_lineColour(tester), AppPalette.dark.accent);
      expect(find.descendant(of: find.byKey(const Key('drag-tag')), matching: find.textContaining('loop')),
          findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.slotList(p.loop, 'body'), [p.brk, p.inc, p.stop]);
      expect(c.graph.slotList(p.stop, 'then'), isEmpty);
    });

    testWidgets('the tag and the reason are in the player\'s language', (tester) async {
      final p = await open(tester, language: 'tr');
      final gesture = await _carry(tester, p.brk, _above(tester, p.loop));
      expect(_layer(tester).targetAllowed, isFalse);
      final tag = find.byKey(const Key('drag-tag'));
      expect(find.descendant(of: tag, matching: find.text('BREAK')), findsOneWidget);
      expect(find.descendant(of: tag, matching: find.textContaining('döngü')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.textContaining('döngü'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block with a body drags as one: the tag counts what moves', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final size = c.subtreeOf(p.loop).length;
      final gesture = await _carry(tester, p.loop, _above(tester, p.ret));
      expect(find.descendant(of: find.byKey(const Key('drag-tag')), matching: find.text('WHILE · $size blocks')),
          findsOneWidget);
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, 3));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.entryIds, [p.setI, p.ifId, p.loop, p.ret]);
      expect(c.subtreeOf(p.loop).length, size);
    });

    testWidgets('its own body is not a place for a block', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final before = c.graph;
      final gesture = await _hold(tester, p.loop);
      final start = tester.getCenter(_grip(p.loop));
      // Over its own INCREMENT: the nearest place is still the block's own.
      await _dragTo(tester, gesture, start, tester.getCenter(_tile(p.inc)));
      expect(c.draggingId, p.loop);
      expect(_layer(tester).target?.to.blockId, isNot(anyOf(p.loop, p.stop)));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.subtreeOf(p.loop).length, before.blocks.keys.where((b) => c.subtreeOf(p.loop).contains(b)).length);
      expect(c.graph.slotList(p.loop, 'body'), [p.inc, p.stop]);
    });

    testWidgets('a cancelled gesture moves nothing', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final before = c.graph;
      final gesture = await _carry(tester, p.setI, _above(tester, p.ret));
      expect(c.draggingId, p.setI);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(c.draggingId, isNull);
      expect(identical(c.graph, before), isTrue);
      expect(find.byKey(const Key('drag-tag')), findsNothing);
    });

    testWidgets('a long press on a value still selects the value, and drags nothing', (tester) async {
      final p = await open(tester);
      final c = editorOf(tester);
      final plus = c.graph.slotList(p.guarded, 'value').single;
      await tester.scrollUntilVisible(inScript('PLUS'), 200, scrollable: scriptScrollable);
      await tester.ensureVisible(inScript('PLUS'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(inScript('PLUS')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      expect(c.selectedBlockId, plus);
      expect(c.draggingId, isNull);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the screen reader\'s long press still selects', (tester) async {
      final handle = tester.ensureSemantics();
      final p = await open(tester);
      final c = editorOf(tester);
      final node = tester.getSemantics(_grip(p.setI));
      expect(node.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      tester.semantics.longPress(find.semantics.byPredicate((n) => n.id == node.id));
      await tester.pumpAndSettle();
      expect(c.selectedBlockId, p.setI);
      expect(c.draggingId, isNull);
      handle.dispose();
    });
  });

  group('a long program', () {
    final puzzle = parsePuzzleJson(File('assets/puzzles/world_01/$stressProbeId.json').readAsStringSync());

    testWidgets('resting the finger at the bottom edge scrolls the program; the drop lands far away, in one step',
        (tester) async {
      await openEditor(tester, puzzle);
      final c = editorOf(tester);
      expect(c.blockCount, 82);
      final first = c.graph.entryIds.first;
      final last = c.graph.entryIds.last;
      final position = _position(tester);
      await tester.ensureVisible(_grip(first));
      await tester.pumpAndSettle();
      final from = position.pixels;

      // Above the RETURN at the very end.
      final gesture = await _carry(tester, first, _above(tester, last));
      expect(c.draggingId, first);
      expect(position.pixels, greaterThan(from + 800), reason: 'more than a screen went by under the finger');
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, c.graph.entryIds.length - 1));
      expect(_layer(tester).targetAllowed, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();

      final ids = c.graph.entryIds;
      expect(ids.indexOf(first), ids.length - 2);
      expect(c.blockCount, 82);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(c.graph.entryIds.first, first);
      expect(c.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and back up: the top edge scrolls the other way', (tester) async {
      await openEditor(tester, puzzle);
      final c = editorOf(tester);
      final first = c.graph.entryIds.first;
      final last = c.graph.entryIds.last;
      final position = _position(tester);
      await tester.scrollUntilVisible(_tile(last), 400, scrollable: scriptScrollable);
      await tester.pumpAndSettle();
      final from = position.pixels;
      expect(from, greaterThan(800));

      final gesture = await _carry(tester, last, _above(tester, first));
      expect(position.pixels, lessThan(from - 800));
      expect(_layer(tester).target, DropTarget(PortRef.mainBody, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.entryIds.first, last);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a deep block comes out to the top level through three levels', (tester) async {
      await openEditor(tester, puzzle);
      final c = editorOf(tester);
      // INCREMENT echoes, inside IF inside IF inside WHILE inside WHILE.
      final deep = c.graph.blocks.values
          .firstWhere((b) => b.catalogId == BlockIds.varInc && b.literals['name'] == 'echoes')
          .id;
      expect(c.ancestorsOf(deep).length, 4);
      await tester.scrollUntilVisible(_tile(deep), 300, scrollable: scriptScrollable);
      final last = c.graph.entryIds.last;
      final gesture = await _carry(tester, deep, _above(tester, last));
      expect(_layer(tester).targetAllowed, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.graph.parentOf(deep)!.blockId, BlockGraph.mainId);
      expect(c.blockCount, 82);
      expect(tester.takeException(), isNull);
    });
  });
}
