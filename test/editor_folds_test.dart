import 'dart:convert';

import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/l10n/terms.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/editor_harness.dart';
import 'support/progress_fixtures.dart';

/// E1: folding the body of IF / WHILE / FOR / FOR EACH / FUNCTION, on the
/// longest programs the game has. A fold says how many blocks it hides and
/// never changes what the program is or does.
const _programs = [
  ('world_09', 'cheapest_crossing'), // the longest reference: WHILE, IF / ELSE, heaps
  ('world_12', 'maze_paths'), // FUNCTION, recursion
  ('world_12', 'seating_plan'), // FUNCTION
  ('world_01', 'hill_tops'), // FOR
  ('world_01', 'warm_readings'), // FOR EACH
];

EditorController _open(String world, String id) =>
    EditorController(puzzle: shippedPuzzle(world, id), initialGraph: referenceSolution(world, id));

String _ir(Puzzle puzzle, BlockGraph graph) =>
    jsonEncode(const DefaultEngine().lower(graph, puzzle).program!.toJson());

void main() {
  test('the programs under test cover every block that has a body', () {
    final kinds = {
      for (final (world, id) in _programs)
        for (final b in _open(world, id).cBlockIds.map((b) => referenceSolution(world, id).blocks[b]!)) b.catalogId,
    };
    expect(
      kinds,
      containsAll([BlockIds.ctrlIf, BlockIds.ctrlWhile, BlockIds.ctrlForRange, BlockIds.ctrlForEach, BlockIds.fnDef]),
    );
    expect(_open('world_09', 'cheapest_crossing').blockCount, greaterThan(150));
  });

  for (final (world, id) in _programs) {
    test('$id: folded or not, it is the same program and runs the same', () {
      final c = _open(world, id);
      final open = runPuzzle(const DefaultEngine(), c.graphForSave, c.puzzle);
      final ir = _ir(c.puzzle, c.graphForSave);
      final count = c.blockCount;
      final text = graphText(c.graphForSave);
      expect(open.suite.kind, ResultKind.correct);

      c.collapseAll();
      expect(c.cBlockIds, isNotEmpty);
      expect(c.cBlockIds.every(c.isCollapsed), isTrue);
      expect(c.canUndo, isFalse, reason: 'folding is never an undo step');
      expect(c.blockCount, count, reason: 'hidden blocks still count against the budget');
      final saved = c.graphForSave;
      expect(saved.blocks.values.where((b) => b.collapsed).map((b) => b.id).toSet(), c.cBlockIds.toSet());
      expect(_ir(c.puzzle, saved), ir, reason: 'the lowered program does not know about folds');
      final folded = runPuzzle(const DefaultEngine(), saved, c.puzzle);
      expect(folded.suite.kind, ResultKind.correct);
      expect(folded.suite.metrics.ops, open.suite.metrics.ops);
      expect(folded.suite.metrics.blocks, open.suite.metrics.blocks);

      // A restart restores the folds from the saved program.
      final restored = EditorController(puzzle: c.puzzle, initialGraph: BlockGraph.fromJson(saved.toJson()));
      expect(restored.collapsedIds, c.collapsedIds);
      restored.expandAll();
      expect(graphText(restored.graphForSave), text, reason: 'unfolded, it is the program it was');
    });
  }

  test('a fold says how many blocks it hides: everything inside, values included', () {
    final c = _open('world_09', 'cheapest_crossing');
    for (final b in c.cBlockIds) {
      expect(c.hiddenCount(b), c.subtreeOf(b).length - 1);
    }
    final outer = c.cBlockIds.reduce((a, b) => c.hiddenCount(a) >= c.hiddenCount(b) ? a : b);
    expect(c.hiddenCount(outer), greaterThanOrEqualTo(100));
    expect(englishStrings.foldedInside(blocksText(c.hiddenCount(outer), englishStrings)),
        'Folded · ${c.hiddenCount(outer)} blocks inside');
  });

  test('folding never leaves the selection on a hidden block', () {
    final c = _open('world_09', 'cheapest_crossing');
    // A block two levels down.
    final deep = c.graph.blocks.keys.firstWhere((b) => c.isStatement(b) && c.ancestorsOf(b).length >= 2);
    final holders = c.ancestorsOf(deep).where((a) => EditorController.isCBlock(c.graph.blocks[a]!.catalogId)).toList();
    expect(holders.length, greaterThanOrEqualTo(2));

    c.selectBlock(deep);
    c.toggleCollapsed(holders.first);
    expect(c.selectedBlockId, holders.first, reason: 'the folded block takes the selection');
    c.toggleCollapsed(holders.first);
    c.selectBlock(deep);
    c.collapseAll();
    expect(c.selectedBlockId, holders.last, reason: 'the outermost folded block');

    // Folding something else leaves the selection alone.
    c.expandAll();
    c.selectBlock(holders.last);
    c.toggleCollapsed(holders.first);
    expect(c.selectedBlockId, holders.last);
    expect(c.canUndo, isFalse);
  });

  group('on a 360 × 800 phone', () {
    Future<EditorController> open(WidgetTester tester, String world, String id, {String? language}) async {
      await openEditor(tester, shippedPuzzle(world, id), initial: referenceSolution(world, id), language: language);
      return editorOf(tester);
    }

    Future<void> foldAll(WidgetTester tester, {String menu = 'Program options', String item = 'Fold every block'}) async {
      await tester.tap(find.byTooltip(menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    for (final (world, id, label, kind) in [
      ('world_09', 'cheapest_crossing', 'WHILE', BlockIds.ctrlWhile),
      ('world_09', 'cheapest_crossing', 'IF', BlockIds.ctrlIf),
      ('world_01', 'hill_tops', 'FOR', BlockIds.ctrlForRange),
      ('world_01', 'warm_readings', 'FOR EACH', BlockIds.ctrlForEach),
      ('world_12', 'maze_paths', 'FUNCTION', BlockIds.fnDef),
    ]) {
      testWidgets('$label ($id) folds to one line with its count, and opens again', (tester) async {
        final c = await open(tester, world, id);
        // The first block of this kind that holds something, top-down.
        final block = c.graph.blocks.keys.firstWhere(
          (b) => c.graph.blocks[b]!.catalogId == kind && c.hiddenCount(b) > 1 && c.ancestorsOf(b).isEmpty,
          orElse: () =>
              c.graph.blocks.keys.firstWhere((b) => c.graph.blocks[b]!.catalogId == kind && c.hiddenCount(b) > 1),
        );
        final ir = _ir(c.puzzle, c.graphForSave);
        final count = tester.widget<Text>(find.byKey(const Key('block-count'))).data;

        c.selectBlock(block); // reveals nothing by itself; scroll to it
        await tester.pumpAndSettle();
        final header = find.byKey(ValueKey('fold:$block'));
        await tester.scrollUntilVisible(header, 200, scrollable: scriptScrollable);
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(header).tooltip, 'Collapse');
        await tester.tap(header);
        await tester.pumpAndSettle();

        expect(c.isCollapsed(block), isTrue);
        expect(tester.widget<IconButton>(header).tooltip, 'Expand');
        final summary = find.text('Folded · ${c.hiddenCount(block)} blocks inside');
        expect(summary, findsOneWidget);
        expect(find.byKey(ValueKey('add-step:$block.${kind == BlockIds.ctrlIf ? 'then' : 'body'}')), findsNothing,
            reason: 'the body is not on screen');
        expect(tester.widget<Text>(find.byKey(const Key('block-count'))).data, count);
        expect(_ir(c.puzzle, c.graphForSave), ir);
        expect(find.byTooltip('Undo').hitTestable(), findsOneWidget);
        expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo)).onPressed, isNull,
            reason: 'nothing to undo: a fold is not an edit');

        await tester.tap(summary);
        await tester.pumpAndSettle();
        expect(c.isCollapsed(block), isFalse);
        expect(summary, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the longest program folds to a handful of lines and still runs', (tester) async {
      final c = await open(tester, 'world_09', 'cheapest_crossing');
      await foldAll(tester);
      expect(c.cBlockIds.every(c.isCollapsed), isTrue);
      // Every top-level instruction is now built at once: the program is short.
      for (final b in c.graph.entryIds) {
        final block = c.graph.blocks[b]!;
        if (!EditorController.isCBlock(block.catalogId)) continue;
        await tester.scrollUntilVisible(find.byKey(ValueKey('fold:$b')), 200, scrollable: scriptScrollable);
        expect(find.text('Folded · ${c.hiddenCount(b)} blocks inside'), findsWidgets);
      }
      expect(runPuzzle(const DefaultEngine(), c.graphForSave, c.puzzle).suite.kind, ResultKind.correct);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Turkish', (tester) async {
      final c = await open(tester, 'world_01', 'warm_readings', language: 'tr');
      await foldAll(tester, menu: 'Program seçenekleri', item: 'Tüm blokları katla');
      final loop = c.graph.entryIds.firstWhere((b) => EditorController.isCBlock(c.graph.blocks[b]!.catalogId));
      expect(find.text('Katlı · içinde ${c.hiddenCount(loop)} blok'), findsOneWidget);
      expect(find.byTooltip('Aç'), findsWidgets);
    });
  });
}
