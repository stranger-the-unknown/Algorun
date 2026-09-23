import 'dart:io';

import 'package:algorun/dev/stress_probe.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone.dart';
import 'support/progress_fixtures.dart';

/// The MS13 editor stress probe: a long, deep program (82 blocks, two nested
/// WHILE loops, IF / ELSE three deep, a map, two lists, IS NOTHING, a long
/// name) edited on a 360 × 800 phone.
final _puzzle = parsePuzzleJson(File('assets/puzzles/world_01/$stressProbeId.json').readAsStringSync());

EditorController _built() {
  final c = EditorController(puzzle: _puzzle);
  buildStressProgram(c);
  return c;
}

/// Saves what the screen would save.
final class _Hooks implements PuzzleSaveHooks {
  BlockGraph? draft;
  bool? lastEdited;

  @override
  void graphChanged(BlockGraph graph, {bool edited = true}) {
    draft = graph;
    lastEdited = edited;
  }

  @override
  RunRecordOutcome runFinished(BlockGraph graph, SuiteResult suite) => const RunRecordOutcome();
  @override
  void leaving() {}
  @override
  BlockGraph? bestSolution() => null;
  @override
  bool get solved => false;
  @override
  NextPuzzle? next() => null;
}

Future<void> _open(WidgetTester tester, {BlockGraph? initial, PuzzleSaveHooks? hooks}) async {
  usePhone(tester, 360, 800);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: PuzzleEditor(puzzle: _puzzle, initialGraph: initial, save: hooks, briefOpen: false),
      routes: {'/results': (_) => const ResultsScreen()},
    ),
  ));
  await tester.pumpAndSettle();
}

final _script = find.byType(ScriptView);
Finder _inScript(String text) => find.descendant(of: _script, matching: find.text(text));
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));
String _count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('block-count'))).data!;

/// The IF x > 0 three levels down.
String _innermostIf(EditorController c) => c.graph.blocks.values
    .firstWhere((b) =>
        b.catalogId == BlockIds.ctrlIf &&
        c.graph.blocks[c.graph.slotList(b.id, 'condition').single]!.catalogId == BlockIds.cmpGt)
    .id;

