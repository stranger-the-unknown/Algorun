import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone.dart';

/// The real puzzle screen on a phone, under the real app theme (E1 tests).
///
/// [language] installs the app's localizations (`en`, `tr`); without it the
/// screen falls back to English like the other bare harnesses.
Future<void> openEditor(
  WidgetTester tester,
  Puzzle puzzle, {
  BlockGraph? initial,
  PuzzleSaveHooks? hooks,
  String? language,
  double width = 360,
  double height = 800,
  double textScale = 1,
  bool dark = true,
}) async {
  usePhone(tester, width, height, textScale: textScale);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(dark ? AppPalette.dark : AppPalette.light),
      locale: language == null ? null : Locale(language),
      localizationsDelegates: language == null ? null : AppLocalizations.localizationsDelegates,
      supportedLocales: language == null ? const [Locale('en')] : AppLocalizations.supportedLocales,
      home: PuzzleEditor(puzzle: puzzle, initialGraph: initial, save: hooks, briefOpen: false),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The controller of the editor on screen.
EditorController editorOf(WidgetTester tester) =>
    tester.widget<ScriptView>(find.byType(ScriptView)).controller;

/// The program's own scroll view.
final scriptScrollable =
    find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable)).first;

/// A piece of text inside the program (the palette shows block names too).
Finder inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));

/// Scrolls [finder] into view and taps it; it must be hittable. A block
/// further down a long program is not built yet: the program is scrolled
/// until it is.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scriptScrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder inSheet(Finder matching) => find.descendant(of: find.byType(BottomSheet), matching: matching);
