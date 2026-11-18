import 'package:algorun_engine/algorun_engine.dart';

import '../guide/guide_data.dart';

/// Search over block names (E1), for the picker and the palette.
///
/// A block answers to its English name as the editor shows it (`GET
/// ELEMENT`), to its Turkish name from the block reference (`Konumdaki öğe`)
/// and, when it names a variable or a function, to that name. Nothing here
/// knows a particular block: a block the reference has no entry for is still
/// found by its English name.
abstract final class BlockSearch {
  /// Lower case, with Turkish letters folded onto their plain neighbours, so
  /// `DÖNGÜ`, `döngü` and `dongu` are the same query.
  static String fold(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      out.write(switch (rune) {
        0x130 || 0x131 || 0x49 => 'i', // İ ı I
        0x15E || 0x15F => 's', // Ş ş
        0x11E || 0x11F => 'g', // Ğ ğ
        0xDC || 0xFC => 'u', // Ü ü
        0xD6 || 0xF6 => 'o', // Ö ö
        0xC7 || 0xE7 => 'c', // Ç ç
        _ => String.fromCharCode(rune).toLowerCase(),
      });
    }
    return out.toString();
  }

  /// The words of [query], folded. Empty when the query is blank.
  static List<String> words(String query) => [
        for (final word in fold(query).split(RegExp(r'\s+')))
          if (word.isNotEmpty) word,
      ];

  /// Everything [catalogId] answers to, folded.
  static String haystack(String catalogId, {Map<String, Object?> literals = const {}}) {
    final name = literals['name'];
    return fold([
      BlockChrome.labelOf(catalogId),
      ?blockGuide[catalogId]?.tr,
      if (name is String) name,
    ].join(' '));
  }

  /// Whether every word of [query] is part of one of the block's names. A
  /// blank query matches everything.
  static bool matches(String catalogId, String query, {Map<String, Object?> literals = const {}}) {
    final wanted = words(query);
    if (wanted.isEmpty) return true;
    final text = haystack(catalogId, literals: literals);
    return wanted.every(text.contains);
  }
}
