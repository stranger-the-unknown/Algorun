import 'dart:io';

import 'package:algorun/editor/palette_tray.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone.dart';

/// Arrays → Second Highest. The IFs under test are added inside FOR EACH,
/// not on the program's main list.
final _puzzle = parsePuzzleJson(
  File('assets/puzzles/world_02/second_highest.json').readAsStringSync(),
);

Finder _sheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

BlockGraph _graph(WidgetTester tester) =>
    tester.widget<ScriptView>(find.byType(ScriptView)).controller.graph;

Future<void> _open(WidgetTester tester) async {
  usePhone(tester, 360, 800);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(AppPalette.dark),
      home: PuzzleEditor(puzzle: _puzzle, briefOpen: false),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  final target = finder.hitTestable();
  if (target.evaluate().isEmpty) {
    final sheet = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable));
    final script = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable));
    final scrollable = sheet.evaluate().isNotEmpty ? sheet.first : script.first;
    await tester.scrollUntilVisible(finder, 160, scrollable: scrollable);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder.hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  expect(find.byType(BottomSheet), findsOneWidget);
  await _tap(tester, _sheet(label));
}

Future<void> _pick(WidgetTester tester, String label) async {
  await _choose(tester, label);
  expect(find.byType(BottomSheet), findsNothing);
}

Future<void> _openList(WidgetTester tester, String? parent, String port, String sheet) async {
  final finder = parent == null
      ? (_graph(tester).entryIds.isEmpty
          ? find.text('add step')
          : find.byKey(const ValueKey('add-step:main')))
      : find.byKey(ValueKey('add-step:$parent.$port'));
  await _tap(tester, finder);
  expect(find.textContaining(sheet), findsOneWidget);
}

Future<String> _addForEach(WidgetTester tester) async {
  await _openList(tester, null, 'body', 'For the program.');
  await _pick(tester, 'FOR EACH');
  final loop = _graph(tester).entryIds.singleWhere(
    (id) => _graph(tester).blocks[id]?.catalogId == BlockIds.ctrlForEach,
  );
  await _tap(tester, find.text('item'));
  await _pick(tester, 'v');
  await _tap(tester, find.text('list'));
  await _pick(tester, 'values');
  return loop;
}

Future<String> _addIf(WidgetTester tester, String parent, String port, String sheet) async {
  await _openList(tester, parent, port, sheet);
  await _pick(tester, 'IF');
  return _graph(tester).slotList(parent, port).last;
}

Future<void> _setIn(WidgetTester tester, String? parent, String port, String sheet, String name, int value) async {
  await _openList(tester, parent, port, sheet);
  await _choose(tester, 'SET');
  expect(find.text('Choose a name'), findsOneWidget);
  await _tap(tester, _sheet(name));
  expect(find.byType(BottomSheet), findsNothing);
  await _number(tester, value);
}

Future<void> _number(WidgetTester tester, int value) async {
  await _tap(tester, find.text('value'));
  await _choose(tester, 'NUMBER');
  if (value != 0) await _tap(tester, find.byKey(Key('pad-$value')));
  await _tap(tester, _sheet('DONE'));
  expect(find.byType(BottomSheet), findsNothing);
}

/// `1 > 0` or `0 > 1`, tapped into the next empty condition.
Future<void> _compare(WidgetTester tester, int left, int right) async {
  await _tap(tester, find.text('condition'));
  await _pick(tester, 'GREATER THAN');
  await _number(tester, left);
  await _number(tester, right);
}

ForEachStmt _loweredLoop(BlockGraph graph) {
  final lowered = const Lowerer().lower(graph, _puzzle);
  expect(lowered.ok, isTrue, reason: '${lowered.errors}');
  final loop = lowered.program!.functions.single.body.whereType<ForEachStmt>().single;
  expect(loop.itemVar, 'v');
  return loop;
}

