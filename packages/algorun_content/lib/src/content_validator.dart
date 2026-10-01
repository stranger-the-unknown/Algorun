import 'package:algorun_engine/algorun_engine.dart';

import 'content_issue.dart';
import 'content_spec.dart';
import 'coverage.dart';
import 'difficulty.dart';
import 'progression_check.dart';
import 'redundancy.dart';
import 'reference_check.dart';

/// Offline content gate — the content pipeline. No content is ever executed as
/// code: reference solutions are block graphs, and they run only inside the
/// engine's sandboxed interpreter.
///
/// A candidate puzzle is a puzzle JSON plus its reference file. It is
/// **accepted** only when no level reports an error against it:
///
/// 1. **schema** — the engine's own closed schema (`readPuzzleJson`, the same
///    code the game loads with), file locations, the manifest, the reference
///    file and its spec;
/// 2. **blocks** — allowlist, block budget, the language capability audit
///    (`content/capabilities.json`);
/// 3. **replay** — the reference rebuilt through the editor's commands, and
///    lowered;
/// 4. **execution** — every visible and hidden case through the real
///    `TestRunner`, every reject ending in its declared verdict, the
///    independent oracle agreeing with the fixtures and with the reference;
/// 5. **performance** — budgets, recorded metrics, declared performance;
/// 6. **progression** — reachable under the campaign unlock rules;
/// 7. **corpus** — not a near duplicate; coverage and difficulty advice.
///
/// Errors block a commit. Warnings are advice. Info records facts.
final class ContentValidator {
  const ContentValidator({this.checker = const ReferenceChecker()});

  final ReferenceChecker checker;

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
  /// [capabilitiesSource] and [targetsSource] are `content/capabilities.json`
  /// and `content/coverage_targets.json`.
  ContentReport validateContent({
    required List<ContentFile> puzzles,
    String? worldsSource,
    String worldsFile = 'worlds.json',
    List<ContentFile>? references,
    String referencesLabel = 'references',
    String? capabilitiesSource,
    String? targetsSource,
  }) {
    final issues = <ContentIssue>[];
    final files = [...puzzles]..sort((a, b) => a.path.compareTo(b.path));
    final byId = <String, ({String file, Puzzle puzzle})>{};
    final unread = <String>[];

    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      final puzzle = _readPuzzle(file.source, path, issues);
      if (puzzle == null) {
        unread.add(path);
        continue;
      }
      final taken = byId[puzzle.id];
      if (taken != null) {
        issues.add(ContentIssue(Severity.error, path, 'id', 'Puzzle id "${puzzle.id}" is also used by ${taken.file}.',
            level: Level.schema));
        unread.add(path);
        continue;
      }
      byId[puzzle.id] = (file: path, puzzle: puzzle);
      final expected = '${puzzle.world}/${puzzle.id}.json';
      if (path != expected) {
        issues.add(ContentIssue(Severity.error, path, '', 'The game loads this puzzle from $expected.',
            level: Level.schema, puzzle: puzzle.id));
      }
    }

    Capabilities? capabilities;
    if (capabilitiesSource != null) {
      try {
        capabilities = Capabilities.parse(capabilitiesSource);
      } on FormatException catch (e) {
        issues.add(ContentIssue(Severity.error, 'capabilities.json', '', e.message, level: Level.schema));
      }
    }
    CoverageTargets? targets;
    if (targetsSource != null) {
      try {
        targets = CoverageTargets.parse(targetsSource);
      } on Object catch (e) {
        issues.add(ContentIssue(Severity.error, 'coverage_targets.json', '', '$e', level: Level.schema));
      }
    }

    final manifest = worldsSource == null ? null : _checkWorlds(worldsSource, worldsFile, byId, issues);
    final listed = manifest == null ? null : {for (final w in manifest.worlds) ...w.puzzleIds};
    final checked = _checkReferences(byId, listed, references, referencesLabel, capabilities, issues);

