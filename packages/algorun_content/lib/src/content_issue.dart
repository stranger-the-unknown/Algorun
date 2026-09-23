/// Errors block a commit, warnings are advice, info records facts (such as a
/// reference solution's measured cost).
enum Severity { error, warning, info }

/// The pipeline's validation levels. A campaign puzzle is accepted only when
/// no level reports an error for it.
abstract final class Level {
  /// Schema and structure: the puzzle, the manifest, the reference file.
  static const schema = 1;

  /// Types and blocks: the allowlist, the block budget, language capabilities.
  static const blocks = 2;

  /// The reference rebuilt through the editor's own commands, and lowered.
  static const replay = 3;

  /// The real interpreter: visible and hidden cases, rejects, the oracle.
  static const execution = 4;

  /// Operation, memory, depth and block budgets; recorded metrics.
  static const performance = 5;

  /// Every puzzle and world reachable under the campaign unlock rules.
  static const progression = 6;

  /// The corpus: redundancy, coverage, difficulty, quality advice.
  static const corpus = 7;

  static const names = {
    schema: 'schema',
    blocks: 'blocks',
    replay: 'replay',
    execution: 'execution',
    performance: 'performance',
    progression: 'progression',
    corpus: 'corpus',
  };
}

/// One finding. [file] is relative to the puzzles root (`world_01/x.json`) or
/// the manifest name; [path] points into the JSON, `''` for the whole file.
/// [level] is the pipeline level that found it and [puzzle] the puzzle it
/// counts against, when there is one.
final class ContentIssue {
  const ContentIssue(this.severity, this.file, this.path, this.message, {this.level, this.puzzle});

  final Severity severity;
  final String file;
  final String path;
  final String message;
  final int? level;
  final String? puzzle;

  bool get isError => severity == Severity.error;

  ContentIssue about(String? puzzleId, {int? atLevel}) =>
      ContentIssue(severity, file, path, message, level: level ?? atLevel, puzzle: puzzle ?? puzzleId);

  @override
  String toString() {
    final where = path.isEmpty ? file : '$file $path';
    final stage = level == null ? '' : ' [L$level ${Level.names[level]}]';
    return '${severity.name.toUpperCase()}$stage $where: $message';
  }
}

/// Whether one puzzle made it through the pipeline.
final class PuzzleVerdict {
  const PuzzleVerdict({required this.id, required this.file, required this.campaign, required this.failed});

  final String id;
  final String file;

  /// Listed by a world (a dev probe is not).
  final bool campaign;

  /// The levels that reported an error against this puzzle.
  final Set<int> failed;

  bool get accepted => failed.isEmpty;
}

final class ContentReport {
  const ContentReport(this.issues, {this.puzzleCount = 0, this.verdicts = const [], this.coverage});

  final List<ContentIssue> issues;

  /// Puzzles that passed the schema.
  final int puzzleCount;

  /// One per puzzle file, in path order.
  final List<PuzzleVerdict> verdicts;

  /// The coverage matrix, when a manifest was given (`coverageMatrix`).
  final Map<String, Object?>? coverage;

  bool get ok => !issues.any((i) => i.isError);

  Iterable<ContentIssue> get errors => issues.where((i) => i.isError);
  Iterable<ContentIssue> get warnings =>
      issues.where((i) => i.severity == Severity.warning);
  Iterable<ContentIssue> get infos =>
      issues.where((i) => i.severity == Severity.info);
}

/// A puzzle file: its path relative to the puzzles root, and its text.
final class ContentFile {
  const ContentFile(this.path, this.source);

  final String path;
  final String source;
}
