import 'package:algorun_engine/algorun_engine.dart';

enum Severity { error, warning }

/// One finding. [file] is relative to the puzzles root (`world_01/x.json`) or
/// the manifest name; [path] points into the JSON, `''` for the whole file.
final class ContentIssue {
  const ContentIssue(this.severity, this.file, this.path, this.message);

  final Severity severity;
  final String file;
  final String path;
  final String message;

  bool get isError => severity == Severity.error;

  @override
  String toString() {
    final where = path.isEmpty ? file : '$file $path';
    return '${severity.name.toUpperCase()} $where: $message';
  }
}

final class ContentReport {
  const ContentReport(this.issues, {this.puzzleCount = 0});

  final List<ContentIssue> issues;

  /// Puzzles that passed the schema.
  final int puzzleCount;

  bool get ok => !issues.any((i) => i.isError);

  Iterable<ContentIssue> get errors => issues.where((i) => i.isError);
  Iterable<ContentIssue> get warnings => issues.where((i) => !i.isError);
}

/// A puzzle file: its path relative to the puzzles root, and its text.
final class ContentFile {
  const ContentFile(this.path, this.source);

  final String path;
  final String source;
}

/// Offline content gate. Nothing it reads is executed.
///
/// The single-puzzle rules are the engine's own schema
/// (`algorun_engine` → `readPuzzleJson`), so the game and this tool can never
/// disagree about what a valid puzzle is. On top of that it checks what only
/// the whole content set can show: duplicate ids, file locations the game can
/// load, and that worlds and puzzles point at each other.
///
/// Errors block a commit. Warnings are advice.
final class ContentValidator {
  const ContentValidator();

  /// One puzzle on its own: the schema, plus single-file advice.
  ContentReport validatePuzzleSource(String source, {String file = 'puzzle.json'}) {
    final issues = <ContentIssue>[];
    final puzzle = _readPuzzle(source, file, issues);
    return ContentReport(issues, puzzleCount: puzzle == null ? 0 : 1);
  }

  /// The whole content set. Files are checked in path order, so the same set
  /// always produces the same report.
  ContentReport validateContent({
    required List<ContentFile> puzzles,
    String? worldsSource,
    String worldsFile = 'worlds.json',
  }) {
    final issues = <ContentIssue>[];
    final files = [...puzzles]..sort((a, b) => a.path.compareTo(b.path));
    final byId = <String, ({String file, Puzzle puzzle})>{};

    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      final puzzle = _readPuzzle(file.source, path, issues);
      if (puzzle == null) continue;
      final taken = byId[puzzle.id];
      if (taken != null) {
        issues.add(ContentIssue(
          Severity.error,
          path,
          'id',
          'Puzzle id "${puzzle.id}" is also used by ${taken.file}.',
        ));
        continue;
      }
      byId[puzzle.id] = (file: path, puzzle: puzzle);
      final expected = '${puzzle.world}/${puzzle.id}.json';
      if (path != expected) {
        issues.add(ContentIssue(
          Severity.error,
          path,
          '',
          'The game loads this puzzle from $expected.',
        ));
      }
    }

    if (worldsSource != null) {
      _checkWorlds(worldsSource, worldsFile, byId, issues);
    }
    return ContentReport(issues, puzzleCount: byId.length);
  }

  Puzzle? _readPuzzle(String source, String file, List<ContentIssue> issues) {
    final read = readPuzzleJson(source);
    for (final issue in read.issues) {
      issues.add(ContentIssue(Severity.error, file, issue.path, issue.message));
    }
    final puzzle = read.puzzle;
    if (puzzle == null) return null;

    if (puzzle.hints.isEmpty) {
      issues.add(ContentIssue(Severity.warning, file, 'hints', 'No hints provided.'));
    }
    for (final id in const [BlockIds.fnDef, BlockIds.fnCall]) {
      if (puzzle.blocks.allow.contains(id)) {
        issues.add(ContentIssue(
          Severity.warning,
          file,
          'blocks.allow',
          '"$id" is hidden from the editor and cannot run yet.',
        ));
      }
    }
    if (puzzle.blocks.allow.length == BlockIds.all.length) {
      issues.add(ContentIssue(
        Severity.warning,
        file,
        'blocks.allow',
        'Allows the whole catalog. The palette is meant to be the puzzle\'s own subset.',
      ));
    }
    return puzzle;
  }

  void _checkWorlds(
    String source,
    String file,
    Map<String, ({String file, Puzzle puzzle})> puzzles,
    List<ContentIssue> issues,
  ) {
    final read = readWorldsJson(source);
    for (final issue in read.issues) {
      issues.add(ContentIssue(Severity.error, file, issue.path, issue.message));
    }
    final manifest = read.manifest;
    if (manifest == null) return;

    final concepts = {for (final w in manifest.worlds) ...w.concepts};
    final listedBy = <String, String>{};
    for (final (i, world) in manifest.worlds.indexed) {
      for (final (j, id) in world.puzzleIds.indexed) {
        listedBy[id] = world.id;
        final entry = puzzles[id];
        if (entry == null) {
          issues.add(ContentIssue(
            Severity.error,
            file,
            'worlds[$i].puzzles[$j]',
            'Lists "$id", but no valid puzzle has that id.',
          ));
        } else if (entry.puzzle.world != world.id) {
          issues.add(ContentIssue(
            Severity.error,
            file,
            'worlds[$i].puzzles[$j]',
            '"$id" says it belongs to ${entry.puzzle.world}, not ${world.id}.',
          ));
        }
      }
      for (final (j, prerequisite) in world.prerequisites.indexed) {
        if (!concepts.contains(prerequisite)) {
          issues.add(ContentIssue(
            Severity.warning,
            file,
            'worlds[$i].prerequisites[$j]',
            'No world teaches "$prerequisite".',
          ));
        }
      }
    }

    final ids = puzzles.keys.toList()..sort();
    for (final id in ids) {
      final (:file, :puzzle) = puzzles[id]!;
      if (manifest.byId(puzzle.world) == null) {
        issues.add(ContentIssue(
          Severity.error,
          file,
          'world',
          'World "${puzzle.world}" is not in the worlds manifest.',
        ));
      } else if (!listedBy.containsKey(id)) {
        issues.add(ContentIssue(
          Severity.warning,
          file,
          '',
          'No world lists this puzzle, so no player can reach it.',
        ));
      }
      for (final (j, prerequisite) in puzzle.prerequisites.indexed) {
        if (!concepts.contains(prerequisite)) {
          issues.add(ContentIssue(
            Severity.warning,
            file,
            'prerequisites[$j]',
            'No world teaches "$prerequisite".',
          ));
        }
      }
    }
  }
}
