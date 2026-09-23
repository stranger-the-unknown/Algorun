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

/// The unlock rules — data-driven, no puzzle or world id is special:
///
/// 1. A world is **open** when every concept in its `prerequisites` is
///    mastered — or when the player has already solved one of its puzzles, so
///    a content update can never lock a world the player has played.
/// 2. A world is **complete** when it is open and every puzzle it lists is
///    solved. A world with no puzzles yet is complete as soon as it opens, so
///    a missing chapter never blocks the ones after it.
/// 3. A concept is **mastered** when a complete world teaches it (lists it in
///    `concepts`).
/// 4. A puzzle is **open** when its world is open and each of its own
///    `prerequisites` is mastered or taught by that same world (a world's
///    first puzzle may practise the world's own concept).
///
/// Rules 1–3 feed each other, so they are applied until nothing changes. It
/// settles quickly: mastered concepts only grow.
CampaignProgress evaluateCampaign(Campaign campaign, PlayerSave save) {
  final worlds = campaign.manifest.worlds;
  final completed = {
    for (final id in campaign.puzzles.keys)
      if (save[id]?.completed ?? false) id,
  };

  var mastered = <String>{};
  var open = <String>{};
  var done = <String>{};
  while (true) {
    open = {
      for (final w in worlds)
        if (w.prerequisites.every(mastered.contains) || w.puzzleIds.any(completed.contains)) w.id,
    };
    done = {
      for (final w in worlds)
        if (open.contains(w.id) && w.puzzleIds.every(completed.contains)) w.id,
    };
    final next = {
      for (final w in worlds)
        if (done.contains(w.id)) ...w.concepts,
    };
    if (next.length == mastered.length) break;
    mastered = next;
  }

  final worldStatus = <String, WorldStatus>{};
  final puzzleStatus = <String, PuzzleStatus>{};
  final missing = <String, List<String>>{};
  for (final w in worlds) {
    if (!open.contains(w.id)) {
      worldStatus[w.id] = WorldStatus.locked;
      missing[w.id] = [for (final c in w.prerequisites) if (!mastered.contains(c)) c];
    } else if (w.puzzleIds.isEmpty) {
      worldStatus[w.id] = WorldStatus.empty;
    } else {
      worldStatus[w.id] = done.contains(w.id) ? WorldStatus.completed : WorldStatus.open;
    }
    for (final id in w.puzzleIds) {
      final puzzle = campaign.puzzles[id]!;
      final needs = open.contains(w.id)
          ? [
              for (final c in puzzle.prerequisites)
                if (!mastered.contains(c) && !w.concepts.contains(c)) c,
            ]
          : missing[w.id]!;
      final progress = save[id];
      if (completed.contains(id)) {
        puzzleStatus[id] = PuzzleStatus.completed;
      } else if (needs.isNotEmpty) {
        puzzleStatus[id] = PuzzleStatus.locked;
        missing[id] = needs;
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
    mastered: Set.unmodifiable(mastered),
    worlds: Map.unmodifiable(worldStatus),
    puzzles: Map.unmodifiable(puzzleStatus),
    missing: Map.unmodifiable(missing),
    currentPuzzleId: current,
  );
}

/// A concept id as words: `two_pointers` → `two pointers`.
String conceptWords(String concept) => concept.replaceAll('_', ' ');
