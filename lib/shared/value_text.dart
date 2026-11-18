import 'dart:convert';

/// A fixture value (canonical JSON) the way a player reads it: `[3, 1, 4]`,
/// `7`, `TRUE`, `NOTHING`. Tagged structures keep their JSON form.
String fixtureText(Object? json) => switch (json) {
      null => 'NOTHING',
      true => 'TRUE',
      false => 'FALSE',
      final List<Object?> list => '[${list.map(fixtureText).join(', ')}]',
      final Map<Object?, Object?> tagged => jsonEncode(tagged),
      _ => '$json',
    };
