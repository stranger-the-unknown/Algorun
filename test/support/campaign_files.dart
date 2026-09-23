import 'dart:io';

import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/state/progress_providers.dart';
import 'package:algorun/state/providers.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shipped campaign, read from the repository files. Widget tests must not
/// load assets through `rootBundle` inside fake async: the bundle caches the
/// pending load and the next test would wait on it forever.
Campaign shippedCampaign() {
  final manifest = parseWorldsJson(File('assets/worlds.json').readAsStringSync());
  return Campaign(manifest, {
    for (final world in manifest.worlds)
      for (final id in world.puzzleIds)
        id: parsePuzzleJson(File('assets/puzzles/${world.id}/$id.json').readAsStringSync()),
  });
}

Puzzle shippedPuzzle(String worldId, String id) =>
    parsePuzzleJson(File('assets/puzzles/$worldId/$id.json').readAsStringSync());

/// Overrides that give a widget test the shipped campaign (no asset IO) and
/// [store] as the device.
List<Override> campaignOverrides(ProgressStore store, {Campaign? campaign}) {
  final c = campaign ?? shippedCampaign();
  return [
    worldsProvider.overrideWith((ref) async => c.manifest),
    campaignProvider.overrideWith((ref) async => c),
    progressStoreProvider.overrideWithValue(store),
  ];
}
