import 'package:algorun/editor/editor_bars.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/editor_harness.dart';
import 'support/progress_fixtures.dart';

/// E1: copy a block (with everything inside it) and paste it wherever the
/// engine's typing accepts it. One undo step per paste; COPY itself changes
/// nothing.
Puzzle _puzzle({String allowExtra = ''}) => parsePuzzleJson('''
{
  "id": "clipboard_probe", "title": "Clipboard", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Copy and paste.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.if", "ctrl.else", "ctrl.while", "ctrl.return", "var.set", "var.get", "var.inc",
              "lit.num", "cmp.lt", "arith.add", "arr.len", "logic.is_not_nothing"$allowExtra],
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
  String loop,
  String lt,
  String setTotal,
  String plus,
  String ifId,
  String guarded,
  String ret,
});

/// WHILE i < LENGTH nums { total = total + 1; INCREMENT i }
/// IF c IS NOT NOTHING { total = c + 1 }
/// RETURN ▢
_Program _program([Puzzle? puzzle]) {
  final c = EditorController(puzzle: puzzle ?? _puzzle());
  String put(String id, PortRef to, [Map<String, Object?> lit = const {}]) =>
      c.place(Placement(catalogId: id, literals: lit), to: to)!;
  final loop = put(BlockIds.ctrlWhile, PortRef.mainBody);
  final lt = put(BlockIds.cmpLt, PortRef(loop, 'condition'));
  put(BlockIds.varGet, PortRef(lt, 'left'), {'name': 'i'});
  final len = put(BlockIds.arrLen, PortRef(lt, 'right'));
  put(BlockIds.varGet, PortRef(len, 'array'), {'name': 'nums'});
  final setTotal = put(BlockIds.varSet, PortRef(loop, 'body'), {'name': 'total'});
  final plus = put(BlockIds.arithAdd, PortRef(setTotal, 'value'));
  put(BlockIds.varGet, PortRef(plus, 'left'), {'name': 'total'});
  put(BlockIds.litNum, PortRef(plus, 'right'), {'value': 1});
  put(BlockIds.varInc, PortRef(loop, 'body'), {'name': 'i'});
  final ifId = put(BlockIds.ctrlIf, PortRef.mainBody);
  final check = put(BlockIds.logicIsNotNothing, PortRef(ifId, 'condition'));
  put(BlockIds.varGet, PortRef(check, 'value'), {'name': 'c'});
  final guarded = put(BlockIds.varSet, PortRef(ifId, 'then'), {'name': 'total'});
  final sum = put(BlockIds.arithAdd, PortRef(guarded, 'value'));
  put(BlockIds.varGet, PortRef(sum, 'left'), {'name': 'c'});
  put(BlockIds.litNum, PortRef(sum, 'right'), {'value': 1});
  final ret = put(BlockIds.ctrlReturn, PortRef.mainBody);
  c.selectBlock(null);
  c.markBaseline();
  return (c: c, loop: loop, lt: lt, setTotal: setTotal, plus: plus, ifId: ifId, guarded: guarded, ret: ret);
}

/// The shape of [id]: its block, literals and everything inside, without ids.
String _shape(BlockGraph g, String id) {
  final b = g.blocks[id]!;
  final def = BlockCatalog.of(b.catalogId)!;
  final parts = [
    for (final port in def.inputs)
      if (g.slotList(id, port.name).isNotEmpty)
        '${port.name}:[${g.slotList(id, port.name).map((child) => _shape(g, child)).join(', ')}]',
  ];
  return '${b.catalogId}${b.literals.isEmpty ? '' : b.literals}${parts.isEmpty ? '' : '(${parts.join(' ')})'}';
}

void main() {
  group('controller', () {
    test('COPY takes a snapshot and changes nothing: no undo step, no edit', () {
      final p = _program();
      final before = p.c.graph;
      p.c.selectBlock(p.loop);
      expect(p.c.selection!.canCopy, isTrue);
      expect(p.c.copySelected(), isTrue);
      expect(identical(p.c.graph, before), isTrue);
      expect(p.c.canUndo, isFalse);
      final clip = p.c.clipboard!;
      expect(clip.label, 'WHILE');
      expect(clip.isStatement, isTrue);
      expect(clip.size, p.c.subtreeOf(p.loop).length);
      expect(p.c.flash.toString(), 'Copied WHILE with 9 blocks inside. Tap where it should go, then choose PASTE.');
    });

    test('a pasted instruction brings everything inside it, under new ids, as one undo step', () {
      final p = _program();
      final c = p.c;
      c.copyTree(p.loop);
      final before = c.graph;
      final count = c.blockCount;
      final to = PortRef(p.ifId, 'then');
      expect(c.canPaste(to), isTrue);
      expect(identical(c.graph, before), isTrue, reason: 'asking does not edit');

      final copy = c.paste(to)!;
      expect(copy, isNot(p.loop));
      expect(c.graph.slotList(p.ifId, 'then'), [p.guarded, copy], reason: 'at the end of the list, like a placement');
      expect(_shape(c.graph, copy), _shape(c.graph, p.loop));
      expect(c.subtreeOf(copy).toSet().intersection(c.subtreeOf(p.loop).toSet()), isEmpty);
      expect(c.blockCount, count + 10);
      expect(c.selectedBlockId, copy);
      expect(c.flash.toString(), 'Pasted WHILE with 9 blocks inside.');
      expect(GraphStructure.validate(c.graph).messages.where((m) => m.code != 'empty_hole' && m.code != 'missing_input'), isEmpty);

      c.undo();
      expect(graphText(c.graph), graphText(before), reason: 'one UNDO takes the whole paste back');
      expect(c.canUndo, isFalse);
      c.redo();
      expect(c.blockCount, count + 10);
      expect(_shape(c.graph, c.graph.slotList(p.ifId, 'then').last), _shape(c.graph, p.loop));
    });

    test('PASTE at a position puts the copy there', () {
      final p = _program();
      p.c.copyTree(p.setTotal);
      final copy = p.c.paste(PortRef.mainBody, index: 0)!;
      expect(p.c.graph.entryIds, [copy, p.loop, p.ifId, p.ret]);
    });

    test('a value can be copied into a slot of its type, and nowhere else', () {
      final p = _program();
      final c = p.c;
      c.selectBlock(p.plus);
      expect(c.selection!.isStatement, isFalse);
      expect(c.selection!.canCopy, isTrue);
      c.copySelected();
      expect(c.clipboard!.isStatement, isFalse);
      expect(c.clipboard!.label, 'PLUS');

      // RETURN ▢ takes a number: total PLUS 1 fits.
      final value = PortRef(p.ret, 'value');
      expect(c.canPaste(value), isTrue);
      // A condition does not take a number; an instruction list does not take a value.
      final before = c.graph;
      final extra = c.place(const Placement(catalogId: BlockIds.ctrlWhile), to: PortRef.mainBody)!;
      c.markBaseline();
      expect(c.canPaste(PortRef(extra, 'condition')), isFalse);
      expect(c.canPaste(PortRef.mainBody), isFalse);
      expect(c.canPaste(PortRef(extra, 'body')), isFalse);
      final held = c.graph;
      expect(c.paste(PortRef(extra, 'condition')), isNull);
      expect(identical(c.graph, held), isTrue, reason: 'a refused paste changes nothing');
      expect(c.canUndo, isFalse, reason: 'and is not an undo step');
      expect(c.flash, isNotNull);
      expect(before.blocks.length + 1, held.blocks.length);

      final copy = c.paste(value)!;
      expect(_shape(c.graph, copy), _shape(c.graph, p.plus));
      expect(c.graph.slotList(p.ret, 'value'), [copy]);
      // The slot is taken now.
      expect(c.canPaste(value), isFalse);
      c.undo();
      expect(c.graph.slotList(p.ret, 'value'), isEmpty);
    });

    test('an instruction does not paste into a value slot', () {
      final p = _program();
      p.c.copyTree(p.setTotal);
      expect(p.c.canPaste(PortRef(p.ret, 'value')), isFalse);
      expect(p.c.canPaste(PortRef(p.ifId, 'else')), isFalse, reason: 'only ELSE goes there');
      expect(p.c.canPaste(PortRef(p.loop, 'body')), isTrue);
    });

    test('the place decides: a value that may be empty there is refused', () {
      final p = _program();
      final c = p.c;
      // total = c + 1 is fine inside IF c IS NOT NOTHING, and nowhere else.
      c.copyTree(p.guarded);
      expect(c.canPaste(PortRef(p.ifId, 'then')), isTrue);
      expect(c.canPaste(PortRef.mainBody), isFalse);
      expect(c.canPaste(PortRef(p.loop, 'body')), isFalse);
      final before = c.graph;
      expect(c.paste(PortRef.mainBody), isNull);
      expect(identical(c.graph, before), isTrue);
      expect(c.flash.toString(), 'This value may be empty here. Check that it is not empty first.');
      expect(c.paste(PortRef(p.ifId, 'then')), isNotNull);
    });

    test('the clipboard is a snapshot: deleting or editing the original does not change it', () {
      final p = _program();
      final c = p.c;
      c.copyTree(p.setTotal);
      final shape = _shape(c.graph, p.setTotal);
      c.setLiteral(p.setTotal, 'name', 'i');
      c.deleteTree(p.setTotal);
      final copy = c.paste(PortRef.mainBody)!;
      expect(_shape(c.graph, copy), shape);
      // And it can be pasted again.
      final second = c.paste(PortRef.mainBody)!;
      expect(_shape(c.graph, second), shape);
      expect(second, isNot(copy));
    });

    test('folds travel with the copy', () {
      final p = _program();
      final c = p.c;
      c.copyTree(p.ifId);
      expect(c.isCollapsed(c.paste(PortRef.mainBody)!), isFalse);
      c.toggleCollapsed(p.ifId);
      c.copyTree(p.ifId);
      c.toggleCollapsed(p.ifId);
      c.toggleCollapsed(p.loop);
      final copy = c.paste(PortRef(p.loop, 'body'))!;
      expect(c.isCollapsed(copy), isTrue, reason: 'a C-block copied folded pastes folded');
      expect(c.isCollapsed(p.loop), isFalse, reason: 'what holds the pasted block is unfolded to show it');
    });

    test('what the puzzle gave without allowing it cannot be copied or duplicated', () {
      // The same program, opened by a puzzle that no longer allows WHILE.
      final built = _program();
      final strict = parsePuzzleJson('''
{
  "id": "clipboard_strict", "title": "Strict", "world": "world_01", "tier": 1, "mode": "build",
  "story": "No loops.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.if", "ctrl.return", "var.set", "var.get", "var.inc", "lit.num", "cmp.lt",
                        "arith.add", "arr.len", "logic.is_not_nothing"], "maxBlocks": 80 },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2] }, "out": 2 }],
    "hidden": [{ "id": "h1", "in": { "nums": [] }, "out": 0 }]
  },
  "variables": { "pool": [{ "name": "i", "type": "num" }, { "name": "total", "type": "num" },
                           { "name": "c", "type": "num?" }] }
}
''');
      final c = EditorController(puzzle: strict, initialGraph: built.c.graph);
      c.selectBlock(built.loop);
      expect(c.selection!.canCopy, isFalse);
      expect(c.selection!.canDuplicate, isFalse);
      expect(c.copySelected(), isFalse);
      expect(c.duplicateSelected(), isNull);
      expect(c.clipboard, isNull);
      // What is inside it and allowed can still be copied.
      c.selectBlock(built.setTotal);
      expect(c.selection!.canCopy, isTrue);
      expect(c.selection!.canDuplicate, isTrue);
    });

    test('DUPLICATE still copies just below, as one step, and leaves the clipboard alone', () {
      final p = _program();
      p.c.copyTree(p.plus);
      p.c.selectBlock(p.loop);
      final copy = p.c.duplicateSelected()!;
      expect(p.c.graph.entryIds, [p.loop, copy, p.ifId, p.ret]);
      expect(_shape(p.c.graph, copy), _shape(p.c.graph, p.loop));
      expect(p.c.clipboard!.label, 'PLUS');
      p.c.undo();
      expect(p.c.graph.entryIds, [p.loop, p.ifId, p.ret]);
    });
  });

  group('on the phone', () {
    Future<EditorController> open(WidgetTester tester, {String? language}) async {
      final p = _program();
      await openEditor(tester, p.c.puzzle, initial: p.c.graph, language: language);
      return editorOf(tester);
    }

    testWidgets('copy a value, tap an empty slot, PASTE; one UNDO takes it back', (tester) async {
      final c = await open(tester);
      final plus = c.graph.blocks.values.firstWhere((b) => b.catalogId == BlockIds.arithAdd).id;
      final ret = c.graph.entryIds.last;
      final count = c.blockCount;

      await tapVisible(tester, inScript('PLUS').first);
      expect(c.selectedBlockId, plus);
      await tapVisible(tester, find.byKey(const Key('selection-copy')));
      expect(find.textContaining('Copied PLUS with 2 blocks inside.'), findsOneWidget);
      expect(c.blockCount, count, reason: 'COPY does not change the program');

      await tapVisible(tester, find.bySemanticsLabel('Empty value slot'));
      expect(inSheet(find.text('COPIED')), findsOneWidget);
      expect(inSheet(find.text('PLUS · 3 blocks')), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-paste')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(c.blockCount, count + 3);
      expect(c.graph.blocks[c.graph.slotList(ret, 'value').single]!.catalogId, BlockIds.arithAdd);
      expect(c.activeHole, isNull);
      expect(find.text('Pasted PLUS with 2 blocks inside.'), findsOneWidget);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(c.blockCount, count);
      expect(c.graph.slotList(ret, 'value'), isEmpty);
    });

    testWidgets('copy an instruction with its body and paste it into another list', (tester) async {
      final c = await open(tester);
      final loop = c.graph.entryIds.first;
      final ifId = c.graph.entryIds[1];
      final count = c.blockCount;

      await tapVisible(tester, inScript('WHILE'));
      await tapVisible(tester, find.byKey(const Key('selection-copy')));
      await tapVisible(tester, find.byKey(ValueKey('add-step:$ifId.then')));
      expect(inSheet(find.text('WHILE · 10 blocks')), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-paste')));
      await tester.pumpAndSettle();

      expect(c.blockCount, count + 10);
      final pasted = c.graph.slotList(ifId, 'then').last;
      expect(_shape(c.graph, pasted), _shape(c.graph, loop));
      expect(c.selectedBlockId, pasted);
      expect(find.byType(BlockActionsBar), findsOneWidget);
    });

    testWidgets('PASTE is only offered where the copy fits', (tester) async {
      final c = await open(tester);
      // A number does not fit a list of instructions.
      await tapVisible(tester, inScript('PLUS').first);
      await tapVisible(tester, find.byKey(const Key('selection-copy')));
      await tapVisible(tester, find.byKey(const ValueKey('add-step:main')));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const Key('picker-paste')), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(c.activeHole, isNull);

      // The guarded SET fits its own IF, not the top of the program.
      final ifId = c.graph.entryIds[1];
      c.copyTree(c.graph.slotList(ifId, 'then').single);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('add-step:main')));
      expect(find.byKey(const Key('picker-paste')), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(ValueKey('add-step:$ifId.then')));
      expect(find.byKey(const Key('picker-paste')), findsOneWidget);
    });

    testWidgets('search keeps PASTE only while the query names it', (tester) async {
      final c = await open(tester);
      c.copyTree(c.graph.entryIds.first);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('add-step:main')));
      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'whi');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-paste')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'return');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('picker-paste')), findsNothing);
      expect(inSheet(find.text('RETURN')), findsOneWidget);
    });

    testWidgets('in Turkish; the selection bar keeps every action reachable at 360 dp', (tester) async {
      final c = await open(tester, language: 'tr');
      await tapVisible(tester, inScript('WHILE'));
      expect(find.text('ÇOĞALT'), findsOneWidget);
      expect(find.byTooltip('Başka bir yere yapıştırmak için kopyala'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('selection-copy')));
      expect(find.textContaining('WHILE, içindeki 9 blok ile birlikte kopyalandı.'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('add-step:main')));
      expect(inSheet(find.text('KOPYALANAN')), findsOneWidget);
      expect(inSheet(find.text('YAPIŞTIR')), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-paste')));
      await tester.pumpAndSettle();
      expect(find.text('WHILE, içindeki 9 blok ile birlikte yapıştırıldı.'), findsOneWidget);
      expect(c.graph.entryIds, hasLength(4));

      // SİL (delete) is the last action of the bar.
      await tapVisible(tester, find.text('SİL'));
      expect(c.graph.entryIds, hasLength(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the copy button is a labelled button for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await tapVisible(tester, inScript('WHILE'));
      expect(
        tester.getSemantics(find.byKey(const Key('selection-copy'))),
        isSemantics(
          tooltip: 'Copy, to paste somewhere else',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
