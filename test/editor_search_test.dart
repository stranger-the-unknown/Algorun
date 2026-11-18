import 'package:algorun/editor/block_search.dart';
import 'package:algorun/editor/palette_tray.dart';
import 'package:algorun/guide/guide_data.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/editor_harness.dart';

/// E1: search by block name, English or Turkish, in the picker and the
/// palette. Only what the puzzle allows is ever listed.
Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "search_probe", "title": "Search", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Search.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": {
    "allow": ["ctrl.if", "ctrl.else", "ctrl.while", "ctrl.foreach", "ctrl.return", "var.set", "var.get", "var.inc",
              "lit.num", "cmp.lt", "cmp.gt", "arith.add", "arr.len", "arr.get", "arr.append"],
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

final _palette = find.byType(PaletteTray);
Finder _chip(String label) => find.descendant(of: _palette, matching: find.text(label));

void main() {
  group('BlockSearch', () {
    test('folds case and Turkish letters', () {
      expect(BlockSearch.fold('DÖNGÜ İÇİN Iğdır Şu Ç'), 'dongu icin igdir su c');
      expect(BlockSearch.words('  get   EL '), ['get', 'el']);
      expect(BlockSearch.words('   '), isEmpty);
    });

    test('a block answers to its English name, in any case, by any part', () {
      expect(BlockSearch.matches(BlockIds.arrGet, 'get element'), isTrue);
      expect(BlockSearch.matches(BlockIds.arrGet, 'ELEM'), isTrue);
      expect(BlockSearch.matches(BlockIds.arrGet, 'el get'), isTrue, reason: 'words in any order');
      expect(BlockSearch.matches(BlockIds.arrGet, 'while'), isFalse);
      expect(BlockSearch.matches(BlockIds.arrGet, ''), isTrue, reason: 'a blank query lists everything');
    });

    test('a block answers to its Turkish name, with or without Turkish letters', () {
      expect(blockGuide[BlockIds.ctrlWhile]!.tr, contains('DÖNGÜ'));
      for (final query in ['döngü', 'DÖNGÜ', 'dongu', 'Döng']) {
        expect(BlockSearch.matches(BlockIds.ctrlWhile, query), isTrue, reason: query);
      }
      expect(BlockSearch.matches(BlockIds.ctrlReturn, 'döndür'), isTrue);
      expect(BlockSearch.matches(BlockIds.ctrlReturn, 'dongu'), isFalse);
    });

    test('a named piece answers to its name', () {
      expect(BlockSearch.matches(BlockIds.varGet, 'tot', literals: const {'name': 'total'}), isTrue);
      expect(BlockSearch.matches(BlockIds.varInc, 'increment total', literals: const {'name': 'total'}), isTrue);
      expect(BlockSearch.matches(BlockIds.varGet, 'nums', literals: const {'name': 'total'}), isFalse);
    });

    test('every catalog block is found by its own label; an unknown one does not throw', () {
      for (final def in BlockCatalog.all) {
        expect(BlockSearch.matches(def.id, BlockChrome.labelOf(def.id)), isTrue, reason: def.id);
      }
      expect(BlockSearch.matches('future.block', 'block'), isTrue);
      expect(BlockSearch.matches('future.block', 'while'), isFalse);
    });
  });

  group('palette search', () {
    testWidgets('no text field until asked; a name narrows the row; the hit places the block', (tester) async {
      await openEditor(tester, _puzzle());
      expect(find.byType(TextField), findsNothing, reason: 'programming never opens the keyboard by itself');
      expect(_chip('WHILE'), findsOneWidget);
      expect(_chip('IF'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('palette-search')));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'whi');
      await tester.pumpAndSettle();
      expect(_chip('WHILE'), findsOneWidget);
      expect(_chip('IF'), findsNothing);
      expect(_chip('RETURN'), findsNothing);

      await tester.tap(_chip('WHILE'));
      await tester.pumpAndSettle();
      final c = editorOf(tester);
      expect(c.graph.blocks[c.graph.entryIds.single]!.catalogId, BlockIds.ctrlWhile);
    });

    testWidgets('Turkish names work, and only allowed blocks are ever listed', (tester) async {
      await openEditor(tester, _puzzle(), language: 'tr');
      await tapVisible(tester, find.byKey(const Key('palette-search')));
      expect(find.text('Blok ara'), findsOneWidget, reason: 'the hint, in Turkish');

      await tester.enterText(find.byType(TextField), 'döngü');
      await tester.pumpAndSettle();
      expect(_chip('WHILE'), findsOneWidget);
      expect(_chip('IF'), findsNothing);
      // FOR (SAYARAK DÖNGÜ) matches the query too, but the puzzle does not allow it.
      expect(BlockSearch.matches(BlockIds.ctrlForRange, 'döngü'), isTrue);
      expect(_chip('FOR'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('“zzz” ile eşleşen blok yok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing the search brings the categories and every block back', (tester) async {
      await openEditor(tester, _puzzle());
      await tapVisible(tester, find.byKey(const Key('palette-search')));
      await tester.enterText(find.byType(TextField), 'return');
      await tester.pumpAndSettle();
      expect(_chip('IF'), findsNothing);
      expect(_chip('ALL'), findsNothing, reason: 'the search box takes the category row');

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(_chip('ALL'), findsOneWidget);
      expect(_chip('IF'), findsOneWidget);
    });

    testWidgets('the side rail on a wide screen searches too', (tester) async {
      await openEditor(tester, _puzzle(), width: 1000, height: 700);
      await tapVisible(tester, find.byKey(const Key('palette-search')));
      await tester.enterText(find.byType(TextField), 'append');
      await tester.pumpAndSettle();
      expect(_chip('APPEND'), findsOneWidget);
      expect(_chip('WHILE'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('picker search', () {
    testWidgets('a name narrows the typed list; picking places the piece', (tester) async {
      await openEditor(tester, _puzzle());
      await tapVisible(tester, find.text('add step'));
      expect(find.byType(TextField), findsNothing);
      expect(inSheet(find.text('IF')), findsOneWidget);
      expect(inSheet(find.text('WHILE')), findsOneWidget);

      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ret');
      await tester.pumpAndSettle();
      expect(inSheet(find.text('RETURN')), findsOneWidget);
      expect(inSheet(find.text('IF')), findsNothing);
      expect(inSheet(find.text('CONTROL')), findsOneWidget, reason: 'the category heading of the hit');
      expect(inSheet(find.text('VALUES')), findsNothing, reason: 'no heading for a category without hits');

      await tester.tap(inSheet(find.text('RETURN')));
      await tester.pumpAndSettle();
      final c = editorOf(tester);
      expect(c.graph.blocks[c.graph.entryIds.single]!.catalogId, BlockIds.ctrlReturn);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the picker still lists only what fits: a variable is found by its name', (tester) async {
      await openEditor(tester, _puzzle());
      await tapVisible(tester, find.text('add step'));
      await tapVisible(tester, inSheet(find.text('RETURN')));
      await tapVisible(tester, find.bySemanticsLabel('Empty value slot'));
      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'tot');
      await tester.pumpAndSettle();
      expect(inSheet(find.text('total')), findsOneWidget);
      expect(inSheet(find.text('i')), findsNothing);

      // WHILE is allowed by the puzzle but is not a value: search cannot bring it in.
      await tester.enterText(find.byType(TextField), 'while');
      await tester.pumpAndSettle();
      expect(inSheet(find.text('WHILE')), findsNothing);
      expect(find.text('No block matches “while”.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'artı');
      await tester.pumpAndSettle();
      expect(inSheet(find.text('PLUS')), findsOneWidget, reason: 'the Turkish name of PLUS');
    });

    testWidgets('closing the sheet with a query typed still lets go of the slot', (tester) async {
      await openEditor(tester, _puzzle());
      await tapVisible(tester, find.text('add step'));
      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'wh');
      await tester.pumpAndSettle();
      expect(editorOf(tester).activeHole, PortRef.mainBody);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(editorOf(tester).activeHole, isNull);
      expect(editorOf(tester).graph.blocks, isEmpty);
    });

    testWidgets('with the keyboard up the sheet sits above it, without overflow', (tester) async {
      await openEditor(tester, _puzzle());
      await tapVisible(tester, find.text('add step'));
      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(800 - 300));
      expect(field.top, greaterThanOrEqualTo(24));
      await tester.enterText(find.byType(TextField), 'if');
      await tester.pumpAndSettle();
      final hit = tester.getRect(inSheet(find.text('IF')));
      expect(hit.bottom, lessThanOrEqualTo(800 - 300), reason: 'the result is above the keyboard');
    });

    testWidgets('at the largest font the search sheet still fits a 360 × 640 phone', (tester) async {
      await openEditor(tester, _puzzle(), height: 640, textScale: 1.6, dark: false);
      await tapVisible(tester, find.text('add step'));
      await tester.tap(find.byKey(const Key('picker-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
