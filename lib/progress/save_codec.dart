import 'dart:convert';

import 'package:algorun_engine/algorun_engine.dart';

import 'save_data.dart';

/// The save file format.
///
/// ```json
/// {
///   "saveVersion": 1,
///   "puzzles": {
///     "<puzzleId>": {
///       "puzzleVersion": 1,
///       "completed": true,
///       "best": {"ops": 23, "peakAlloc": 0, "peakDepth": 1, "blocks": 9, "hintsUsed": 0},
///       "lastRun": {"result": "wrongAnswer", "ops": …, "peakAlloc": …, "peakDepth": …, "blocks": …, "hintsUsed": …},
///       "solution": <BlockGraph JSON>,
///       "draft": <BlockGraph JSON>,
///       "editedSinceRun": false
///     }
///   },
///   "settings": {"language": "en", "showBriefOnOpen": true},
///   "session": {"worldId": "world_02", "puzzleId": "smallest_cart"}
/// }
/// ```
///
/// Writing is deterministic: object keys are sorted at every level, lists keep
/// their order, so the same save always gives the same text.
///
/// Reading never throws and never invents progress:
/// - not JSON, not an object, no usable `saveVersion`, or a version newer than
///   this build: nothing is used (`SaveRead.usable` is false) and the caller
///   keeps the original text aside;
/// - an older version is upgraded through [_migrations], one step at a time;
/// - a damaged section is dropped on its own (one puzzle, one graph, the
///   settings, the session) and reported as a [SaveIssue]; the rest is kept.
///   A value that is not a clear `true` never counts as completion.
///
/// Unknown fields, at any level, are ignored and not written back. A future
/// build may add a field without a version change only if an older build
/// losing it is harmless; anything else needs a new `saveVersion` and a
/// migration.
String encodeSave(PlayerSave save) => jsonEncode(_canonical(saveToJson(save)));

Map<String, Object?> saveToJson(PlayerSave save) => {
      'saveVersion': currentSaveVersion,
      'puzzles': {
        for (final e in save.puzzles.entries) e.key: _puzzleToJson(e.value),
      },
      'settings': {'showBriefOnOpen': save.settings.showBriefOnOpen, 'language': save.settings.language},
      if (save.session case final session?)
        'session': {'worldId': session.worldId, 'puzzleId': session.puzzleId},
    };

Map<String, Object?> _puzzleToJson(PuzzleProgress p) => {
      'puzzleVersion': p.puzzleVersion,
      'completed': p.completed,
      if (p.best case final best?) 'best': _numbersToJson(best),
      if (p.lastRun case final run?)
        'lastRun': {'result': run.result.name, ..._numbersToJson(run.numbers)},
      if (p.solution case final graph?) 'solution': graph.toJson(),
      if (p.draft case final graph?) 'draft': graph.toJson(),
      'editedSinceRun': p.editedSinceRun,
    };

Map<String, Object?> _numbersToJson(RunNumbers n) => {
      'ops': n.ops,
      'peakAlloc': n.peakAlloc,
      'peakDepth': n.peakDepth,
      'blocks': n.blocks,
      'hintsUsed': n.hintsUsed,
    };

Object? _canonical(Object? value) => switch (value) {
      final Map<Object?, Object?> map => {
          for (final key in map.keys.map((k) => '$k').toList()..sort())
            key: _canonical(map[key]),
        },
      final List<Object?> list => [for (final item in list) _canonical(item)],
      _ => value,
    };

/// One thing that could not be read, and what was done about it.
final class SaveIssue {
  const SaveIssue(this.path, this.message);

  /// Where in the save, e.g. `puzzles.twin_beacons.draft`.
  final String path;
  final String message;

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

final class SaveRead {
  const SaveRead(this.save, this.issues, {this.usable = true});

  /// The save to play with: what could be read, defaults for the rest.
  final PlayerSave save;
  final List<SaveIssue> issues;

  /// False when nothing could be used; [save] is then a fresh save.
  final bool usable;
}

/// Upgrades keyed by the version they read: `_migrations[1]` would turn a
/// version 1 save into version 2. Empty — version 1 is the first format.
final Map<int, Map<String, Object?> Function(Map<String, Object?>)> _migrations = {};

SaveRead decodeSave(String source) {
  Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException {
    return const SaveRead(PlayerSave.fresh, [SaveIssue('', 'The save is not valid JSON.')], usable: false);
  }
  if (json is! Map<String, Object?>) {
    return const SaveRead(PlayerSave.fresh, [SaveIssue('', 'The save is not a JSON object.')], usable: false);
  }
  final version = json['saveVersion'];
  if (version is! int || version < 1) {
    return const SaveRead(PlayerSave.fresh, [SaveIssue('saveVersion', 'The save has no usable version.')],
        usable: false);
  }
  if (version > currentSaveVersion) {
    return SaveRead(
      PlayerSave.fresh,
      [SaveIssue('saveVersion', 'Version $version was written by a newer build (this one reads up to $currentSaveVersion).')],
      usable: false,
    );
  }
  var upgraded = json;
  for (var v = version; v < currentSaveVersion; v++) {
    final step = _migrations[v];
    if (step == null) {
      return SaveRead(PlayerSave.fresh, [SaveIssue('saveVersion', 'No upgrade from version $v.')], usable: false);
    }
    upgraded = step(upgraded);
  }
  return _Reader().read(upgraded);
}

final _id = RegExp(r'^[a-z][a-z0-9_]*$');

final class _Reader {
  final issues = <SaveIssue>[];

  void issue(String path, String message) => issues.add(SaveIssue(path, message));

