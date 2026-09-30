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
final _pair = parsePuzzleJson(File('assets/puzzles/world_04/matched_pair.json').readAsStringSync());

Finder _inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> _open(WidgetTester tester, [Puzzle? puzzle]) async {
  usePhone(tester, 360, 800, dpr: 2);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(theme: buildAppTheme(AppPalette.dark), home: PuzzleEditor(puzzle: puzzle ?? _warm, briefOpen: false)),
  ));
  await tester.pumpAndSettle();
}

/// Taps [finder], scrolling it into view first (the picker lists every
/// piece that fits, so some are below the fold).
Future<void> _tap(WidgetTester tester, Finder finder) async {
  final sheetList = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable));
  if (finder.evaluate().isEmpty && sheetList.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 120, scrollable: sheetList.first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// What the pad shows, e.g. `44` or `−9`.
String _pad(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('pad-value'))).data!;

Future<void> _key(WidgetTester tester, String key) => _tap(tester, find.byKey(Key('pad-$key')));

/// SET count TO a NUMBER, with the pad open on it.
Future<void> _setCountToNumber(WidgetTester tester) async {
  await _tap(tester, find.text('add step'));
  await _tap(tester, _inSheet('SET'));
  await _tap(tester, _inSheet('count'));
  await _tap(tester, find.text('value'));
  await _tap(tester, _inSheet('NUMBER'));
}

void main() {
  testWidgets('SET count TO a number typed on the pad, then edited again', (tester) async {
    await _open(tester);
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));

    // The name sheet spans the screen and offers the pool.
    expect(tester.getSize(find.byType(BottomSheet)).width, 360);
    expect(_inSheet('Choose a name'), findsOneWidget);
    expect(_inSheet('Create variable'), findsNothing, reason: 'U1: names come from the puzzle');
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
    await _key(tester, '±');
    await _tap(tester, _inSheet('DONE'));
    expect(_inScript('-42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('U1 pad: the number opens selected, so typing replaces it; ⌫ fixes the last digit', (tester) async {
    await _open(tester);
    await _setCountToNumber(tester);
    for (final d in ['4', '5']) {
      await _key(tester, d);
    }
    await _key(tester, 'done');
    expect(_inScript('45'), findsOneWidget);

    // 45 → tap → type 4 4 → 44: no deleting first.
    await _tap(tester, _inScript('45'));
    expect(_pad(tester), '45');
    expect(_inSheet('Typing replaces this number'), findsOneWidget, reason: 'the selection is said in words');
    await _key(tester, '4');
    expect(_pad(tester), '4');
    await _key(tester, '4');
    expect(_pad(tester), '44');

    // A wrong last digit: ⌫ removes just that one.
    await _key(tester, '7');
    expect(_pad(tester), '447');
    await _key(tester, '⌫');
    expect(_pad(tester), '44');
    await _key(tester, 'done');
    expect(_inScript('44'), findsOneWidget);
    expect(_inScript('45'), findsNothing);
  });

  testWidgets('U1 pad: CLEAR empties it in one tap; ⌫ on a selected number clears it too', (tester) async {
    await _open(tester);
    await _setCountToNumber(tester);
    for (final d in ['1', '2', '3']) {
      await _key(tester, d);
    }
    expect(_pad(tester), '123');
    await _key(tester, 'clear');
    expect(_pad(tester), '0');
    await _key(tester, '8');
    expect(_pad(tester), '8', reason: 'a new number after CLEAR');
    await _key(tester, 'done');
    expect(_inScript('8'), findsOneWidget);

    await _tap(tester, _inScript('8'));
    await _key(tester, '⌫');
    expect(_pad(tester), '0', reason: 'the whole selected number is gone');
    await _key(tester, '3');
    await _key(tester, '0');
    expect(_pad(tester), '30');

    // Tapping the number selects it all again.
    await _tap(tester, find.byKey(const Key('pad-display')));
    await _key(tester, '6');
    expect(_pad(tester), '6');
    await _key(tester, 'done');
    expect(_inScript('6'), findsOneWidget);
  });

  testWidgets('U1 pad: +/− makes a negative number and says so in words; no One more / One less', (tester) async {
    await _open(tester);
    await _setCountToNumber(tester);
    expect(find.text('One more'), findsNothing);
    expect(find.text('One less'), findsNothing);
    expect(_inSheet('+/−'), findsOneWidget);
    expect(find.bySemanticsLabel('Change sign'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete last digit'), findsOneWidget);

    await _key(tester, '9');
    await _key(tester, '±');
    expect(_pad(tester), '−9');
    expect(_inSheet('negative'), findsOneWidget, reason: 'not by colour alone');
    await _key(tester, '±');
    expect(_pad(tester), '9');
    expect(_inSheet('negative'), findsNothing);
    await _key(tester, '±');
    await _key(tester, 'done');
    expect(_inScript('-9'), findsOneWidget);

    // Reopened, the sign is kept and the digits are selected.
    await _tap(tester, _inScript('-9'));
    expect(_pad(tester), '−9');
    expect(_inSheet('negative'), findsOneWidget);
    await _key(tester, '2');
    expect(_pad(tester), '−2', reason: 'typing replaces the digits, the sign stays');
    await _key(tester, 'done');
    expect(_inScript('-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('U1: TRUE / FALSE shows which one is set, with a check and a word', (tester) async {
    await _open(tester, _pair);
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('RETURN'));
    await _tap(tester, find.text('value'));
    await _tap(tester, _inSheet('BOOLEAN'));
    final initial = _inScript('TRUE').evaluate().isNotEmpty ? 'TRUE' : 'FALSE';
    final other = initial == 'TRUE' ? 'FALSE' : 'TRUE';

    await _tap(tester, _inScript(initial));
    expect(_inSheet('$initial · selected'), findsOneWidget);
    expect(_inSheet(other), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.check)), findsOneWidget);
    await _tap(tester, _inSheet(other));
    expect(_inScript(other), findsOneWidget);

    await _tap(tester, _inScript(other));
    expect(_inSheet('$other · selected'), findsOneWidget);
    expect(_inSheet(initial), findsOneWidget);
  });

  testWidgets('the picker offers INCREMENT per number variable, and the palette opens it', (tester) async {
    await _open(tester);
    // U1: the puzzle's variables are there from the start, so INCREMENT
    // count is offered before anything sets count.
    await _tap(tester, find.text('add step'));
    expect(_inSheet('INCREMENT count'), findsOneWidget);
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
        theme: buildAppTheme(AppPalette.dark),
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
