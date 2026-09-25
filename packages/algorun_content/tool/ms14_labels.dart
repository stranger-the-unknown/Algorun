import 'dart:convert';
import 'dart:io';

import 'package:algorun_engine/algorun_engine.dart';

/// Reports block labels used as whole tokens in English story/hints that the
/// Turkish text dropped. Same rule as test/localization_test.dart.
void main() {
  final labels = {for (final id in BlockIds.all) BlockChrome.labelOf(id)}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final tr = jsonDecode(File('assets/l10n/content_tr.json').readAsStringSync()) as Map<String, Object?>;
  final puzzles = (tr['puzzles']! as Map).cast<String, Object?>();
  var missing = 0;
  for (final spec in Directory('assets/puzzles').listSync(recursive: true).whereType<File>()) {
    if (!spec.path.endsWith('.json')) continue;
    final json = jsonDecode(spec.readAsStringSync()) as Map<String, Object?>;
    final id = json['id']! as String;
    final pt = puzzles[id];
    if (pt is! Map) {
      print('NO TURKISH $id');
      missing++;
      continue;
    }
    final story = json['story']! as String;
    final hints = (json['hints']! as List).cast<String>();
    final storyTr = pt['story'] as String? ?? '';
    final hintsTr = (pt['hints'] as List?)?.cast<String>() ?? const <String>[];
    if (storyTr == story) {
      print('STORY SAME $id');
      missing++;
    }
    if (hintsTr.length != hints.length) {
      print('HINT COUNT $id ${hintsTr.length} != ${hints.length}');
      missing++;
    }
    final pairs = [(story, storyTr), for (var i = 0; i < hints.length && i < hintsTr.length; i++) (hints[i], hintsTr[i])];
    for (final (english, turkish) in pairs) {
      for (final label in labels) {
        if (RegExp('(?<![A-Z])${RegExp.escape(label)}(?![A-Z])').hasMatch(english) && !turkish.contains(label)) {
          print('$id missing "$label"');
          missing++;
        }
      }
    }
  }
  print(missing == 0 ? 'labels ok' : '$missing problems');
  if (missing != 0) exit(1);
}
