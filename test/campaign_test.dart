import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// The MS12 campaign as the app sees it: every listed puzzle loads through
/// the game's own schema and can be reached under the app's own unlock rules.
void main() {
  final campaign = shippedCampaign();

  PlayerSave solved(Iterable<String> ids) => PlayerSave(puzzles: {
        for (final id in ids) id: const PuzzleProgress(puzzleVersion: 1, completed: true),
      });

  test('107 puzzles load, and a fresh install starts at Foundations', () {
    expect(campaign.puzzles, hasLength(107));
    final fresh = evaluateCampaign(campaign, PlayerSave.fresh);
    expect(fresh.worldStatus('world_01'), WorldStatus.open);
    // MS15: Foundations holds twelve puzzles, all open from the start.
    final basics = campaign.manifest.byId('world_01')!.puzzleIds;
    expect(basics, hasLength(12));
    expect(basics.take(2), ['warm_readings', 'highest_tide']);
    expect([for (final e in fresh.puzzles.entries) if (e.value != PuzzleStatus.locked) e.key], basics);
    expect(fresh.missingFor('world_02'), ['variables']);
  });

  test('a player who solves everything that opens reaches every puzzle', () {
    var done = <String>{};
    var rounds = 0;
    while (true) {
      final progress = evaluateCampaign(campaign, solved(done));
      final open = {for (final e in progress.puzzles.entries) if (e.value != PuzzleStatus.locked) e.key};
      if (open.difference(done).isEmpty) break;
      done = open;
      rounds++;
    }
    expect(done, campaign.puzzles.keys.toSet());
    expect(rounds, greaterThan(3), reason: 'the campaign unlocks in stages');
    final end = evaluateCampaign(campaign, solved(done));
    expect(end.worldStatus('world_12'), WorldStatus.locked, reason: 'backtracking waits for recursion');
    expect(end.worldStatus('world_14'), WorldStatus.completed);
  });

  test('Foundations opens Arrays; Arrays opens the next chapters', () {
    final basics = campaign.manifest.byId('world_01')!.puzzleIds;
    final almostBasics = evaluateCampaign(campaign, solved(basics.skip(1)));
    expect(almostBasics.worldStatus('world_02'), WorldStatus.locked, reason: 'one Foundations puzzle is still open');
    final afterBasics = evaluateCampaign(campaign, solved(basics));
    expect(afterBasics.worldStatus('world_02'), WorldStatus.open);
    expect(afterBasics.worldStatus('world_03'), WorldStatus.locked);
    // A world completes when every puzzle it lists is solved (MS15 made
    // Arrays thirteen puzzles long).
    final arrays = campaign.manifest.byId('world_02')!.puzzleIds;
    expect(arrays, hasLength(13));
    final almost = evaluateCampaign(campaign, solved([...basics, ...arrays.skip(1)]));
    expect(almost.worldStatus('world_03'), WorldStatus.locked, reason: 'one Arrays puzzle is still open');
    final afterArrays = evaluateCampaign(campaign, solved([...basics, ...arrays]));
    for (final world in ['world_03', 'world_04', 'world_06', 'world_11']) {
      expect(afterArrays.worldStatus(world), WorldStatus.open, reason: world);
    }
    expect(afterArrays.worldStatus('world_05'), WorldStatus.locked, reason: 'sliding windows wait for two pointers');
    // A puzzle-level prerequisite: Market Variety also needs hash maps.
    expect(afterArrays.missingFor('world_05'), ['two_pointers']);
  });
}
