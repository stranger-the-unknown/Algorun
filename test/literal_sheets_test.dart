import 'dart:io';

import 'package:algorun/editor/script_view.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/phone.dart';

/// The number pad and the name sheet under the app's real theme, on a phone.
/// (Before MS13 the theme's full-width button minimum made the number pad
/// fail layout on a device: the sheet never appeared and numbers could not
/// be changed. Tests without the theme did not see it.)
final _warm = parsePuzzleJson(File('assets/puzzles/world_01/warm_readings.json').readAsStringSync());

Finder _inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> _open(WidgetTester tester) async {
  usePhone(tester, 360, 800, dpr: 2);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(theme: buildAppTheme(), home: PuzzleEditor(puzzle: _warm, briefOpen: false)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SET count TO a number typed on the pad, then edited again', (tester) async {
    await _open(tester);
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));

    // The name sheet spans the screen and offers the pool.
    expect(tester.getSize(find.byType(BottomSheet)).width, 360);
    expect(_inSheet('Choose a name'), findsOneWidget);
    await _tap(tester, _inSheet('count'));

    await _tap(tester, find.text('value'));
    await _tap(tester, _inSheet('NUMBER'));
    expect(_inSheet('DONE'), findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).width, 360);
    await _tap(tester, _inSheet('4'));
    await _tap(tester, _inSheet('2'));
    await _tap(tester, _inSheet('DONE'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(_inScript('42'), findsOneWidget);

    await _tap(tester, _inScript('42'));
    await _tap(tester, _inSheet('±'));
    await _tap(tester, _inSheet('DONE'));
    expect(_inScript('-42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the picker offers INCREMENT per number variable, and the palette opens it', (tester) async {
    await _open(tester);
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));
    await _tap(tester, _inSheet('count'));
    await _tap(tester, find.byTooltip('Done'));

    await _tap(tester, find.byKey(const ValueKey('add-step:main')));
    expect(_inSheet('INCREMENT count'), findsOneWidget);
    expect(_inSheet('INCREMENT limit'), findsOneWidget);
    expect(_inSheet('INCREMENT readings'), findsNothing, reason: 'a list cannot be incremented');
    await _tap(tester, _inSheet('INCREMENT count'));
    expect(find.text('INCREMENT'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const Key('block-count'))).data, '2 / 20 blocks');
  });

  testWidgets('RUN with an empty slot says what is missing and points at the block', (tester) async {
    usePhone(tester, 360, 800, dpr: 2);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: PuzzleEditor(puzzle: _warm, briefOpen: false),
        routes: {'/results': (_) => const ResultsScreen()},
      ),
    ));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));
    await _tap(tester, _inSheet('count'));
    await _tap(tester, find.byTooltip('Done'));
    await _tap(tester, find.widgetWithText(FilledButton, 'RUN'));
    expect(find.text('INVALID PROGRAM'), findsOneWidget);
    expect(find.text('This block needs a value.'), findsWidgets);
    await _tap(tester, find.text('BACK TO PUZZLE'));
    expect(find.text('SELECTED'), findsOneWidget);
    expect(find.text('This block needs a value.'), findsOneWidget, reason: 'said again in the editor');
  });
}
