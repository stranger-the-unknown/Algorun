import 'package:algorun_engine/algorun_engine.dart';

import 'save_data.dart';

/// The playable campaign: the worlds manifest and every puzzle a world lists,
/// in manifest order. Puzzles no world lists (the dev probes) are not part of
/// it and never affect progression.
final class Campaign {
  Campaign(this.manifest, Map<String, Puzzle> puzzles)
      : puzzles = Map.unmodifiable({
          for (final world in manifest.worlds)
            for (final id in world.puzzleIds)
              id: ?puzzles[id],
        }) {
    for (final world in manifest.worlds) {
      for (final id in world.puzzleIds) {
        if (!this.puzzles.containsKey(id)) {
          throw ArgumentError('World ${world.id} lists $id, which was not loaded.');
        }
      }
    }
  }

  final WorldsManifest manifest;
  final Map<String, Puzzle> puzzles;

  bool contains(String puzzleId) => puzzles.containsKey(puzzleId);

  WorldDef? worldOf(String puzzleId) {
    for (final world in manifest.worlds) {
      if (world.puzzleIds.contains(puzzleId)) return world;
    }
    return null;
  }
}

enum WorldStatus {
  /// A prerequisite concept is not mastered yet.
  locked,

  /// Open, with puzzles still to solve.
  open,

  /// Open and every puzzle solved.
  completed,

  /// Open, but no puzzles have shipped for it yet.
  empty,
}

enum PuzzleStatus { locked, open, inProgress, completed }

/// Where the player stands. Derived from the save and the content every time
/// — never stored — so a content update re-evaluates it and nothing can
/// drift.
final class CampaignProgress {
  const CampaignProgress._({
    required this.mastered,
    required this.worlds,
    required this.puzzles,
    required this.missing,
    required this.currentPuzzleId,
  });

  /// Concepts taught by a completed world.
  final Set<String> mastered;
  final Map<String, WorldStatus> worlds;

  /// Campaign puzzles only.
  final Map<String, PuzzleStatus> puzzles;

  /// For a locked world or puzzle: the concepts it still waits for.
  final Map<String, List<String>> missing;

  /// The saved session's puzzle, when it is still an open campaign puzzle.
  final String? currentPuzzleId;

  WorldStatus worldStatus(String worldId) => worlds[worldId] ?? WorldStatus.locked;

  PuzzleStatus puzzleStatus(String puzzleId) => puzzles[puzzleId] ?? PuzzleStatus.locked;

  bool isWorldOpen(String worldId) => worldStatus(worldId) != WorldStatus.locked;

  bool isPuzzleOpen(String puzzleId) =>
      puzzles.containsKey(puzzleId) && puzzleStatus(puzzleId) != PuzzleStatus.locked;

  List<String> missingFor(String id) => missing[id] ?? const [];

  int get solvedCount => puzzles.values.where((s) => s == PuzzleStatus.completed).length;

  int get puzzleCount => puzzles.length;
}

/// Where the player stands, by the campaign unlock rules (`evaluateUnlocks`
/// in the engine — the same function the content validator uses to prove
/// every puzzle reachable): a world opens when its prerequisite concepts are
/// mastered or one of its puzzles is solved; it completes when every puzzle it
/// lists is solved (an empty world as soon as it opens); a complete world
/// masters its concepts; a puzzle opens when its world is open and its own
/// prerequisites are mastered or taught by that world.
CampaignProgress evaluateCampaign(Campaign campaign, PlayerSave save) {
  final completed = {
    for (final id in campaign.puzzles.keys)
      if (save[id]?.completed ?? false) id,
  };
  final unlocks = evaluateUnlocks(
    campaign.manifest,
    {for (final e in campaign.puzzles.entries) e.key: e.value.prerequisites},
    completed,
  );

  final worldStatus = <String, WorldStatus>{};
  final puzzleStatus = <String, PuzzleStatus>{};
  for (final w in campaign.manifest.worlds) {
    if (!unlocks.openWorlds.contains(w.id)) {
      worldStatus[w.id] = WorldStatus.locked;
    } else if (w.puzzleIds.isEmpty) {
      worldStatus[w.id] = WorldStatus.empty;
    } else {
      worldStatus[w.id] = unlocks.completeWorlds.contains(w.id) ? WorldStatus.completed : WorldStatus.open;
    }
    for (final id in w.puzzleIds) {
      final progress = save[id];
      if (completed.contains(id)) {
        puzzleStatus[id] = PuzzleStatus.completed;
      } else if (!unlocks.openPuzzles.contains(id)) {
        puzzleStatus[id] = PuzzleStatus.locked;
      } else if (progress != null && (progress.draft != null || progress.lastRun != null)) {
        puzzleStatus[id] = PuzzleStatus.inProgress;
      } else {
        puzzleStatus[id] = PuzzleStatus.open;
      }
    }
  }

  final session = save.session?.puzzleId;
  final current = session != null && puzzleStatus.containsKey(session) &&
          puzzleStatus[session] != PuzzleStatus.locked
      ? session
      : null;

  return CampaignProgress._(
    mastered: unlocks.mastered,
    worlds: Map.unmodifiable(worldStatus),
    puzzles: Map.unmodifiable(puzzleStatus),
    missing: unlocks.missing,
    currentPuzzleId: current,
  );
}

/// A concept id as words: `two_pointers` → `two pointers`.
String conceptWords(String concept) => concept.replaceAll('_', ' ');