  SaveRead read(Map<String, Object?> json) {
    final puzzles = <String, PuzzleProgress>{};
    final rawPuzzles = json['puzzles'];
    if (rawPuzzles is Map<String, Object?>) {
      for (final entry in rawPuzzles.entries) {
        final progress = _puzzle('puzzles.${entry.key}', entry.key, entry.value);
        if (progress != null) puzzles[entry.key] = progress;
      }
    } else if (rawPuzzles != null) {
      issue('puzzles', 'Not an object; puzzle progress was dropped.');
    }
    return SaveRead(
      PlayerSave(puzzles: puzzles, settings: _settings(json['settings']), session: _session(json['session'])),
      List.unmodifiable(issues),
    );
  }

  PuzzleProgress? _puzzle(String path, String id, Object? raw) {
    if (!_id.hasMatch(id)) {
      issue(path, 'Not a puzzle id; dropped.');
      return null;
    }
    if (raw is! Map<String, Object?>) {
      issue(path, 'Not an object; dropped.');
      return null;
    }
    var version = raw['puzzleVersion'];
    if (version is! int || version < 0) {
      issue('$path.puzzleVersion', 'Unreadable; treated as an older version of the puzzle.');
      version = 0;
    }
    final completedRaw = raw['completed'];
    final completed = completedRaw == true;
    if (completedRaw != null && completedRaw is! bool) {
      issue('$path.completed', 'Not true or false; not counted as completed.');
    }
    var best = _numbers('$path.best', raw['best']);
    if (best != null && !completed) {
      issue('$path.best', 'A best result without a completion; dropped.');
      best = null;
    }
    final edited = raw['editedSinceRun'];
    if (edited != null && edited is! bool) issue('$path.editedSinceRun', 'Not true or false; read as false.');
    return PuzzleProgress(
      puzzleVersion: version,
      completed: completed,
      best: best,
      lastRun: _run('$path.lastRun', raw['lastRun']),
      solution: completed ? _graph('$path.solution', raw['solution']) : _stray('$path.solution', raw['solution']),
      draft: _graph('$path.draft', raw['draft']),
      editedSinceRun: edited == true,
    );
  }

  BlockGraph? _stray(String path, Object? raw) {
    if (raw != null) issue(path, 'A solution without a completion; dropped.');
    return null;
  }

  RunNumbers? _numbers(String path, Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      issue(path, 'Not an object; dropped.');
      return null;
    }
    int? field(String key) {
      final v = raw[key];
      return v is int && v >= 0 ? v : null;
    }

    final ops = field('ops');
    final peakAlloc = field('peakAlloc');
    final peakDepth = field('peakDepth');
    final blocks = field('blocks');
    final hintsUsed = field('hintsUsed');
    if (ops == null || peakAlloc == null || peakDepth == null || blocks == null || hintsUsed == null) {
      issue(path, 'Needs ops, peakAlloc, peakDepth, blocks and hintsUsed as whole numbers; dropped.');
      return null;
    }
    return RunNumbers(ops: ops, peakAlloc: peakAlloc, peakDepth: peakDepth, blocks: blocks, hintsUsed: hintsUsed);
  }

  RunRecord? _run(String path, Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      issue(path, 'Not an object; dropped.');
      return null;
    }
    final name = raw['result'];
    final result = ResultKind.values.where((k) => k.name == name).firstOrNull;
    if (result == null) {
      issue('$path.result', 'Not a known result; the last run was dropped.');
      return null;
    }
    final numbers = _numbers(path, raw);
    return numbers == null ? null : RunRecord(result: result, numbers: numbers);
  }

  /// A saved program. It must decode and be structurally sound (every block
  /// known, every plug pointing at a block, no cycles) — an unfinished program
  /// with empty holes is fine. Anything else is dropped rather than shown.
  BlockGraph? _graph(String path, Object? raw) {
    if (raw == null) return null;
    if (raw is! Map<String, Object?>) {
      issue(path, 'Not a program; dropped.');
      return null;
    }
    final BlockGraph graph;
    try {
      graph = BlockGraph.fromJson(raw);
    } on Object catch (e) {
      // Hostile input can fail as a FormatException or a type error alike.
      issue(path, 'Not a readable program ($e); dropped.');
      return null;
    }
    final structure = GraphStructure.validate(graph);
    if (!structure.ok) {
      issue(path, 'The program is not put together correctly (${structure.messages.first.code}); dropped.');
      return null;
    }
    return graph;
  }

  PlayerSettings _settings(Object? raw) {
    if (raw == null) return PlayerSettings.defaults;
    if (raw is! Map<String, Object?>) {
      issue('settings', 'Not an object; defaults used.');
      return PlayerSettings.defaults;
    }
    final brief = raw['showBriefOnOpen'];
    if (brief != null && brief is! bool) {
      issue('settings.showBriefOnOpen', 'Not true or false; default used.');
    }
    // Saves before the language setting have none: English, silently.
    final language = raw['language'];
    if (language != null && !PlayerSettings.languages.contains(language)) {
      issue('settings.language', 'Not a supported language; English used.');
    }
    return PlayerSettings(
      showBriefOnOpen: brief is bool ? brief : PlayerSettings.defaults.showBriefOnOpen,
      language: PlayerSettings.languages.contains(language) ? language as String : PlayerSettings.defaults.language,
    );
  }

  CurrentSession? _session(Object? raw) {
    if (raw == null) return null;
    if (raw is Map<String, Object?>) {
      final world = raw['worldId'];
      final puzzle = raw['puzzleId'];
      if (world is String && _id.hasMatch(world) && puzzle is String && _id.hasMatch(puzzle)) {
        return CurrentSession(worldId: world, puzzleId: puzzle);
      }
    }
    issue('session', 'Not a world and puzzle id; dropped.');
    return null;
  }
}
