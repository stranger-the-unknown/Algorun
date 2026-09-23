import 'dart:io';

import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/results_finders.dart';

Puzzle _puzzle({String hints = '["Think in pairs.", "Keep a set.", "Ask before you add."]'}) =>
    parsePuzzleJson('''
{
  "id": "hint_probe", "title": "Hint Probe", "world": "world_01", "tier": 1, "mode": "build",
  "story": "Count the numbers.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "arr.len", "var.get"] },
  "limits": { "maxOps": 1000 },
  "hints": $hints,
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }
}
''');

Future<void> _open(WidgetTester tester, Puzzle puzzle) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: PuzzleEditor(puzzle: puzzle),
        routes: {'/results': (_) => const ResultsScreen()},
      ),
    ),
  );
  await tester.pump();
}

final _reveal = find.byKey(const Key('hints-reveal'));
final _toggle = find.byKey(const Key('hints-toggle'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('hints start hidden and come one per tap, in order', (tester) async {
    await _open(tester, _puzzle());
    expect(find.text('0/3'), findsOneWidget);
    expect(find.text('SHOW HINT 1'), findsOneWidget);
    expect(find.textContaining('Think in pairs.'), findsNothing);

    await _tap(tester, _reveal);
    expect(find.text('1. Think in pairs.'), findsOneWidget);
    expect(find.textContaining('Keep a set.'), findsNothing);
    expect(find.text('1/3'), findsOneWidget);

    await _tap(tester, _reveal);
    expect(find.text('2. Keep a set.'), findsOneWidget);
    expect(find.textContaining('Ask before you add.'), findsNothing);
    expect(find.text('2/3'), findsOneWidget);

    await _tap(tester, _reveal);
    expect(find.text('3. Ask before you add.'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('after the last hint the action is disabled and taps do nothing', (tester) async {
    await _open(tester, _puzzle());
    for (var i = 0; i < 3; i++) {
      await _tap(tester, _reveal);
    }
    expect(find.text('NO MORE HINTS'), findsOneWidget);
    final button = tester.widget<TextButton>(_reveal);
    expect(button.onPressed, isNull);

    await tester.tap(_reveal, warnIfMissed: false);
    await tester.pump();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('opening and closing the hints never counts', (tester) async {
    await _open(tester, _puzzle());
    // Opening before any reveal shows no hint and counts nothing.
    await _tap(tester, _toggle);
    expect(find.text('0/3'), findsOneWidget);
    expect(find.textContaining('Think in pairs.'), findsNothing);
    await _tap(tester, _toggle);

    await _tap(tester, _reveal);
    await _tap(tester, _reveal);
    for (var i = 0; i < 5; i++) {
      await _tap(tester, _toggle);
      expect(find.text('2/3'), findsOneWidget);
    }
    // Five toggles from open ends closed; the revealed hints are kept.
    expect(find.text('1. Think in pairs.'), findsNothing);
    await _tap(tester, _toggle);
    expect(find.text('1. Think in pairs.'), findsOneWidget);
    expect(find.text('2. Keep a set.'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('RUN hands the hint count to the results screen', (tester) async {
    await _open(tester, _puzzle());
    await _tap(tester, _reveal);
    await _tap(tester, _reveal);

    await tester.tap(find.text('RUN'));
    await tester.pumpAndSettle();
    expect(find.text('Result'), findsOneWidget);
    expect(costRow(tester, 'hints'), ['Hints', '2 hints', '—']);
  });

  testWidgets('a puzzle without hints shows no hint action and still runs', (tester) async {
    await _open(tester, _puzzle(hints: '[]'));
    expect(_reveal, findsNothing);
    expect(_toggle, findsNothing);

    await tester.tap(find.text('RUN'));
    await tester.pumpAndSettle();
    expect(costRow(tester, 'hints'), ['Hints', '0 hints', '—']);
  });

  testWidgets('a real puzzle shows its own first hint and nothing else', (tester) async {
    final puzzle = parsePuzzleJson(
      File('assets/puzzles/world_03/twin_beacons.json').readAsStringSync(),
    );
    await _open(tester, puzzle);
    expect(find.text('SHOW HINT 1'), findsOneWidget);
    await _tap(tester, _reveal);
    expect(find.text('1. ${puzzle.hints[0]}'), findsOneWidget);
    expect(find.textContaining(puzzle.hints[1]), findsNothing);
    expect(find.textContaining(puzzle.hints[2]), findsNothing);
    for (final hidden in puzzle.hiddenTests) {
      expect(find.textContaining(hidden.id), findsNothing);
    }
  });
}
