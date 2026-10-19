import 'package:algorun/editor/palette_tray.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone.dart';

/// The real editor screen: add-step buttons, the picker sheet, and the
/// palette. The graph is read from the [ScriptView] the screen built.
Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "sibling_if_widget",
  "title": "Sibling IF",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "Two IFs.",
  "io": {
    "inputs": [{ "name": "x", "type": "num" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": ["ctrl.if"], "maxBlocks": 20 },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "x": 1 }, "out": 1 }],
    "hidden": [{ "id": "h1", "in": { "x": 1 }, "out": 1 }]
  }
}
''');

Finder _sheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

BlockGraph _graph(WidgetTester tester) =>
    tester.widget<ScriptView>(find.byType(ScriptView)).controller.graph;

Future<void> _open(WidgetTester tester, {double width = 360, double height = 800, double textScale = 1}) async {
  usePhone(tester, width, height, textScale: textScale);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(AppPalette.dark),
      home: PuzzleEditor(puzzle: _puzzle(), briefOpen: false),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickIf(WidgetTester tester) async {
  await _tap(tester, _sheet('IF'));
  expect(find.byType(BottomSheet), findsNothing);
}

Future<void> _addFirstIf(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('add-step:main')), findsNothing);
  await _tap(tester, find.text('add step'));
  expect(find.textContaining('For the program.'), findsOneWidget);
  expect(find.textContaining('THEN of IF'), findsNothing);
  await _pickIf(tester);
}

void main() {
  testWidgets('the program add button places a second IF as a sibling', (tester) async {
    await _open(tester);
    await _addFirstIf(tester);

    final first = _graph(tester).entryIds.single;
    final then = find.byKey(ValueKey('add-step:$first.then'));
    final program = find.byKey(const ValueKey('add-step:main'));
    expect(tester.getRect(program).overlaps(tester.getRect(then)), isFalse);

    await _tap(tester, program);
    expect(find.textContaining('For the program.'), findsOneWidget);
    expect(find.textContaining('THEN of IF'), findsNothing);
    await _pickIf(tester);

    final graph = _graph(tester);
    expect(graph.entryIds, hasLength(2));
    expect(graph.entryIds.first, first);
    expect(graph.slotList(first, 'then'), isEmpty);
    expect(graph.parentOf(graph.entryIds[1])?.blockId, BlockGraph.mainId);
  });

  testWidgets('the THEN add button nests the next IF', (tester) async {
    await _open(tester);
    await _addFirstIf(tester);
    final first = _graph(tester).entryIds.single;

    await _tap(tester, find.byKey(ValueKey('add-step:$first.then')));
    expect(find.textContaining('For THEN of IF.'), findsOneWidget);
    expect(find.textContaining('For the program.'), findsNothing);
    await _pickIf(tester);

    final graph = _graph(tester);
    expect(graph.entryIds, [first]);
    expect(graph.slotList(first, 'then'), hasLength(1));
    expect(graph.parentOf(graph.slotList(first, 'then').single)?.blockId, first);
  });

  testWidgets('a palette IF, after the selection is closed, stays on the program list', (tester) async {
    await _open(tester);
    await _tap(tester, find.descendant(of: find.byType(PaletteTray), matching: find.text('IF')));
    final first = _graph(tester).entryIds.single;
    expect(_graph(tester).slotList(first, 'then'), isEmpty);

    await _tap(tester, find.byTooltip('Done'));
    expect(find.byType(PaletteTray), findsOneWidget);
    await _tap(tester, find.descendant(of: find.byType(PaletteTray), matching: find.text('IF')));

    final graph = _graph(tester);
    expect(graph.entryIds, hasLength(2));
    expect(graph.entryIds.first, first);
    expect(graph.slotList(first, 'then'), isEmpty);
    expect(graph.parentOf(graph.entryIds[1])?.blockId, BlockGraph.mainId);
  });

  testWidgets('Move into the block above is a separate control and does nest', (tester) async {
    await _open(tester);
    await _addFirstIf(tester);
    await _tap(tester, find.byTooltip('Done'));
    await _tap(tester, find.byKey(const ValueKey('add-step:main')));
    await _pickIf(tester);

    final before = _graph(tester).entryIds.toList();
    expect(before, hasLength(2));
    await _tap(tester, find.byTooltip('Move into the block above'));

    final graph = _graph(tester);
    expect(graph.entryIds, [before.first]);
    expect(graph.slotList(before.first, 'then'), [before[1]]);
  });

  testWidgets('on a short phone the two add buttons still hit different ports', (tester) async {
    await _open(tester, height: 520);
    expect(find.byType(PaletteTray), findsNothing, reason: 'the tray is hidden below 560px');
    await _addFirstIf(tester);
    final first = _graph(tester).entryIds.single;
    final then = find.byKey(ValueKey('add-step:$first.then'));
    final program = find.byKey(const ValueKey('add-step:main'));
    final scriptScroll = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(program, 80, scrollable: scriptScroll.first);
    await tester.pumpAndSettle();
    expect(program.hitTestable(), findsOneWidget);
    if (then.hitTestable().evaluate().isNotEmpty) {
      expect(tester.getRect(program).overlaps(tester.getRect(then)), isFalse);
    }

    await _tap(tester, program);
    expect(find.textContaining('For the program.'), findsOneWidget);
    await _pickIf(tester);
    expect(_graph(tester).entryIds, hasLength(2));
    expect(_graph(tester).slotList(first, 'then'), isEmpty);
  });
}