void main() {
  test('the program is built through typed placement, runs correct, and matches its reference file', () {
    final c = _built();
    expect(c.blockCount, 82);
    expect(c.subtreeOf(c.graph.entryIds[6]).length, greaterThanOrEqualTo(60), reason: 'the outer WHILE');
    final outcome = runPuzzle(const DefaultEngine(), c.graph, _puzzle);
    expect(outcome.suite.kind, ResultKind.correct);
    expect(outcome.suite.metrics.ops, 2955);
    expect(graphText(c.graph), graphText(referenceSolution('world_01', stressProbeId)),
        reason: 'the content pipeline checks the same program');
  });

  testWidgets('on a 360 × 800 phone: scroll, select, delete, undo, redo', (tester) async {
    await _open(tester);
    expect(tester.takeException(), isNull);
    expect(_count(tester), '82 / 120 blocks');

    await tester.scrollUntilVisible(_inScript('RETURN'), 300, scrollable: find.byType(Scrollable).first);
    expect(_inScript('RETURN').hitTestable(), findsOneWidget);

    await tester.tap(_inScript('RETURN'));
    await tester.pumpAndSettle();
    expect(find.text('SELECTED'), findsOneWidget);
    expect(find.text('RETURN · 7 blocks'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete it and the 6 blocks inside'));
    await tester.pumpAndSettle();
    expect(_count(tester), '75 / 120 blocks');
    expect(find.text('Removed RETURN and 6 blocks inside. UNDO brings them back.'), findsOneWidget);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(_count(tester), '82 / 120 blocks');
    expect(find.textContaining('UNDO brings'), findsNothing);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    expect(_count(tester), '75 / 120 blocks');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep insertion: the picker for the innermost IF offers instructions only and reveals the result',
      (tester) async {
    final ids = _built();
    final target = _innermostIf(ids);
    await _open(tester);
    final addStep = find.byKey(ValueKey('add-step:$target.then'));
    await tester.scrollUntilVisible(addStep, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(addStep);
    await tester.pumpAndSettle();
    await tester.tap(addStep);
    await tester.pumpAndSettle();
    expect(_inSheet('Choose a piece'), findsOneWidget);
    expect(find.textContaining('For THEN of IF.'), findsOneWidget);
    expect(_inSheet('SET'), findsOneWidget);
    expect(_inSheet('PLUS'), findsNothing, reason: 'values do not fit an instruction list');
    expect(_inSheet('ELSE'), findsNothing, reason: 'ELSE fits only the IF else port');

    await tester.tap(_inSheet('SET'));
    await tester.pumpAndSettle();
    expect(_inSheet('Choose a name'), findsOneWidget);
    await tester.tap(_inSheet('odds').first);
    await tester.pumpAndSettle();
    expect(_count(tester), '83 / 120 blocks');
    expect(find.text('SET odds'), findsOneWidget, reason: 'the new block is selected');
    expect(find.byKey(ValueKey('add-step:$target.then')).hitTestable(), findsOneWidget,
        reason: 'the edited list stays on screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('fold every block, unfold one, and the folds survive a save and restore', (tester) async {
    final hooks = _Hooks();
    await _open(tester, hooks: hooks);
    await tester.tap(find.byTooltip('Program options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fold every block'));
    await tester.pumpAndSettle();
    final folded = find.textContaining('Folded ·');
    await tester.scrollUntilVisible(folded, 200, scrollable: find.byType(Scrollable).first);
    expect(folded, findsOneWidget, reason: 'the outer WHILE folds everything inside it');
    expect(hooks.lastEdited, isFalse, reason: 'folding is saved, but is not an edit');
    final saved = hooks.draft!;
    expect(saved.blocks.values.where((b) => b.collapsed), isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    await _open(tester, initial: reloaded(PlayerSave.fresh.withPuzzle(
      stressProbeId,
      PuzzleProgress(puzzleVersion: 1, draft: saved),
    ))[stressProbeId]!.draft);
    await tester.scrollUntilVisible(folded, 200, scrollable: find.byType(Scrollable).first);
    expect(folded, findsOneWidget, reason: 'restored folded');
    expect(_count(tester), '82 / 120 blocks');
    final outer = tester.widget<Text>(folded).data!;
    await tester.ensureVisible(folded);
    await tester.pumpAndSettle();
    await tester.tap(folded);
    await tester.pumpAndSettle();
    expect(find.text(outer), findsNothing, reason: 'one tap on the summary unfolds');
    expect(find.textContaining('Folded ·'), findsWidgets, reason: 'the blocks inside stay folded');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('back first lets go of the selection', (tester) async {
    await _open(tester);
    await tester.scrollUntilVisible(_inScript('RETURN'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(_inScript('RETURN'));
    await tester.pumpAndSettle();
    expect(find.text('SELECTED'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('SELECTED'), findsNothing);
    expect(find.byType(PuzzleEditor), findsOneWidget);
  });

  testWidgets('an edit on the 82-block program rebuilds quickly', (tester) async {
    await _open(tester);
    await tester.scrollUntilVisible(_inScript('RETURN'), 300, scrollable: find.byType(Scrollable).first);
    final watch = Stopwatch()..start();
    await tester.tap(_inScript('RETURN'));
    await tester.pump();
    await tester.tap(find.byTooltip('Undo'), warnIfMissed: false);
    await tester.pump();
    watch.stop();
    // Debug-mode widget test timing: a loose guard against a pathological
    // rebuild, not a frame budget (device numbers are in MILESTONE_13.md).
    expect(watch.elapsedMilliseconds, lessThan(1500));
    // ignore: avoid_print
    print('stress probe: select + undo rebuild ${watch.elapsedMilliseconds} ms');
  });
}
