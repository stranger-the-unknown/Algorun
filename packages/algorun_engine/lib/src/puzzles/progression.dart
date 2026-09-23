import 'world.dart';

/// What is open, given the puzzles a player has completed.
final class UnlockState {
  const UnlockState({
    required this.mastered,
    required this.openWorlds,
    required this.completeWorlds,
    required this.openPuzzles,
    required this.missing,
  });

  /// Concepts taught by a complete world.
  final Set<String> mastered;
  final Set<String> openWorlds;
  final Set<String> completeWorlds;

  /// Listed puzzles that are open (completed ones included).
  final Set<String> openPuzzles;

  /// For a locked world or a locked puzzle: the concepts it still waits for.
  final Map<String, List<String>> missing;
}

/// The campaign unlock rules (MS11). The game and the content validator both
/// call this, so what the validator proves reachable is exactly what players
/// can reach. Data only — world `concepts` / `prerequisites` and each listed
/// puzzle's `prerequisites`; no id is special:
///
/// 1. A world is **open** when every concept in its `prerequisites` is
///    mastered — or when a puzzle it lists is already completed, so a content
///    update can never lock a world the player has played.
/// 2. A world is **complete** when it is open and every puzzle it lists is
///    completed. A world with no puzzles completes as soon as it opens.
/// 3. A concept is **mastered** when a complete world teaches it.
/// 4. A listed puzzle is **open** when its world is open and each of its own
///    prerequisites is mastered or taught by that same world. A completed
///    puzzle stays open.
///
/// Rules 1–3 feed each other and are applied until nothing changes; mastered
/// concepts only grow, so this settles.
UnlockState evaluateUnlocks(
  WorldsManifest manifest,
  Map<String, List<String>> puzzlePrerequisites,
  Set<String> completed,
) {
  final worlds = manifest.worlds;
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

  final missing = <String, List<String>>{};
  final openPuzzles = <String>{};
  for (final w in worlds) {
    if (!open.contains(w.id)) {
      missing[w.id] = [for (final c in w.prerequisites) if (!mastered.contains(c)) c];
    }
    for (final id in w.puzzleIds) {
      if (completed.contains(id)) {
        openPuzzles.add(id);
        continue;
      }
      final needs = open.contains(w.id)
          ? [
              for (final c in puzzlePrerequisites[id] ?? const <String>[])
                if (!mastered.contains(c) && !w.concepts.contains(c)) c,
            ]
          : missing[w.id]!;
      if (needs.isEmpty) {
        openPuzzles.add(id);
      } else {
        missing[id] = needs;
      }
    }
  }
  return UnlockState(
    mastered: Set.unmodifiable(mastered),
    openWorlds: Set.unmodifiable(open),
    completeWorlds: Set.unmodifiable(done),
    openPuzzles: Set.unmodifiable(openPuzzles),
    missing: Map.unmodifiable(missing),
  );
}
