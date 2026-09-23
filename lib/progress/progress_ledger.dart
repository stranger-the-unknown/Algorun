import 'package:algorun_engine/algorun_engine.dart';

import 'campaign.dart';
import 'save_data.dart';

/// Pure updates of a [PlayerSave]. Every function returns a new save and
/// leaves puzzles outside the campaign (the dev probes) untouched: they are
/// never recorded, so they can never affect progression.

/// The completion rule: a RUN completes its puzzle exactly when the test
/// runner's verdict is correct — every visible and hidden case right, within
/// every budget the puzzle sets (operations, per-case operations, memory,
/// depth; the block budget is checked before anything runs). A correct answer
/// over the operation budget is `operationLimit`, not correct, so it does not
/// complete a puzzle. Hints never matter.
bool completes(SuiteResult suite) => suite.kind == ResultKind.correct;

/// What opening a puzzle gives the editor.
final class OpenedPuzzle {
  const OpenedPuzzle({this.graph, this.puzzleChanged = false, this.progress});

  /// The program to restore: the draft, else the best solution, else none.
  final BlockGraph? graph;

  /// The saved progress was earned on another version of the puzzle.
  final bool puzzleChanged;
  final PuzzleProgress? progress;
}

/// What one RUN changed, for the results screen.
final class RunRecordOutcome {
  const RunRecordOutcome({
    this.firstCompletion = false,
    this.improved = const {},
    this.newSolution = false,
    this.opened = const [],
  });

  /// This run completed the puzzle for the first time.
  final bool firstCompletion;

  /// Best metrics this run beat (empty on a first completion).
  final Set<BestMetric> improved;

  /// This run's program is now the saved best solution.
  final bool newSolution;

  /// Worlds with puzzles that this run opened.
  final List<WorldDef> opened;
}

/// Opening [puzzle]: remember it as the session and hand back its program.
/// A locked puzzle is not opened.
///
/// Version policy: progress earned on another `version` of the puzzle keeps
/// its completion (unlocks never go backwards) and its draft (the player's
/// work, re-checked by RUN), but its best result, best solution and last run
/// are cleared — they measured a different puzzle.
(PlayerSave, OpenedPuzzle) openPuzzle(PlayerSave save, Campaign campaign, Puzzle puzzle) {
  final world = campaign.worldOf(puzzle.id);
  if (world == null || !evaluateCampaign(campaign, save).isPuzzleOpen(puzzle.id)) {
    return (save, const OpenedPuzzle());
  }
  final stored = save[puzzle.id];
  final current = _onVersion(stored, puzzle);
  var next = save.copyWith(session: CurrentSession(worldId: world.id, puzzleId: puzzle.id));
  if (stored != null && !identical(stored, current)) next = next.withPuzzle(puzzle.id, current);
  return (
    next,
    OpenedPuzzle(
      graph: current.draft ?? current.solution,
      puzzleChanged: stored != null && stored.puzzleVersion != puzzle.version,
      progress: stored == null ? null : current,
    ),
  );
}

/// The player changed the program: it becomes the draft.
PlayerSave saveDraft(PlayerSave save, Campaign campaign, Puzzle puzzle, BlockGraph graph, {bool edited = true}) {
  if (!campaign.contains(puzzle.id)) return save;
  final current = _onVersion(save[puzzle.id], puzzle);
  return save.withPuzzle(
    puzzle.id,
    current.copyWith(draft: graph, editedSinceRun: edited || current.editedSinceRun),
  );
}

/// A RUN of [graph] finished with [suite] (`hintsUsed` already stamped).
///
/// The last run is always replaced. Only a completing run touches the best
/// result: each metric keeps its lower value independently, and the program
/// becomes the best solution when it needs strictly fewer operations (the
/// first solution stays on a tie). A failing run never overwrites a success.
/// A run of a locked puzzle is not recorded.
(PlayerSave, RunRecordOutcome) recordRun(
  PlayerSave save,
  Campaign campaign,
  Puzzle puzzle,
  BlockGraph graph,
  SuiteResult suite,
) {
  if (!campaign.contains(puzzle.id)) return (save, const RunRecordOutcome());
  final before = evaluateCampaign(campaign, save);
  if (!before.isPuzzleOpen(puzzle.id)) return (save, const RunRecordOutcome());
  final current = _onVersion(save[puzzle.id], puzzle);
  final numbers = RunNumbers.of(suite.metrics);
  var progress = current.copyWith(
    draft: graph,
    editedSinceRun: false,
    lastRun: RunRecord(result: suite.kind, numbers: numbers),
  );
  if (completes(suite)) {
    final previous = current.best;
    final firstCompletion = !current.completed;
    final newSolution = previous == null || current.solution == null || numbers.ops < previous.ops;
    progress = progress.copyWith(
      completed: true,
      best: previous == null ? numbers : previous.bestWith(numbers),
      solution: newSolution ? graph : current.solution,
    );
    final next = save.withPuzzle(puzzle.id, progress);
    final after = evaluateCampaign(campaign, next);
    return (
      next,
      RunRecordOutcome(
        firstCompletion: firstCompletion,
        improved: previous == null ? const {} : previous.improvedBy(numbers),
        newSolution: newSolution,
        opened: [
          for (final w in campaign.manifest.worlds)
            if (w.puzzleIds.isNotEmpty && !before.isWorldOpen(w.id) && after.isWorldOpen(w.id)) w,
        ],
      ),
    );
  }
  return (save.withPuzzle(puzzle.id, progress), const RunRecordOutcome());
}

PuzzleProgress _onVersion(PuzzleProgress? stored, Puzzle puzzle) {
  if (stored == null) return PuzzleProgress(puzzleVersion: puzzle.version);
  if (stored.puzzleVersion == puzzle.version) return stored;
  return PuzzleProgress(
    puzzleVersion: puzzle.version,
    completed: stored.completed,
    draft: stored.draft,
    editedSinceRun: stored.draft != null,
  );
}
