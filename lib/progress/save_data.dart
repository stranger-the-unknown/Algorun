import 'package:algorun_engine/algorun_engine.dart';

/// The save format this build writes. `save_codec.dart` reads it, migrates
/// older ones and documents the unknown-field policy.
const currentSaveVersion = 1;

/// The numbers one RUN produced, as the results screen shows them.
///
/// `ops`, `peakAlloc` and `peakDepth` are the worst case across the puzzle's
/// cases (`SuiteResult.metrics`), `blocks` counts the program's blocks and
/// `hintsUsed` the hints revealed in that visit. Lower is better for all five.
final class RunNumbers {
  const RunNumbers({
    required this.ops,
    required this.peakAlloc,
    required this.peakDepth,
    required this.blocks,
    required this.hintsUsed,
  });

  factory RunNumbers.of(RunMetrics metrics) => RunNumbers(
        ops: metrics.ops,
        peakAlloc: metrics.peakAlloc,
        peakDepth: metrics.peakDepth,
        blocks: metrics.blocks,
        hintsUsed: metrics.hintsUsed,
      );

  final int ops;
  final int peakAlloc;
  final int peakDepth;
  final int blocks;
  final int hintsUsed;

  int of(BestMetric metric) => switch (metric) {
        BestMetric.ops => ops,
        BestMetric.peakAlloc => peakAlloc,
        BestMetric.peakDepth => peakDepth,
        BestMetric.blocks => blocks,
        BestMetric.hintsUsed => hintsUsed,
      };

  /// Every metric keeps the lower of the two, independently: the fewest
  /// operations and the fewest blocks may come from different runs.
  RunNumbers bestWith(RunNumbers other) => RunNumbers(
        ops: ops < other.ops ? ops : other.ops,
        peakAlloc: peakAlloc < other.peakAlloc ? peakAlloc : other.peakAlloc,
        peakDepth: peakDepth < other.peakDepth ? peakDepth : other.peakDepth,
        blocks: blocks < other.blocks ? blocks : other.blocks,
        hintsUsed: hintsUsed < other.hintsUsed ? hintsUsed : other.hintsUsed,
      );

  /// The metrics on which [candidate] is strictly better than this.
  Set<BestMetric> improvedBy(RunNumbers candidate) => {
        for (final metric in BestMetric.values)
          if (candidate.of(metric) < of(metric)) metric,
      };
}

/// The independently tracked best metrics. There is no combined score.
enum BestMetric { ops, peakAlloc, peakDepth, blocks, hintsUsed }

/// The latest RUN of a puzzle, whatever its verdict. Kept apart from the best
/// result so a failed run never overwrites a success.
final class RunRecord {
  const RunRecord({required this.result, required this.numbers});

  final ResultKind result;
  final RunNumbers numbers;
}

/// What the player has done on one campaign puzzle.
final class PuzzleProgress {
  const PuzzleProgress({
    required this.puzzleVersion,
    this.completed = false,
    this.best,
    this.solution,
    this.draft,
    this.lastRun,
    this.editedSinceRun = false,
  });

  /// The puzzle's `version` these results were earned on.
  final int puzzleVersion;

  /// Set once by a correct RUN (see `completes` in `progress_ledger.dart`) and
  /// never taken back. Stored plainly because progression depends on it.
  final bool completed;

  /// Best metrics over correct runs of [puzzleVersion]; null until completed.
  final RunNumbers? best;

  /// The program of the correct run with the fewest operations (the earlier
  /// one on a tie). The player can load it back into the editor.
  final BlockGraph? solution;

  /// The program as the player last left it in the editor.
  final BlockGraph? draft;

  final RunRecord? lastRun;

  /// Whether [draft] changed after the last RUN (or there was no RUN yet).
  final bool editedSinceRun;

  static const _keep = Object();

  PuzzleProgress copyWith({
    int? puzzleVersion,
    bool? completed,
    Object? best = _keep,
    Object? solution = _keep,
    Object? draft = _keep,
    Object? lastRun = _keep,
    bool? editedSinceRun,
  }) =>
      PuzzleProgress(
        puzzleVersion: puzzleVersion ?? this.puzzleVersion,
        completed: completed ?? this.completed,
        best: identical(best, _keep) ? this.best : best as RunNumbers?,
        solution: identical(solution, _keep) ? this.solution : solution as BlockGraph?,
        draft: identical(draft, _keep) ? this.draft : draft as BlockGraph?,
        lastRun: identical(lastRun, _keep) ? this.lastRun : lastRun as RunRecord?,
        editedSinceRun: editedSinceRun ?? this.editedSinceRun,
      );
}

/// Player preferences.
final class PlayerSettings {
  const PlayerSettings({this.showBriefOnOpen = true, this.language = 'en'});

  /// Whether a puzzle opens with its BRIEF expanded.
  final bool showBriefOnOpen;

  /// The language of every player-facing text: `en` or `tr`. Block names
  /// (IF, WHILE, RETURN…) stay English in every language.
  final String language;

  static const languages = ['en', 'tr'];

  static const defaults = PlayerSettings();

  PlayerSettings copyWith({bool? showBriefOnOpen, String? language}) => PlayerSettings(
        showBriefOnOpen: showBriefOnOpen ?? this.showBriefOnOpen,
        language: language ?? this.language,
      );
}

/// The puzzle the player was last in, for CONTINUE. The editable program is
/// that puzzle's [PuzzleProgress.draft]; nothing of a run is kept.
final class CurrentSession {
  const CurrentSession({required this.worldId, required this.puzzleId});

  final String worldId;
  final String puzzleId;
}

/// Everything saved on the device. Only player state: no hidden tests, no
/// reference solutions, no IR, nothing executable. Which worlds are open is
/// derived from it (`evaluateCampaign`), never stored.
final class PlayerSave {
  const PlayerSave({
    this.puzzles = const {},
    this.settings = PlayerSettings.defaults,
    this.session,
  });

  /// A fresh install.
  static const fresh = PlayerSave();

  /// Keyed by puzzle id. May hold ids the current campaign no longer lists;
  /// progression ignores them.
  final Map<String, PuzzleProgress> puzzles;
  final PlayerSettings settings;
  final CurrentSession? session;

  PuzzleProgress? operator [](String puzzleId) => puzzles[puzzleId];

  static const _keep = Object();

  PlayerSave copyWith({
    Map<String, PuzzleProgress>? puzzles,
    PlayerSettings? settings,
    Object? session = _keep,
  }) =>
      PlayerSave(
        puzzles: puzzles ?? this.puzzles,
        settings: settings ?? this.settings,
        session: identical(session, _keep) ? this.session : session as CurrentSession?,
      );

  PlayerSave withPuzzle(String puzzleId, PuzzleProgress progress) =>
      copyWith(puzzles: {...puzzles, puzzleId: progress});
}
