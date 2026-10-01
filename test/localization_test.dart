import 'dart:convert';
import 'dart:io';

import 'package:algorun/guide/guide_data.dart';
import 'package:algorun/l10n/content_text.dart';
import 'package:algorun/l10n/engine_text.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/l10n/terms.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/state/performance_text.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// U1: every player-facing text exists in English and Turkish, and the
/// Turkish never changes what the game is (block names stay English).
Map<String, Object?> _arb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync()) as Map<String, Object?>;

Set<String> _placeholders(String text) => {
      for (final m in RegExp(r'\{([A-Za-z_]\w*)').allMatches(text)) m.group(1)!,
    };

/// Engine files whose sentences are for content authors (puzzle JSON,
/// program JSON, fixtures), never shown to a player: the validator rejects
/// such content before it ships.
const _authoringOnly = {
  'parse.dart',
  'value_json.dart',
  'ir.dart',
  'block_graph.dart',
  'parse_type.dart',
};

/// Every English sentence in the engine's player-facing code, with each
/// interpolation replaced by a sample value.
List<String> _engineSentences() {
  final literal = RegExp(r"'((?:[^'\\\n]|\\.)*)'");
  final out = <String>{};
  for (final entity in Directory('packages/algorun_engine/lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (_authoringOnly.contains(entity.uri.pathSegments.last)) continue;
    for (final line in entity.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in literal.allMatches(line)) {
        final text = m.group(1)!.replaceAll(r"\'", "'");
        if (RegExp(r'^[A-Z][a-z]').hasMatch(text) && text.endsWith('.') && text.contains(' ')) {
          out.add(text.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '7'));
        }
      }
    }
  }
  return out.toList()..sort();
}

