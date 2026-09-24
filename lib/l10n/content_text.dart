import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import '../progress/campaign.dart';

/// Puzzle content in the player's language. English is the puzzle JSON
/// itself (the content pipeline's source of truth); another language comes
/// from `assets/l10n/content_<language>.json`, and anything it lacks falls
/// back to English. The engine and the validator never read translations.
final class ContentTranslations {
  const ContentTranslations({
    this.worlds = const {},
    this.concepts = const {},
    this.puzzles = const {},
  });

  factory ContentTranslations.parse(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    Map<String, String> strings(Object? raw) => {
          for (final e in ((raw as Map?) ?? const {}).entries)
            if (e.value is String) '${e.key}': e.value as String,
        };
    final puzzles = <String, PuzzleText>{};
    for (final e in ((json['puzzles'] as Map?) ?? const {}).entries) {
      final p = e.value as Map;
      puzzles['${e.key}'] = PuzzleText(
        title: p['title'] as String?,
        story: p['story'] as String?,
        hints: [for (final h in (p['hints'] as List?) ?? const []) '$h'],
      );
    }
    return ContentTranslations(
      worlds: strings(json['worlds']),
      concepts: strings(json['concepts']),
      puzzles: puzzles,
    );
  }

  final Map<String, String> worlds;
  final Map<String, String> concepts;
  final Map<String, PuzzleText> puzzles;
}

final class PuzzleText {
  const PuzzleText({this.title, this.story, this.hints = const []});

  final String? title;
  final String? story;
  final List<String> hints;
}

/// What the screens show for content. `ContentText.english` needs nothing
/// loaded.
final class ContentText {
  const ContentText(this.language, [this.translations = const ContentTranslations()]);

  static const english = ContentText('en');

  final String language;
  final ContentTranslations translations;

  String puzzleTitle(Puzzle puzzle) => translations.puzzles[puzzle.id]?.title ?? puzzle.title;

  String story(Puzzle puzzle) => translations.puzzles[puzzle.id]?.story ?? puzzle.story;

  /// The puzzle's hints; a translation only replaces them whole, so a hint
  /// is never missing or out of order.
  List<String> hints(Puzzle puzzle) {
    final translated = translations.puzzles[puzzle.id]?.hints ?? const [];
    return translated.length == puzzle.hints.length ? translated : puzzle.hints;
  }

  String worldTitle(WorldDef world) => translations.worlds[world.id] ?? world.title;

  String concept(String id) => translations.concepts[id] ?? conceptWords(id);

  String concepts(Iterable<String> ids) => ids.map(concept).join(', ');
}
