import 'dart:convert';
import 'dart:io';

import 'package:algorun/editor/script_view.dart';
import 'package:algorun/editor/statement_tile.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/l10n/terms.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/ui_replay.dart';

/// L3: the blocks taken from algorun-lang, in the editor on a phone, under
/// the app's real theme — the TEXT chips, COPY's two names, and every world
/// 15 puzzle built from the picker and run.
const _world = 'world_15';

BlockGraph _reference(String id) {
  final json = jsonDecode(File('content/references/$_world/$id.json').readAsStringSync()) as Map<String, Object?>;
  return BlockGraph.fromJson(Map<String, dynamic>.from(json['solution']! as Map));
}

Finder _inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
Finder _inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> _open(WidgetTester tester, Puzzle puzzle, {BlockGraph? program, AppPalette palette = AppPalette.dark}) async {
  usePhone(tester, 360, 800, dpr: 2);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(palette),
      home: PuzzleEditor(puzzle: puzzle, briefOpen: false, initialGraph: program),
    ),
  ));
  await tester.pumpAndSettle();
}

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

void main() {
  final world = shippedCampaign().manifest.worlds.singleWhere((w) => w.id == _world);

  test('world 15 lists the sample puzzles for text, SORT, COPY, deques and pairs', () {
    expect(world.puzzleIds, hasLength(10));
    final offered = {
      for (final id in world.puzzleIds) ...shippedPuzzle(_world, id).blocks.allow,
    };
    expect(
      offered,
      containsAll([
        BlockIds.litStr, BlockIds.strLen, BlockIds.strCharAt, BlockIds.strConcat, BlockIds.strFromNum, BlockIds.strToNum, //
        BlockIds.arrSort, BlockIds.varCopy,
        BlockIds.newDeque, BlockIds.dequePushFront, BlockIds.dequePushBack, BlockIds.dequePopFront, BlockIds.dequePopBack,
        BlockIds.dequeEmpty, BlockIds.pairMake, BlockIds.pairFirst, BlockIds.pairSecond,
      ]),
    );
  });

  for (final id in world.puzzleIds) {
    test('$id: the reference is built from the picker and solves the puzzle', () {
      final puzzle = shippedPuzzle(_world, id);
      final built = buildThroughEditor(puzzle, _reference(id));
      final outcome = runPuzzle(const DefaultEngine(), built.graph, puzzle);
      expect(outcome.suite.kind, ResultKind.correct, reason: outcome.suite.message);
    });
  }

  testWidgets('TEXT is chosen from the puzzle\'s texts, shown in quotes, and can be changed', (tester) async {
    await _open(tester, shippedPuzzle(_world, 'seat_label'));
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));
    await _tap(tester, _inSheet('label'));
    await _tap(tester, find.text('value'));
    await _tap(tester, _inSheet('TEXT'));

    // No keyboard: the empty text and the puzzle's two constants, as chips.
    expect(_inSheet('Choose a text'), findsOneWidget);
    expect(_inSheet('Texts come from the puzzle; there is no typing.'), findsOneWidget);
    expect(tester.getSize(find.byType(BottomSheet)).width, 360);
    for (final choice in ['""', '"-"', '"0"']) {
      expect(_inSheet(choice), findsOneWidget, reason: choice);
    }
    expect(find.byType(TextField), findsNothing);
    await _tap(tester, _inSheet('"-"'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(_inScript('"-"'), findsOneWidget);

    // Tapping the text opens the same chips, with the current one checked.
    await _tap(tester, _inScript('"-"'));
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.check)), findsOneWidget);
    await _tap(tester, _inSheet('"0"'));
    expect(_inScript('"0"'), findsOneWidget);
    expect(_inScript('"-"'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a puzzle without texts places the empty text and opens no sheet', (tester) async {
    await _open(tester, shippedPuzzle(_world, 'mirror_sign'));
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('SET'));
    await _tap(tester, _inSheet('result'));
    await _tap(tester, find.text('value'));
    await _tap(tester, _inSheet('TEXT'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(_inScript('""'), findsOneWidget);
    await _tap(tester, _inScript('""'));
    expect(find.byType(BottomSheet), findsNothing, reason: 'nothing to choose between');
    expect(tester.takeException(), isNull);
  });

  testWidgets('COPY names its source and its target with two chips', (tester) async {
    final puzzle = shippedPuzzle(_world, 'out_of_place');
    await _open(tester, puzzle);
    await _tap(tester, find.text('add step'));
    await _tap(tester, _inSheet('COPY'));
    expect(find.byType(BottomSheet), findsNothing);
    expect(_inScript('COPY'), findsOneWidget);
    expect(_inScript('TO'), findsOneWidget);
    Finder chip(String name) => find.descendant(of: find.byType(NameChip), matching: find.text(name));
    expect(chip('name'), findsNWidgets(2), reason: 'two names to choose');

    await _tap(tester, chip('name').first);
    expect(_inSheet('Choose a name'), findsOneWidget);
    await _tap(tester, _inSheet('names'));
    await _tap(tester, chip('name'));
    await _tap(tester, _inSheet('register'));
    expect(chip('names'), findsOneWidget);
    expect(chip('register'), findsOneWidget);
    expect(chip('name'), findsNothing);
    // COPY source TO target, in reading order (the row may wrap on a phone).
    final source = tester.getTopLeft(chip('names'));
    final target = tester.getTopLeft(chip('register'));
    expect(source.dy < target.dy || (source.dy == target.dy && source.dx < target.dx), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final palette in [AppPalette.dark, AppPalette.light]) {
    testWidgets('the new blocks draw on a 360 dp phone (${palette == AppPalette.dark ? 'dark' : 'light'})', (tester) async {
      for (final (id, words) in [
        ('two_doors', ['NEW DEQUE', 'PUSH BACK', 'POP FRONT', 'POP BACK', 'IS EMPTY']),
        ('zigzag_queue', ['PUSH FRONT', 'PUSH BACK']),
        ('pass_list', ['MAKE PAIR', 'APPEND']),
        ('top_scorer', ['SECOND', 'FIRST']),
        ('out_of_place', ['COPY', 'SORT']),
        ('smudged_tickets', ['TEXT AS NUMBER', 'IS NOT NOTHING']),
        ('seat_label', ['JOIN', 'NUMBER AS TEXT', '"-"', '"0"']),
        ('letter_tally', ['TEXT LENGTH', 'LETTER AT']),
      ]) {
        final puzzle = shippedPuzzle(_world, id);
        await _open(tester, puzzle, program: buildThroughEditor(puzzle, _reference(id)).graph, palette: palette);
        for (final word in words) {
          // The program is a lazy list: a block below the fold is built
          // once it is scrolled to.
          if (_inScript(word).evaluate().isEmpty) {
            final list = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable)).first;
            await tester.scrollUntilVisible(_inScript(word), 200, scrollable: list);
          }
          expect(_inScript(word), findsWidgets, reason: '$id: $word');
        }
        expect(tester.takeException(), isNull, reason: id);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  test('captions and types for the new values, in both languages', () {
    final en = stringsFor('en');
    final tr = stringsFor('tr');
    expect(holeCaptionText('text', en), 'text');
    expect(holeCaptionText('deque', en), 'deque');
    expect(holeCaptionText('pair', en), 'pair');
    expect(holeCaptionText('text', tr), 'metin');
    expect(holeCaptionText('deque', tr), 'çift uçlu kuyruk');
    expect(holeCaptionText('pair', tr), 'çift');
    final results = parseValueType('array<pair<str,num>>');
    expect(typeText(results, en), 'list of pairs');
    expect(typeText(parseValueType('pair<str,num>'), en), 'pair of text and number');
    expect(typeText(parseValueType('pair<str,num>'), tr), 'metin ve sayı çifti');
    expect(typeText(parseValueType('deque<num>'), en), 'deque of numbers');
  });
}