void main() {
  final en = _arb('en');
  final tr = _arb('tr');
  final english = stringsFor('en');
  final turkish = stringsFor('tr');

  test('English is the default; English and Turkish are the languages', () {
    expect(PlayerSettings.defaults.language, 'en');
    expect(PlayerSettings.languages, ['en', 'tr']);
    expect(AppLocalizations.supportedLocales, containsAll(const [Locale('en'), Locale('tr')]));
    expect(englishStrings.localeName, 'en');
    expect(turkish.localeName, 'tr');
  });

  test('every English string has a Turkish one with the same placeholders', () {
    final keys = {for (final k in en.keys) if (!k.startsWith('@')) k};
    expect({for (final k in tr.keys) if (!k.startsWith('@')) k}, keys);
    for (final k in keys) {
      expect(_placeholders(tr[k]! as String), _placeholders(en[k]! as String), reason: k);
      expect((tr[k]! as String).trim(), isNotEmpty, reason: k);
    }
    // Only names and words that are the same in both languages.
    final same = {for (final k in keys) if (en[k] == tr[k]) k};
    expect(same, {
      'appTitle',
      'worldHeading',
      'program',
      'selectionTitle',
      'targetElse',
      'captionElse',
      'languageEnglish',
      'languageTurkish',
    });
  });

  test('sample strings: the two languages really differ, keywords stay English', () {
    expect(english.run, 'RUN');
    expect(turkish.run, 'ÇALIŞTIR');
    expect(english.homeGuide, 'Block reference');
    expect(turkish.homeGuide, 'Blok Rehberi');
    expect(turkish.blocksCount(3), '3 blok');
    expect(english.blocksCount(1), '1 block');
    expect(verdictText(ResultKind.correct, turkish), 'DOĞRU');
    expect(verdictText(ResultKind.operationLimit, english), 'OPERATION LIMIT');
    expect(typeText(ValueType.array(ValueType.number), turkish), isNot(typeText(ValueType.array(ValueType.number), english)));
    expect(categoryText(BlockCategory.control, turkish), isNot(categoryText(BlockCategory.control, english)));
    expect(formatCount(12345, 'tr'), '12.345');
    expect(formatCount(12345), '12,345');
  });

  test('a heap (H) has its own words; in Turkish it is not the stack\'s "yığın"', () {
    const heap = ValueType(TypeAtom.heap, param: ValueType.number);
    expect(typeText(heap, english), 'heap of numbers');
    expect(typeText(heap, turkish), 'sayı öncelik kuyruğu');
    expect(holeCaptionText('heap', turkish), 'öncelik kuyruğu');
    expect(engineText('This heap is empty.', turkish), 'Bu öncelik kuyruğu boş.');
    expect(engineText('This block needs a heap.', english), 'This block needs a heap.');
    for (final id in [BlockIds.newMinHeap, BlockIds.heapInsert, BlockIds.heapTake, BlockIds.heapTop]) {
      expect(blockGuide[id]!.trText, isNot(contains('yığın')), reason: id);
    }
  });

  test('every engine message a player can see has Turkish; English passes through', () {
    final sentences = _engineSentences();
    expect(sentences.length, greaterThan(60));
    for (final s in sentences) {
      expect(engineText(s, english), s, reason: 'English is the engine text itself');
      expect(engineText(s, turkish), isNot(s), reason: 'no Turkish for "$s"');
    }
    expect(engineText('This program is not ready to run.', turkish), isNot('This program is not ready to run.'));
    expect(engineText('This puzzle allows at most 20 blocks.', turkish), contains('20'));
    expect(engineText('A message from a newer engine.', turkish), 'A message from a newer engine.',
        reason: 'an unknown message is shown in English rather than not at all');
  });

  test('Turkish content covers every shipped world, concept and puzzle', () {
    final campaign = shippedCampaign();
    final t = turkishContent();
    final text = ContentText('tr', t);
    final ids = {for (final w in campaign.manifest.worlds) ...w.puzzleIds};
    expect(t.puzzles.keys.toSet(), ids, reason: 'no puzzle missing, no stale entry');
    for (final world in campaign.manifest.worlds) {
      expect(t.worlds[world.id], isNotNull, reason: world.id);
      for (final c in world.concepts) {
        expect(t.concepts[c], isNotNull, reason: 'concept $c');
      }
      for (final id in world.puzzleIds) {
        final p = campaign.puzzles[id]!;
        final pt = t.puzzles[id]!;
        expect(pt.title, isNotEmpty, reason: id);
        expect(pt.story, isNotEmpty, reason: id);
        expect(pt.story, isNot(p.story), reason: id);
        expect(pt.hints, hasLength(p.hints.length), reason: '$id: same number of hints, in order');
        expect(text.hints(p), pt.hints);
        expect(text.puzzleTitle(p), pt.title);
      }
    }
  });

  test('Turkish stories and hints keep every block name the English ones use', () {
    final campaign = shippedCampaign();
    final t = turkishContent();
    final labels = {for (final id in BlockIds.all) BlockChrome.labelOf(id)}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final p in campaign.puzzles.values) {
      final pt = t.puzzles[p.id]!;
      final pairs = [(p.story, pt.story!), for (var i = 0; i < p.hints.length; i++) (p.hints[i], pt.hints[i])];
      for (final (english, turkish) in pairs) {
        for (final label in labels) {
          if (RegExp('(?<![A-Z])$label(?![A-Z])').hasMatch(english)) {
            expect(turkish, contains(label), reason: '${p.id}: "$label" stays English');
          }
        }
      }
    }
  });

  test('missing or partial translations fall back to English', () {
    final puzzle = shippedCampaign().puzzles['warm_readings']!;
    const none = ContentText('tr');
    expect(none.puzzleTitle(puzzle), puzzle.title);
    expect(none.story(puzzle), puzzle.story);
    final partial = ContentText(
      'tr',
      ContentTranslations(puzzles: {'warm_readings': const PuzzleText(title: 'Başlık', hints: ['tek ipucu'])}),
    );
    expect(partial.puzzleTitle(puzzle), 'Başlık');
    expect(partial.story(puzzle), puzzle.story);
    expect(partial.hints(puzzle), puzzle.hints, reason: 'hints are replaced whole or not at all');
  });

  test('the block reference covers every block a puzzle offers, in both languages', () {
    final campaign = shippedCampaign();
    final offered = {
      for (final p in campaign.puzzles.values)
        for (final id in p.blocks.allow)
          if (!BlockChrome.hiddenFromEditor(id)) id,
    };
    expect(blockGuide.keys, containsAll(offered));
    for (final e in blockGuide.entries) {
      final g = e.value;
      expect(g.en, isNotEmpty, reason: e.key);
      expect(g.trText, isNotEmpty, reason: e.key);
      expect(g.tr, isNotEmpty, reason: e.key);
      expect(g.trText, isNot(g.en), reason: e.key);
      if (e.key != BlockIds.varGet && e.key != BlockIds.litBool) {
        expect(g.term, startsWith(BlockChrome.labelOf(e.key)), reason: 'the name the editor shows');
      }
    }
    expect(blockGuide[BlockIds.ctrlIf]!.tr, contains('KOŞUL'));
    expect(blockGuide[BlockIds.ctrlIf]!.trText, startsWith('Bir koşulu kontrol eder.'));
    expect(blockGuide[BlockIds.ctrlIf]!.en, startsWith('Checks a condition.'));
  });

  test('the concepts include variable, value, index vs value, list, condition and loop', () {
    final terms = {for (final c in conceptGuide) c.term: c};
    expect(terms.keys, containsAll(['Variable', 'Value', 'Index / Position', 'List', 'Condition', 'Loop']));
    expect(terms['Variable']!.tr, 'Değişken');
    expect(terms['Index / Position']!.tr, contains('Konum'));
    final index = terms['Index / Position']!;
    expect(index.exampleFor('en'), contains('best is a position'));
    expect(index.exampleFor('tr'), contains('best bir konumdur'));
    for (final c in conceptGuide) {
      expect(c.trText, isNot(c.en), reason: c.term);
    }
  });
}
