import 'package:algorun/app.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/progress_fixtures.dart';

/// U1: the game in English and in Turkish, switched in settings, with the
/// block reference open from anywhere. Block names stay English.
final _campaign = shippedCampaign();
final _warm = _campaign.puzzles['warm_readings']!;
final _tr = turkishContent();

/// A device in [language]; with [draft], it left Warm Readings with its
/// solution in the editor.
MemoryProgressStore _device({String language = 'en', bool draft = false}) {
  var save = PlayerSave(settings: PlayerSettings(language: language));
  if (draft) {
    save = openPuzzle(save, _campaign, _warm).$1;
    save = saveDraft(save, _campaign, _warm, referenceSolution('world_01', 'warm_readings'));
  }
  return MemoryProgressStore(encodeSave(save));
}

Future<void> _launch(WidgetTester tester, ProgressStore store,
    {double width = 390, double height = 844, double textScale = 1}) async {
  usePhone(tester, width, height, textScale: textScale);
  await tester.pumpWidget(
    ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _see(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the screen's main list (the script, when there is one) until
/// [finder] is built and on screen.
Future<void> _see(WidgetTester tester, Finder finder, {Finder? within}) async {
  if (finder.evaluate().isEmpty) {
    final script = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable));
    final list = within ??
        (script.evaluate().isNotEmpty ? script.first : find.byType(Scrollable).hitTestable().first);
    await tester.scrollUntilVisible(finder, 150, scrollable: list);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _in(Key key, String text) => find.descendant(of: find.byKey(key), matching: find.text(text));

/// The scrollable list inside a guide tab.
Finder _guideList(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable)).first;

String _stored(MemoryProgressStore store) => decodeSave(store.text!).save.settings.language;

void main() {
  testWidgets('English by default; Türkçe in settings changes every screen at once and is saved', (tester) async {
    final store = MemoryProgressStore();
    await _launch(tester, store);
    expect(find.text('ENTER'), findsOneWidget);
    expect(find.text('Block reference'), findsOneWidget);
    expect(find.text('0 of 107 puzzles solved'), findsOneWidget);

    await _tap(tester, find.text('Settings'));
    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(_in(const Key('settings-language-en'), 'selected'), findsOneWidget);
    expect(_in(const Key('settings-language-tr'), 'selected'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('settings-language-tr'))).height, greaterThanOrEqualTo(48));

    await _tap(tester, find.byKey(const Key('settings-language-tr')));
    expect(find.text('Ayarlar'), findsOneWidget, reason: 'the open screen changes at once');
    expect(find.text('DİL', skipOffstage: false), findsOneWidget);
    expect(_in(const Key('settings-language-tr'), 'seçili'), findsOneWidget, reason: 'said in words, not colour');
    expect(_in(const Key('settings-language-en'), 'seçili'), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const Key('settings-language-tr'))),
      isSemantics(isSelected: true),
    );
    expect(_stored(store), 'tr');

    await _tap(tester, find.byType(BackButton));
    expect(find.text('BAŞLA'), findsOneWidget);
    expect(find.text('Blok Rehberi'), findsOneWidget);
    expect(find.text('107 bulmacadan 0 tanesi çözüldü'), findsOneWidget);

    await _tap(tester, find.text('BAŞLA'));
    expect(find.text('Dünyalar'), findsOneWidget);
    expect(find.text('Temeller'), findsOneWidget);
    await _tap(tester, find.byType(BackButton));

    // And back to English.
    await _tap(tester, find.text('Ayarlar'));
    await _tap(tester, find.byKey(const Key('settings-language-en')));
    expect(find.text('Settings'), findsOneWidget);
    expect(_stored(store), 'en');
    await _tap(tester, find.byType(BackButton));
    expect(find.text('ENTER'), findsOneWidget);
  });

  testWidgets('the language survives a restart and a progress reset', (tester) async {
    final store = _device(language: 'tr', draft: true);
    await _launch(tester, store);
    expect(find.text('DEVAM ET'), findsOneWidget);
    await _tap(tester, find.text('Ayarlar'));
    await _tap(tester, find.byKey(const Key('settings-reset')));
    await _tap(tester, find.byKey(const Key('settings-reset-confirm')));
    expect(find.text('Ayarlar'), findsOneWidget, reason: 'still Turkish after the reset');
    expect(_stored(store), 'tr');
    await _tap(tester, find.byType(BackButton));
    expect(find.text('BAŞLA'), findsOneWidget, reason: 'the progress is gone');
  });

  testWidgets('the block reference in English: every block with its Turkish name, both meanings, an example',
      (tester) async {
    await _launch(tester, MemoryProgressStore());
    await _tap(tester, find.byKey(const Key('home-guide')));
    expect(find.text('Block reference'), findsOneWidget);
    expect(find.text('Blocks'), findsOneWidget);

    final ifCard = find.byKey(const Key('guide-block-ctrl.if'));
    await _see(tester, ifCard, within: _guideList('guide-blocks'));
    expect(find.descendant(of: ifCard, matching: find.text('IF  —  EĞER / KOŞUL')), findsOneWidget);
    final en = find.descendant(of: ifCard, matching: find.textContaining('Checks a condition.'));
    final tr = find.descendant(of: ifCard, matching: find.textContaining('Bir koşulu kontrol eder.'));
    expect(en, findsOneWidget);
    expect(tr, findsOneWidget);
    expect(tester.getTopLeft(en).dy, lessThan(tester.getTopLeft(tr).dy), reason: 'the player’s language first');
    expect(find.descendant(of: ifCard, matching: find.text('EXAMPLE')), findsOneWidget);

    await _tap(tester, find.text('Concepts'));
    final index = find.byKey(const Key('guide-concept-2'));
    await _see(tester, index, within: _guideList('guide-concepts'));
    expect(find.descendant(of: index, matching: find.text('Index / Position  —  Konum (index)')), findsOneWidget);
    expect(find.descendant(of: index, matching: find.textContaining('best is a position')), findsOneWidget);

    await _tap(tester, find.text('How to play'));
    expect(find.text('Read the brief'), findsOneWidget);
  });

  testWidgets('the block reference in Turkish', (tester) async {
    await _launch(tester, _device(language: 'tr'));
    await _tap(tester, find.byKey(const Key('home-guide')));
    expect(find.text('Blok Rehberi'), findsOneWidget);
    expect(find.text('Bloklar'), findsOneWidget);
    final ifCard = find.byKey(const Key('guide-block-ctrl.if'));
    await _see(tester, ifCard, within: _guideList('guide-blocks'));
    final tr = find.descendant(of: ifCard, matching: find.textContaining('Bir koşulu kontrol eder.'));
    final en = find.descendant(of: ifCard, matching: find.textContaining('Checks a condition.'));
    expect(tester.getTopLeft(tr).dy, lessThan(tester.getTopLeft(en).dy));
    expect(find.descendant(of: ifCard, matching: find.text('ÖRNEK')), findsOneWidget);

    await _tap(tester, find.text('Kavramlar'));
    final index = find.byKey(const Key('guide-concept-2'));
    await _see(tester, index, within: _guideList('guide-concepts'));
    expect(find.descendant(of: index, matching: find.textContaining('best bir konumdur')), findsOneWidget);
  });

  testWidgets('a puzzle in Turkish: title, story, hints and results; the blocks stay English', (tester) async {
    await _launch(tester, _device(language: 'tr', draft: true));
    final title = _tr.puzzles['warm_readings']!.title!;
    expect(find.text('Son oynanan: $title · Temeller'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('home-continue')));
    expect(find.text(title), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'ÇALIŞTIR'), findsOneWidget);
    expect(find.text('VERİLENLER'), findsOneWidget);
    expect(find.text('DEĞİŞKENLER'), findsOneWidget);
    expect(find.text('CREATE VARIABLE'), findsNothing);
    await _see(tester, find.text(_tr.puzzles['warm_readings']!.story!));

    await _tap(tester, find.byKey(const Key('hints-reveal')));
    await _see(tester, find.text('1. ${_tr.puzzles['warm_readings']!.hints.first}'));

    final script = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable)).first;
    for (final keyword in ['FOR EACH', 'IF', 'INCREMENT', 'RETURN']) {
      final inScript = find.descendant(of: find.byType(ScriptView), matching: find.text(keyword));
      for (var i = 0; i < 40 && inScript.evaluate().isEmpty; i++) {
        await tester.drag(script, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      expect(inScript, findsWidgets, reason: '$keyword stays English');
    }

    // The reference from the puzzle: this puzzle's blocks first.
    await _tap(tester, find.byKey(const Key('open-guide')));
    expect(find.text('BU BULMACADA'), findsOneWidget);
    await _see(tester, find.byKey(const Key('guide-block-here-ctrl.foreach')), within: _guideList('guide-blocks'));
    await _tap(tester, find.byType(BackButton));

    await _tap(tester, find.widgetWithText(FilledButton, 'ÇALIŞTIR'));
    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('DOĞRU'), findsOneWidget);
    await _see(tester, find.text('Bulmaca çözüldü.'));
    final next = _tr.puzzles['highest_tide']!.title!;
    expect(next, contains('i'), reason: 'this checks Turkish capitals');
    await _see(tester, find.byKey(const Key('results-next')));
    expect(find.text('SIRADAKİ: ${next.replaceAll('i', 'İ').toUpperCase()}'), findsOneWidget);
  });

  for (final (w, h) in [(360.0, 800.0), (800.0, 360.0)]) {
    testWidgets('Turkish on a ${w.toInt()} × ${h.toInt()} phone at font ×1.6: home, settings, guide, puzzle, result',
        (tester) async {
      // An overflow anywhere fails the test.
      await _launch(tester, _device(language: 'tr', draft: true), width: w, height: h, textScale: 1.6);
      await _tap(tester, find.text('Ayarlar'));
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.text('DÜNYALAR'));
      await _tap(tester, find.text('Temeller'));
      expect(find.text(_tr.puzzles['warm_readings']!.title!), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.byKey(const Key('home-guide')));
      await _tap(tester, find.text('Kavramlar'));
      await _tap(tester, find.text('Nasıl oynanır'));
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.byKey(const Key('home-continue')));
      final run = find.widgetWithText(FilledButton, 'ÇALIŞTIR');
      expect(clearOfSystemBars(tester, run), isTrue);
      await _tap(tester, run);
      expect(find.text('DOĞRU'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
