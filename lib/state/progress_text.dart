import 'package:algorun_engine/algorun_engine.dart';

import '../l10n/content_text.dart';
import '../l10n/l10n.dart';
import '../l10n/terms.dart';
import '../progress/campaign.dart';
import '../progress/save_data.dart';
import 'performance_text.dart';

/// Player words for progression. Concepts appear as words, never as ids.

/// Why something is locked: `Locked — learn two pointers first`.
String lockedText(List<String> missing, AppLocalizations l, [ContentText t = ContentText.english]) =>
    missing.isEmpty ? l.locked : l.lockedLearnFirst(t.concepts(missing));

/// One line for a world card.
String worldStatusText(
  WorldDef world,
  WorldStatus status,
  CampaignProgress progress,
  AppLocalizations l, [
  ContentText t = ContentText.english,
]) {
  final solved = world.puzzleIds.where((id) => progress.puzzleStatus(id) == PuzzleStatus.completed).length;
  final total = world.puzzleIds.length;
  return switch (status) {
    WorldStatus.locked => lockedText(progress.missingFor(world.id), l, t),
    WorldStatus.empty => l.worldNoPuzzles,
    WorldStatus.completed => total == 1 ? l.worldSolvedOne : l.worldAllSolved(total),
    WorldStatus.open => l.worldProgress(solved, total),
  };
}

/// One line for a puzzle row.
String puzzleStatusText(
  PuzzleStatus status,
  PuzzleProgress? saved,
  List<String> missing,
  AppLocalizations l, [
  ContentText t = ContentText.english,
]) {
  return switch (status) {
    PuzzleStatus.locked => lockedText(missing, l, t),
    PuzzleStatus.open => l.statusNotStarted,
    PuzzleStatus.inProgress => switch (saved?.lastRun) {
        final run? when saved!.editedSinceRun => l.statusInProgressLastRunEdited(kindText(run.result, l)),
        final run? => l.statusInProgressLastRun(kindText(run.result, l)),
        null => l.statusInProgress,
      },
    PuzzleStatus.completed => switch (saved?.best) {
        final best? => l.statusSolvedBest(formatCount(best.ops, l.localeName), best.blocks),
        null => l.statusSolved,
      },
  };
}
