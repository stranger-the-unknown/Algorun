import 'dart:io';

import 'package:algorun/dev/stress_probe.dart';
import 'package:algorun/editor/block_text.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/program_outline.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/editor_harness.dart';
import 'support/progress_fixtures.dart';

/// E1: finding your way in a long program. The outline lists every
/// instruction on one numbered line; START and END jump to the two ends.
final _stress = parsePuzzleJson(File('assets/puzzles/world_01/$stressProbeId.json').readAsStringSync());

EditorController _built() {
  final c = EditorController(puzzle: _stress);
  buildStressProgram(c);
  c.markBaseline();
  return c;
}

void main() {
  group('BlockText', () {
    test('an instruction reads the way the editor lays it out', () {
      final c = _built();
      final lines = programOutline(c.graph).map((line) => line.text).toList();
      expect(lines.first, 'SET counts TO NEW MAP');
      expect(lines, contains('WHILE i LESS THAN (readings LENGTH)'));
      expect(lines, contains('SET x TO readings GET ELEMENT i'));
      expect(lines, contains('PUT counts x (c PLUS 1)'));
      expect(lines, contains('IF c IS NOTHING'));
      expect(lines, contains('IF (x REMAINDER 2) EQUAL 0'));
      expect(lines, contains('INCREMENT echoes'));
      expect(lines, contains('ELSE'));
      expect(lines.last, 'RETURN (echoes PLUS running_total_of_even_readings) PLUS (odds LENGTH)');
    });

    test('an empty slot shows as a gap, FOR and FOR EACH keep their words, a FUNCTION its parameters', () {
      final c = EditorController(puzzle: shippedPuzzle('world_01', 'hill_tops'));
      final loop = c.place(const Placement(catalogId: BlockIds.ctrlForRange, literals: {'name': 'i'}), to: PortRef.mainBody)!;
      expect(BlockText.line(c.graph, loop), 'FOR i FROM … TO … BY …');
      final each = EditorController(puzzle: shippedPuzzle('world_01', 'warm_readings'));
      final id = each.place(const Placement(catalogId: BlockIds.ctrlForEach), to: PortRef.mainBody)!;
      expect(BlockText.line(each.graph, id), 'FOR EACH IN …');
      final coins = EditorController(puzzle: shippedCampaign().puzzles['coin_stack']!);
      expect(BlockText.line(coins.graph, 'fn_sum_from'), startsWith('FUNCTION sum_from ('));
    });

    test('every block of every shipped reference reads as a line without throwing', () {
      final campaign = shippedCampaign();
      var lines = 0;
      for (final world in campaign.manifest.worlds) {
        for (final id in world.puzzleIds) {
          final graph = referenceSolution(world.id, id);
          final outline = programOutline(graph);
          lines += outline.length;
          for (final line in outline) {
            expect(line.text, isNotEmpty, reason: '$id ${line.blockId}');
            expect(line.text, isNot(contains('BLOCK')), reason: '$id: every block has its own name');
          }
          final numbered = outline.where((line) => line.number != null).toList();
          expect(numbered.map((line) => line.number), List.generate(numbered.length, (i) => i + 1));
          // Every instruction of the program is a line, once.
          final c = EditorController(puzzle: campaign.puzzles[id]!, initialGraph: graph);
          final statements = graph.blocks.keys
              .where((b) => c.isStatement(b) && graph.blocks[b]!.catalogId != BlockIds.ctrlElse)
              .toSet();
          expect(numbered.map((line) => line.blockId).toSet(), statements, reason: id);
        }
      }
      expect(lines, greaterThan(1500));
    });
  });

  group('the outline', () {
    test('numbers instructions from the top; depth follows the nesting; ELSE has no number', () {
      final c = _built();
      final outline = programOutline(c.graph);
      expect(outline.first.number, 1);
      expect(outline.first.depth, 0);
      final loop = outline.firstWhere((line) => line.text.startsWith('WHILE i'));
      expect(loop.number, 7);
      expect(outline[outline.indexOf(loop) + 1].depth, 1);
      final deepest = outline.firstWhere((line) => line.text == 'INCREMENT echoes');
      expect(deepest.depth, 4);
      final elses = outline.where((line) => line.number == null).toList();
      expect(elses, hasLength(2));
      for (final line in elses) {
        expect(c.graph.blocks[line.blockId]!.catalogId, BlockIds.ctrlIf, reason: 'an ELSE row goes to its IF');
      }
      expect(outline.where((line) => line.number != null).length,
          c.graph.blocks.keys.where((b) => c.isStatement(b) && c.graph.blocks[b]!.catalogId != BlockIds.ctrlElse).length);
    });

    test('folds do not hide lines, and going to a line unfolds what is around it', () {
      final c = _built();
      final before = programOutline(c.graph).length;
      c.collapseAll();
      final outline = programOutline(c.graph);
      expect(outline, hasLength(before));
      final deep = outline.firstWhere((line) => line.text == 'INCREMENT echoes').blockId;
      final graph = c.graph;
      c.jumpTo(deep);
      expect(c.selectedBlockId, deep);
      expect(c.ancestorsOf(deep).any(c.isCollapsed), isFalse);
      expect(c.revealId, deep);
      expect(identical(c.graph, graph), isTrue, reason: 'going somewhere is not an edit');
      expect(c.canUndo, isFalse);
    });

    test('scrolling to a place does not touch the selection', () {
      final c = _built();
      final first = c.graph.entryIds.first;
      final last = c.graph.entryIds.last;
      c.selectBlock(last);
      c.scrollTo(first);
      expect(c.selectedBlockId, last);
      expect(c.revealId, first);
      c.scrollToEnd();
      expect(c.selectedBlockId, last);
      expect(c.revealId, EditorController.endOfProgram);
      final empty = EditorController(puzzle: _stress, initialGraph: BlockGraph(blocks: const {}, variables: const {}));
      empty.scrollToEnd();
      expect(empty.revealId, isNull, reason: 'an empty program has no end to go to');
    });
  });

  group('on a 360 × 800 phone', () {
    ScrollPosition position(WidgetTester tester) => tester.state<ScrollableState>(scriptScrollable).position;

    Future<void> openOutline(WidgetTester tester, {String tooltip = 'Program outline'}) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    }

    testWidgets('END goes to the last instruction and the add step under it; START comes back', (tester) async {
      await openEditor(tester, _stress);
      final c = editorOf(tester);
      final pos = position(tester);
      expect(pos.pixels, 0);

      await openOutline(tester);
      await tester.tap(find.byKey(const Key('outline-end')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(pos.pixels, greaterThan(1500), reason: 'a long way down');
      expect(find.byKey(const ValueKey('add-step:main')).hitTestable(), findsOneWidget);
      expect(inScript('RETURN').hitTestable(), findsOneWidget);
      expect(c.selectedBlockId, isNull, reason: 'going there selects nothing');
      expect(c.revealId, isNull, reason: 'the jump is done');
      final end = pos.pixels;

      await openOutline(tester);
      await tester.tap(find.byKey(const Key('outline-start')));
      await tester.pumpAndSettle();
      expect(pos.pixels, lessThan(end - 1500));
      final first = c.graph.entryIds.first;
      expect(find.byKey(ValueKey(first)).hitTestable(), findsOneWidget);
      expect(find.text('PROGRAM').hitTestable(), findsOneWidget, reason: 'the start of the program, not of the page');
      expect(c.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a line takes you to its block: selected, on screen, unfolded', (tester) async {
      await openEditor(tester, _stress);
      final c = editorOf(tester);
      c.collapseAll();
      await tester.pumpAndSettle();
      expect(inScript('INCREMENT'), findsNothing);

      await openOutline(tester);
      final outline = programOutline(c.graph);
      final line = outline.firstWhere((l) => l.text == 'INCREMENT echoes');
      expect(inSheet(find.text('SET counts TO NEW MAP')), findsOneWidget);
      expect(inSheet(find.text('1')), findsOneWidget);
      final row = find.byKey(ValueKey('outline-line:${line.number}'));
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(c.selectedBlockId, line.blockId);
      expect(c.ancestorsOf(line.blockId).any(c.isCollapsed), isFalse);
      final tile = find.descendant(of: find.byType(ScriptView), matching: find.text('echoes'));
      expect(tile.hitTestable(), findsWidgets);
      expect(find.text('SELECTED'), findsOneWidget);

      // The sheet opens again on the selected line.
      await openOutline(tester);
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.getSemantics(row), isSemantics(isSelected: true, hasSelectedState: true));
    }, semanticsEnabled: true);

    testWidgets('the longest program: 160 blocks on numbered lines, in Turkish', (tester) async {
      final puzzle = shippedPuzzle('world_09', 'cheapest_crossing');
      await openEditor(tester, puzzle,
          initial: referenceSolution('world_09', 'cheapest_crossing'), language: 'tr', dark: false);
      final c = editorOf(tester);
      expect(c.blockCount, greaterThan(150));
      final outline = programOutline(c.graph);
      await openOutline(tester, tooltip: 'Program özeti');
      expect(inSheet(find.text('Program özeti')), findsOneWidget);
      expect(inSheet(find.text('BAŞ')), findsOneWidget);
      expect(inSheet(find.text('SON')), findsOneWidget);
      expect(find.byTooltip('Programın başına git'), findsOneWidget);
      expect(find.byTooltip('Programın sonuna git'), findsOneWidget);
      final last = outline.lastWhere((l) => l.number != null);
      final row = find.byKey(ValueKey('outline-line:${last.number}'));
      await tester.scrollUntilVisible(row, 400,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(row).label, 'Satır ${last.number}: ${last.text}');
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(c.selectedBlockId, last.blockId);
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: true);

    testWidgets('at the largest font on a 360 × 640 phone the outline still lays out', (tester) async {
      await openEditor(tester, shippedPuzzle('world_09', 'cheapest_crossing'),
          initial: referenceSolution('world_09', 'cheapest_crossing'), height: 640, textScale: 1.6);
      final c = editorOf(tester);
      await openOutline(tester);
      expect(tester.takeException(), isNull);
      final outline = programOutline(c.graph);
      final deepest = outline.reduce((a, b) => b.depth > a.depth ? b : a);
      final row = find.byKey(ValueKey('outline-line:${deepest.number}'));
      await tester.scrollUntilVisible(row, 300,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48), reason: 'rows grow with the font');
    });

    testWidgets('an empty program: the outline says so and has nowhere to go', (tester) async {
      await openEditor(tester, shippedPuzzle('world_01', 'warm_readings'));
      await openOutline(tester);
      expect(inSheet(find.text('The program is empty.')), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('outline-start'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('outline-end'))).onPressed, isNull);
    });
  });
}