    Map<String, Object?>? coverage;
    if (manifest != null) {
      final campaign = {
        for (final id in listed!)
          if (byId[id] != null) id: byId[id]!.puzzle,
      };
      issues.addAll(checkProgression(
        manifest: manifest,
        listed: campaign,
        worldsFile: worldsFile,
        puzzleFiles: {for (final id in campaign.keys) id: byId[id]!.file},
      ));
      coverage = _corpus(manifest, byId, checked, capabilities, targets, issues);
    }

    // Verdicts: every error counts against the puzzle it names, or the
    // puzzle whose file (or reference file) it is in.
    final fileToId = <String, String>{
      for (final e in byId.entries) e.value.file: e.key,
      for (final e in byId.entries) '$referencesLabel/${e.value.puzzle.world}/${e.key}.json': e.key,
    };
    final failed = <String, Set<int>>{};
    for (final issue in issues.where((i) => i.isError)) {
      final id = issue.puzzle ?? fileToId[issue.file] ?? (unread.contains(issue.file) ? issue.file : null);
      if (id == null) continue;
      (failed[id] ??= {}).add(issue.level ?? Level.schema);
    }
    final verdicts = [
      for (final e in byId.entries)
        PuzzleVerdict(
          id: e.key,
          file: e.value.file,
          campaign: listed?.contains(e.key) ?? false,
          failed: failed[e.key] ?? const {},
        ),
      for (final path in unread)
        PuzzleVerdict(id: path, file: path, campaign: false, failed: failed[path] ?? {Level.schema}),
    ]..sort((a, b) => a.file.compareTo(b.file));
    return ContentReport(issues, puzzleCount: byId.length, verdicts: verdicts, coverage: coverage);
  }

  /// Level 7 over the campaign: redundancy, difficulty advice, coverage.
  Map<String, Object?> _corpus(
    WorldsManifest manifest,
    Map<String, ({String file, Puzzle puzzle})> puzzles,
    Map<String, CheckedReference> checked,
    Capabilities? capabilities,
    CoverageTargets? targets,
    List<ContentIssue> issues,
  ) {
    final fingerprints = <Fingerprint>[];
    final entries = <CoverageEntry>[];
    var order = 0;
    for (final world in manifest.worlds) {
      for (final id in world.puzzleIds) {
        order++;
        final entry = puzzles[id];
        final reference = checked[id];
        final spec = reference?.spec;
        final solution = reference?.solution;
        // Only puzzles whose reference proved them count.
        if (entry == null || spec == null || solution == null) continue;
        entries.add(CoverageEntry(puzzle: entry.puzzle, world: world, spec: spec));
        fingerprints.add(Fingerprint.of(entry.puzzle, spec, solution, order));
        final mismatch = difficultyMismatch(entry.puzzle, DifficultySignals.of(entry.puzzle, spec, solution));
        if (mismatch != null) {
          issues.add(ContentIssue(Severity.warning, entry.file, 'tier', mismatch, level: Level.corpus, puzzle: id));
        }
      }
    }
    for (final pair in redundancyReport(fingerprints)) {
      final later = puzzles[pair.later.puzzleId]!.file;
      final sim = (pair.similarity * 100).round();
      final shape = pair.sameSkeleton ? 'the same program shape' : 'a different program shape';
      if (pair.kind == Redundancy.nearDuplicate) {
        issues.add(ContentIssue(
          Severity.error,
          later,
          '',
          'Near duplicate of ${pair.earlier.puzzleId}: pattern "${pair.later.pattern}" vs '
          '"${pair.earlier.pattern}", the same inputs and output, $shape, $sim% block similarity. '
          'Change the reasoning, not the story.',
          level: Level.corpus,
          puzzle: pair.later.puzzleId,
        ));
      } else {
        issues.add(ContentIssue(
          Severity.info,
          later,
          '',
          'Related to ${pair.earlier.puzzleId} (pattern "${pair.later.pattern}" vs "${pair.earlier.pattern}", '
          '$shape, $sim% block similarity).',
          level: Level.corpus,
          puzzle: pair.later.puzzleId,
        ));
      }
    }
    final matrix = coverageMatrix(manifest: manifest, entries: entries, capabilities: capabilities, targets: targets);
    for (final gap in (matrix['gaps']! as List<Object?>).cast<Map<String, Object?>>()) {
      final note = gap['note'] == null ? '' : ' (${gap['note']})';
      final what = switch (gap['area']) {
        'tiers' => '${gap['id']} has no tier ${(gap['missing']! as List).join(', ')} puzzle',
        _ => '${gap['area']} ${gap['id']}: ${gap['have']} of ${gap['want']}',
      };
      issues.add(ContentIssue(Severity.info, 'coverage', gap['area']! as String, 'Gap: $what$note.',
          level: Level.corpus));
    }
    return matrix;
  }

  /// Every puzzle a player can reach must declare reference metadata and a
  /// spec, and every puzzle that declares it must be proven by its reference
  /// file. Returns what the references gave the corpus checks.
  Map<String, CheckedReference> _checkReferences(
    Map<String, ({String file, Puzzle puzzle})> puzzles,
    Set<String>? listed,
    List<ContentFile>? references,
    String label,
    Capabilities? capabilities,
    List<ContentIssue> issues,
  ) {
    final out = <String, CheckedReference>{};
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
            level: Level.schema,
            puzzle: id,
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
          level: Level.replay,
        ));
      }
      return out;
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
        issues.add(ContentIssue(Severity.error, file, 'reference', 'No reference solution at $label/$path.',
            level: Level.schema, puzzle: puzzle.id));
        continue;
      }
      final result = checker.check(
        puzzle,
        source,
        '$label/$path',
        issues,
        campaign: listed?.contains(puzzle.id) ?? false,
        capabilities: capabilities,
      );
      if (result != null) out[puzzle.id] = result;
    }
    final orphans = byPath.keys.where((p) => !expected.contains(p)).toList()..sort();
    for (final path in orphans) {
      issues.add(ContentIssue(Severity.error, '$label/$path', '', 'No puzzle with reference metadata lives at $path.',
          level: Level.schema));
    }
    return out;
  }

  Puzzle? _readPuzzle(String source, String file, List<ContentIssue> issues) {
    final read = readPuzzleJson(source);
    for (final issue in read.issues) {
      issues.add(ContentIssue(Severity.error, file, issue.path, issue.message, level: Level.schema));
    }
    final puzzle = read.puzzle;
    if (puzzle == null) return null;
    void add(Severity severity, int level, String path, String message) =>
        issues.add(ContentIssue(severity, file, path, message, level: level, puzzle: puzzle.id));

    for (final (list, cases) in [
      ('visible', puzzle.visibleTests),
      ('hidden', puzzle.hiddenTests),
    ]) {
      for (final (i, testCase) in cases.indexed) {
        if (!compareOutputs(puzzle.outputValidator, testCase.output, testCase.output)) {
          add(Severity.error, Level.schema, 'fixtures.$list[$i].out',
              'This answer does not satisfy its own validator '
              '"${puzzle.outputValidator.name}", so no program could match it.');
        }
      }
    }

    if (puzzle.hints.isEmpty) {
      add(Severity.warning, Level.corpus, 'hints', 'No hints provided.');
    }
    // Hints are shown to players as written, so they must speak in the game's
    // words and must not quote a hidden case.
    for (final (i, hint) in puzzle.hints.indexed) {
      for (final id in BlockIds.all) {
        if (hint.contains(id)) {
          add(Severity.warning, Level.corpus, 'hints[$i]',
              'Mentions the internal block id "$id"; say ${BlockChrome.labelOf(id)} instead.');
        }
      }
      for (final hidden in puzzle.hiddenTests) {
        if (hidden.id.length >= 4 && hint.contains(hidden.id)) {
          add(Severity.warning, Level.corpus, 'hints[$i]',
              'Mentions the hidden case "${hidden.id}", which players must not see.');
        }
      }
    }
    // FUNCTION comes from the puzzle's `functions`, never the palette; CALL
    // needs a function to call (L2).
    if (puzzle.blocks.allow.contains(BlockIds.fnDef)) {
      add(Severity.warning, Level.blocks, 'blocks.allow',
          '"${BlockIds.fnDef}" is never in the palette: declare the function in "functions".');
    }
    for (final id in BlockIds.calls) {
      if (puzzle.blocks.allow.contains(id) &&
          !puzzle.functions.any((f) => f.params.length == BlockIds.callArity(id))) {
        add(Severity.warning, Level.blocks, 'blocks.allow', '"$id" has no function with that many values to call.');
      }
    }
    if (puzzle.blocks.allow.length == BlockIds.all.length) {
      add(Severity.warning, Level.blocks, 'blocks.allow',
          'Allows the whole catalog. The palette is meant to be the puzzle\'s own subset.');
    }
    return puzzle;
  }

  /// The manifest's own structure (level 1). Returns it, or null when it did
  /// not load. Reachability is level 6 (`checkProgression`).
  WorldsManifest? _checkWorlds(
    String source,
    String file,
    Map<String, ({String file, Puzzle puzzle})> puzzles,
    List<ContentIssue> issues,
  ) {
    final read = readWorldsJson(source);
    for (final issue in read.issues) {
      issues.add(ContentIssue(Severity.error, file, issue.path, issue.message, level: Level.schema));
    }
    final manifest = read.manifest;
    if (manifest == null) return null;

    final listedBy = <String, String>{};
    for (final (i, world) in manifest.worlds.indexed) {
      for (final (j, id) in world.puzzleIds.indexed) {
        final other = listedBy[id];
        if (other != null) {
          issues.add(ContentIssue(Severity.error, file, 'worlds[$i].puzzles[$j]', '"$id" is also listed by $other.',
              level: Level.schema, puzzle: id));
          continue;
        }
        listedBy[id] = world.id;
        final entry = puzzles[id];
        if (entry == null) {
          issues.add(ContentIssue(Severity.error, file, 'worlds[$i].puzzles[$j]',
              'Lists "$id", but no valid puzzle has that id.',
              level: Level.schema));
        } else if (entry.puzzle.world != world.id) {
          issues.add(ContentIssue(Severity.error, file, 'worlds[$i].puzzles[$j]',
              '"$id" says it belongs to ${entry.puzzle.world}, not ${world.id}.',
              level: Level.schema, puzzle: id));
        }
      }
    }

    final ids = puzzles.keys.toList()..sort();
    for (final id in ids) {
      final (:file, :puzzle) = puzzles[id]!;
      if (manifest.byId(puzzle.world) == null) {
        issues.add(ContentIssue(Severity.error, file, 'world', 'World "${puzzle.world}" is not in the worlds manifest.',
            level: Level.schema, puzzle: id));
      } else if (!listedBy.containsKey(id)) {
        issues.add(ContentIssue(Severity.warning, file, '', 'No world lists this puzzle, so no player can reach it.',
            level: Level.progression, puzzle: id));
      }
    }
    // A manifest that lists a puzzle it cannot load is reported above; the
    // rest of the pipeline works on what did load.
    return WorldsManifest([
      for (final w in manifest.worlds)
        WorldDef(
          id: w.id,
          title: w.title,
          index: w.index,
          puzzleIds: [for (final id in w.puzzleIds) if (puzzles[id]?.puzzle.world == w.id && listedBy[id] == w.id) id],
          concepts: w.concepts,
          prerequisites: w.prerequisites,
        ),
    ]);
  }
}