void main() {
  testWidgets('a FOR EACH DO button adds two and three sibling IFs', (tester) async {
    await _open(tester);
    final loop = await _addForEach(tester);
    final first = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    final second = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    final third = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');

    final graph = _graph(tester);
    expect(graph.slotList(loop, 'body'), [first, second, third]);
    for (final id in [first, second, third]) {
      expect(graph.blocks[id]?.catalogId, BlockIds.ctrlIf);
      expect(graph.parentOf(id)?.blockId, loop);
      expect(graph.parentOf(id)?.port, 'body');
      expect(graph.slotList(id, 'then'), isEmpty);
    }
    expect(graph.entryIds.where((id) => graph.blocks[id]?.catalogId == BlockIds.ctrlIf), isEmpty);
  });

  testWidgets('top true and bottom false stay siblings, lower, and return 7', (tester) async {
    await _open(tester);
    await _setIn(tester, null, 'body', 'For the program.', 'best', 0);
    final loop = await _addForEach(tester);
    final first = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    await _compare(tester, 1, 0);
    await _setIn(tester, first, 'then', 'For THEN of IF.', 'best', 7);
    final second = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    await _compare(tester, 0, 1);
    await _setIn(tester, second, 'then', 'For THEN of IF.', 'best', 9);
    await _openList(tester, null, 'body', 'For the program.');
    await _pick(tester, 'RETURN');
    await _tap(tester, find.text('value'));
    await _pick(tester, 'best');

    final graph = _graph(tester);
    expect(graph.slotList(loop, 'body'), [first, second]);
    expect(graph.parentOf(second)?.blockId, loop);
    expect(graph.slotList(first, 'then').where((id) => graph.blocks[id]?.catalogId == BlockIds.ctrlIf), isEmpty);

    final lowered = _loweredLoop(graph);
    expect(lowered.body, hasLength(2));
    final top = lowered.body[0] as IfStmt;
    final bottom = lowered.body[1] as IfStmt;
    expect(top.srcBlockId, first);
    expect(bottom.srcBlockId, second);
    expect(top.thenBody.whereType<IfStmt>(), isEmpty);
    expect((top.thenBody.single as AssignStmt).srcBlockId, isNotNull);

    final result = const DefaultEngine().run(
      const Lowerer().lower(graph, _puzzle).program!,
      {'values': ArrayValue([const NumValue(4)])},
      RunLimits.standard,
    );
    expect(result.kind, ResultKind.correct, reason: result.message);
    expect((result.output as NumValue).value, 7);
  });

  testWidgets('the THEN add button nests an IF, and that lowering is different', (tester) async {
    await _open(tester);
    final loop = await _addForEach(tester);
    final outer = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    await _compare(tester, 0, 1);
    final inner = await _addIf(tester, outer, 'then', 'For THEN of IF.');
    await _compare(tester, 1, 0);

    final graph = _graph(tester);
    expect(graph.slotList(loop, 'body'), [outer]);
    expect(graph.slotList(outer, 'then'), [inner]);
    expect(graph.parentOf(inner)?.blockId, outer);
    expect(graph.parentOf(inner)?.port, 'then');

    final lowered = _loweredLoop(graph);
    expect(lowered.body, hasLength(1));
    final stmt = lowered.body.single as IfStmt;
    expect(stmt.srcBlockId, outer);
    expect((stmt.thenBody.single as IfStmt).srcBlockId, inner);
  });

  testWidgets('closing the THEN picker arms that list for the next palette IF', (tester) async {
    await _open(tester);
    final loop = await _addForEach(tester);
    final first = await _addIf(tester, loop, 'body', 'For DO of FOR EACH.');
    await _tap(tester, find.byKey(ValueKey('add-step:$first.then')));
    expect(find.textContaining('For THEN of IF.'), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byTooltip('Close')));
    expect(find.byType(PaletteTray), findsOneWidget);
    final chip = find.descendant(of: find.byType(PaletteTray), matching: find.text('IF'));
    final rows = find.descendant(of: find.byType(PaletteTray), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(chip, 120, scrollable: rows.last);
    await tester.pumpAndSettle();
    await tester.tap(chip.hitTestable().first);
    await tester.pumpAndSettle();

    final graph = _graph(tester);
    final nested = graph.slotList(first, 'then').single;
    expect(graph.blocks[nested]?.catalogId, BlockIds.ctrlIf);
    expect(graph.parentOf(nested)?.blockId, first);
    expect(graph.parentOf(nested)?.port, 'then');
    expect(graph.slotList(loop, 'body'), [first]);
  });
}
