import 'dart:io';

import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L1 in the editor: the bundled chain probe, built tap by tap.
Puzzle _chainProbe() => parsePuzzleJson(
      File('assets/puzzles/world_01/l1_list_probe.json').readAsStringSync(),
    );

/// Places `count = 0; node = head; WHILE node IS NOT NOTHING { count = count
/// + 1; node = NEXT NODE node }; RETURN count` the way a player would. Returns
/// the NEXT NODE block, whose node hole is left empty when [fillNext] is false.
({EditorController controller, String whileId, String next}) _build({bool fillNext = true, bool check = true}) {
  final c = EditorController(puzzle: _chainProbe());
  c.declareVariable('node', ValueType.listNode.asNullable);
  c.declareVariable('count', ValueType.number);

  String place(String catalogId, PortRef to, {Map<String, Object?> literals = const {}}) {
    final id = c.place(Placement(catalogId: catalogId, literals: literals), to: to);
    expect(id, isNotNull, reason: '$catalogId into $to');
    return id!;
  }

  final setCount = place(BlockIds.varSet, PortRef.mainBody, literals: {'name': 'count'});
  place(BlockIds.litNum, PortRef(setCount, 'value'), literals: {'value': 0});
  final setNode = place(BlockIds.varSet, PortRef.mainBody, literals: {'name': 'node'});
  place(BlockIds.varGet, PortRef(setNode, 'value'), literals: {'name': 'head'});
  final loop = place(BlockIds.ctrlWhile, PortRef.mainBody);
  if (check) {
    final isNot = place(BlockIds.logicIsNotNothing, PortRef(loop, 'condition'));
    place(BlockIds.varGet, PortRef(isNot, 'value'), literals: {'name': 'node'});
  }
  final step = place(BlockIds.varSet, PortRef(loop, 'body'), literals: {'name': 'count'});
  final plus = place(BlockIds.arithAdd, PortRef(step, 'value'));
  place(BlockIds.varGet, PortRef(plus, 'left'), literals: {'name': 'count'});
  place(BlockIds.litNum, PortRef(plus, 'right'), literals: {'value': 1});
  final advance = place(BlockIds.varSet, PortRef(loop, 'body'), literals: {'name': 'node'});
  final next = place(BlockIds.llNext, PortRef(advance, 'value'));
  if (fillNext) place(BlockIds.varGet, PortRef(next, 'node'), literals: {'name': 'node'});
  final ret = place(BlockIds.ctrlReturn, PortRef.mainBody);
  place(BlockIds.varGet, PortRef(ret, 'value'), literals: {'name': 'count'});
  return (controller: c, whileId: loop, next: next);
}

List<Object?> _names(EditorController c, PortRef hole) => [
      for (final p in c.placementsFor(hole))
        if (p.catalogId == BlockIds.varGet) p.literals['name'],
    ];

Future<void> _show(WidgetTester tester, EditorController c) async {
  // Tall enough that the whole script is built.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: c,
        builder: (_, _) => Scaffold(body: ScriptView(controller: c)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a player builds the chain walk tap by tap, and RUN solves it', () {
    final built = _build();
    final outcome = runPuzzle(const DefaultEngine(), built.controller.graph, built.controller.puzzle);
    expect(outcome.suite.kind, ResultKind.correct, reason: outcome.suite.message);
    expect(outcome.suite.hiddenSummary!.allPassed, isTrue);
  });

  test('inside WHILE node IS NOT NOTHING the picker offers node for NEXT NODE; without the check it does not', () {
    final checked = _build(fillNext: false);
    expect(_names(checked.controller, PortRef(checked.next, 'node')), contains('node'));

    final unchecked = _build(fillNext: false, check: false);
    final names = _names(unchecked.controller, PortRef(unchecked.next, 'node'));
    expect(names, isNot(contains('node')));
    expect(names, isNot(contains('head')));
  });

  test('the check only takes a value that may be empty', () {
    final c = _build(check: false, fillNext: false).controller;
    final loop = c.graph.entryIds[2];
    final check = c.place(const Placement(catalogId: BlockIds.logicIsNotNothing), to: PortRef(loop, 'condition'))!;
    final names = _names(c, PortRef(check, 'value'));
    expect(names, containsAll(['node', 'head']));
    expect(names, isNot(contains('count')));
  });

  test('a step moved above a read is caught before RUN, in game words', () {
    final c = EditorController(puzzle: _chainProbe());
    c.declareVariable('node', ValueType.listNode.asNullable);
    c.declareVariable('count', ValueType.number);
    String place(String catalogId, PortRef to, {Map<String, Object?> literals = const {}, int? index}) =>
        c.place(Placement(catalogId: catalogId, literals: literals), to: to, index: index)!;

    final setNode = place(BlockIds.varSet, PortRef.mainBody, literals: {'name': 'node'});
    place(BlockIds.varGet, PortRef(setNode, 'value'), literals: {'name': 'head'});
    final loop = place(BlockIds.ctrlWhile, PortRef.mainBody);
    final check = place(BlockIds.logicIsNotNothing, PortRef(loop, 'condition'));
    place(BlockIds.varGet, PortRef(check, 'value'), literals: {'name': 'node'});
    // count = NODE VALUE node: fine while nothing above it changes node.
    final read = place(BlockIds.varSet, PortRef(loop, 'body'), literals: {'name': 'count'});
    final value = place(BlockIds.llValue, PortRef(read, 'value'));
    place(BlockIds.varGet, PortRef(value, 'node'), literals: {'name': 'node'});
    // Now the player puts node = NEXT NODE node above the read.
    final step = place(BlockIds.varSet, PortRef(loop, 'body'), literals: {'name': 'node'}, index: 0);
    final next = place(BlockIds.llNext, PortRef(step, 'value'));
    place(BlockIds.varGet, PortRef(next, 'node'), literals: {'name': 'node'});
    final ret = place(BlockIds.ctrlReturn, PortRef.mainBody);
    place(BlockIds.varGet, PortRef(ret, 'value'), literals: {'name': 'count'});

    final outcome = runPuzzle(const DefaultEngine(), c.graph, c.puzzle);
    expect(outcome.suite.kind, ResultKind.invalidProgram);
    expect(outcome.suite.message, 'This value may be empty here. Check that it is not empty first.');
    expect(outcome.suite.firstFailureBlockId, value);
  });

  testWidgets('the loop reads as IS NOT NOTHING, with no ids, symbols or text fields', (tester) async {
    await _show(tester, _build().controller);
    expect(find.text('IS NOT NOTHING'), findsOneWidget);
    expect(find.text('NEXT NODE'), findsOneWidget);
    expect(find.text('WHILE'), findsOneWidget);
    for (final hidden in ['logic.is_not_nothing', 'listNode', 'null', '?', '!']) {
      expect(find.textContaining(hidden), findsNothing, reason: hidden);
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('the condition picker offers both checks', (tester) async {
    await _show(tester, _build(check: false, fillNext: false).controller);
    await tester.tap(find.text('condition'));
    await tester.pumpAndSettle();
    for (final label in ['IS NOTHING', 'IS NOT NOTHING']) {
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(label)), findsOneWidget);
    }
  });
}
