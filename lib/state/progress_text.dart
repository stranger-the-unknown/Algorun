import 'package:algorun_engine/algorun_engine.dart';

import '../progress/campaign.dart';
import '../progress/save_data.dart';
import 'performance_text.dart';

/// Player words for progression. Concepts appear as words, never as ids.

/// Why something is locked: `Locked — learn two pointers first`.
String lockedText(List<String> missing) =>
    missing.isEmpty ? 'Locked' : 'Locked — learn ${missing.map(conceptWords).join(', ')} first';

/// One line for a world card.
String worldStatusText(WorldDef world, WorldStatus status, CampaignProgress progress) {
  final solved = world.puzzleIds.where((id) => progress.puzzleStatus(id) == PuzzleStatus.completed).length;
  final total = world.puzzleIds.length;
  return switch (status) {
    WorldStatus.locked => lockedText(progress.missingFor(world.id)),
    WorldStatus.empty => 'No puzzles yet',
    WorldStatus.completed => total == 1 ? 'Solved' : 'All $total solved',
    WorldStatus.open => '$solved of $total solved',
  };
}

/// One line for a puzzle row.
String puzzleStatusText(PuzzleStatus status, PuzzleProgress? saved, List<String> missing) {
  return switch (status) {
    PuzzleStatus.locked => lockedText(missing),
    PuzzleStatus.open => 'Not started',
    PuzzleStatus.inProgress => switch (saved?.lastRun) {
        final run? when saved!.editedSinceRun => 'In progress · last run: ${run.result.label.toLowerCase()}, edited since',
        final run? => 'In progress · last run: ${run.result.label.toLowerCase()}',
        null => 'In progress',
      },
    PuzzleStatus.completed => switch (saved?.best) {
        final best? => 'Solved · best ${formatCount(best.ops)} steps · ${best.blocks} blocks',
        null => 'Solved',
      },
  };
}
