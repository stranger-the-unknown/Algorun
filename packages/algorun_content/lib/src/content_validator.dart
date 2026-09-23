import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'reference_check.dart';

/// Offline content gate. No content is ever executed as code: reference
/// solutions are block graphs, and they run only inside the engine's sandboxed
/// interpreter.
///
/// The single-puzzle rules are the engine's own schema
/// (`algorun_engine` → `readPuzzleJson`), so the game and this tool can never
/// disagree about what a valid puzzle is. On top of that it checks what only
/// the whole content set can show: duplicate ids, file locations the game can
/// load, that worlds and puzzles point at each other, and — for every puzzle a
/// player can reach — that a reference solution proves it solvable
/// ([ReferenceChecker]).
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
  ///
  /// [references] are reference files, each at `<world>/<id>.json` relative to
  /// the references root ([referencesLabel] names that root in the report).
  /// Leave it null to skip executing references; the report then says so.
  ContentReport validateContent({
    required List<ContentFile> puzzles,
    String? worldsSource,
    String worldsFile = 'worlds.json',
    List<ContentFile>? references,
    String referencesLabel = 'references',
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

    final listed = worldsSource == null
        ? null
        : _checkWorlds(worldsSource, worldsFile, byId, issues);
    _checkReferences(byId, listed, references, referencesLabel, issues);
    return ContentReport(issues, puzzleCount: byId.length);
  }

  /// Every puzzle a player can reach must declare reference metadata, and every
  /// puzzle that declares it must be proven by its reference file.
  void _checkReferences(
    Map<String, ({String file, Puzzle puzzle})> puzzles,
    Set<String>? listed,
    List<ContentFile>? references,
    String label,
    List<ContentIssue> issues,
  ) {
    final ids = puzzles.keys.toList()..sort();
    if (listed != null) {
      for (final id in ids) {
        final (:file, :puzzle) = puzzles[id]!;
        if (listed.contains(id) && puzzle.reference == null) {
          issues.add(ContentIssue(
            Severity.error,
            file,
            'reference',
            'A puzzle players can reach needs reference metadata and a reference solution.',
          ));
        }
      }
    }
    final declared = [
      for (final id in ids)
        if (puzzles[id]!.puzzle.reference != null) puzzles[id]!,
    ];
    if (references == null) {
      if (declared.isNotEmpty) {
        issues.add(ContentIssue(
          Severity.warning,
          label,
          '',
          'Reference solutions were not checked: no references were given.',
        ));
      }
      return;
    }

    final byPath = {
      for (final ref in references) ref.path.replaceAll(r'\', '/'): ref.source,
    };
    final expected = <String>{};
    for (final (:file, :puzzle) in declared) {
      final path = '${puzzle.world}/${puzzle.id}.json';
      expected.add(path);
      final source = byPath[path];
      if (source == null) {
        issues.add(ContentIssue(
          Severity.error,
          file,
          'reference',
          'No reference solution at $label/$path.',
        ));
        continue;
      }
      const ReferenceChecker().check(puzzle, source, '$label/$path', issues);
    }
    final orphans = byPath.keys.where((p) => !expected.contains(p)).toList()..sort();
    for (final path in orphans) {
      issues.add(ContentIssue(
        Severity.error,
        '$label/$path',
        '',
        'No puzzle with reference metadata lives at $path.',
      ));
    }
  }

  Puzzle? _readPuzzle(String source, String file, List<ContentIssue> issues) {
    final read = readPuzzleJson(source);
    for (final issue in read.issues) {
      issues.add(ContentIssue(Severity.error, file, issue.path, issue.message));
    }
    final puzzle = read.puzzle;
    if (puzzle == null) return null;

    for (final (list, cases) in [
      ('visible', puzzle.visibleTests),
      ('hidden', puzzle.hiddenTests),
    ]) {
      for (final (i, testCase) in cases.indexed) {
        if (!compareOutputs(puzzle.outputValidator, testCase.output, testCase.output)) {
          issues.add(ContentIssue(
            Severity.error,
            file,
            'fixtures.$list[$i].out',
            'This answer does not satisfy its own validator '
            '"${puzzle.outputValidator.name}", so no program could match it.',
          ));
        }
      }
    }

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

  /// Returns the ids the manifest lists, or null when it did not load.
  Set<String>? _checkWorlds(
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
    if (manifest == null) return null;

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
    return listedBy.keys.toSet();
  }
}
