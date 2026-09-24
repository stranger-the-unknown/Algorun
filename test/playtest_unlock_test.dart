import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/playtest_flags.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/progress_fixtures.dart';

void main() {
  tearDown(() => PlaytestFlags.unlockAllPuzzles = false);

  test('default flag is off so release/tests keep real locks', () {
    expect(PlaytestFlags.unlockAllPuzzles, isFalse);
    final campaign = tinyCampaign([
      ('world_01', ['basics'], [], ['p1']),
      ('world_02', ['next'], ['basics'], ['p2']),
    ]);
    final progress = evaluateCampaign(campaign, PlayerSave.fresh);
    expect(progress.puzzleStatus('p1'), PuzzleStatus.open);
    expect(progress.puzzleStatus('p2'), PuzzleStatus.locked);
    expect(progress.worldStatus('world_02'), WorldStatus.locked);
  });

  test('playtest unlock opens every puzzle and world without inventing completions', () {
    PlaytestFlags.unlockAllPuzzles = true;
    final campaign = tinyCampaign([
      ('world_01', ['basics'], [], ['p1']),
      ('world_02', ['next'], ['basics'], ['p2']),
      ('world_03', ['later'], ['next'], ['p3']),
    ]);
    final progress = evaluateCampaign(campaign, PlayerSave.fresh);
    expect(progress.puzzles.values.every((s) => s != PuzzleStatus.locked), isTrue);
    expect(progress.worlds.values.every((s) => s != WorldStatus.locked), isTrue);
    expect(progress.solvedCount, 0);
    expect(progress.puzzleStatus('p1'), PuzzleStatus.open);
    expect(progress.puzzleStatus('p3'), PuzzleStatus.open);
  });

  test('playtest unlock still records completion and keeps completed status', () {
    PlaytestFlags.unlockAllPuzzles = true;
    final campaign = tinyCampaign([
      ('world_01', ['basics'], [], ['p1']),
      ('world_02', ['next'], ['basics'], ['p2']),
    ]);
    var save = PlayerSave.fresh;
    final p2 = campaign.puzzles['p2']!;
    final (openedSave, opened) = openPuzzle(save, campaign, p2);
    expect(opened.progress, isNull);
    expect(openedSave.session?.puzzleId, 'p2', reason: 'locked p2 is open under playtest');
    save = openedSave.withPuzzle(
      'p2',
      const PuzzleProgress(puzzleVersion: 1, completed: true),
    );
    final after = evaluateCampaign(campaign, save);
    expect(after.puzzleStatus('p2'), PuzzleStatus.completed);
    expect(after.solvedCount, 1);
  });

  test('with the flag off, openPuzzle still rejects a locked puzzle', () {
    final campaign = tinyCampaign([
      ('world_01', ['basics'], [], ['p1']),
      ('world_02', ['next'], ['basics'], ['p2']),
    ]);
    final (_, opened) = openPuzzle(PlayerSave.fresh, campaign, campaign.puzzles['p2']!);
    expect(opened.progress, isNull);
    expect(opened.graph, isNull);
  });
}
