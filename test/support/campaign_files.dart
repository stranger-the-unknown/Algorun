import 'dart:io';

import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/state/progress_providers.dart';
import 'package:algorun/state/providers.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A campaign from a manifest file, with its puzzles read from the repository.
/// Widget tests must not load assets through `rootBundle` inside fake async:
/// the bundle caches the pending load and the next test would wait on it
/// forever.
Campaign campaignFrom(String manifestPath) {
  final manifest = parseWorldsJson(File(manifestPath).readAsStringSync());
  return Campaign(manifest, {
    for (final world in manifest.worlds)
      for (final id in world.puzzleIds)
        id: parsePuzzleJson(File('assets/puzzles/${world.id}/$id.json').readAsStringSync()),
  });
}

/// The campaign as shipped today.
Campaign shippedCampaign() => campaignFrom('assets/worlds.json');

/// The five-puzzle campaign of MS11, frozen: the progression and persistence
/// tests check the rules against it, so they do not change every time content
/// is added. Its puzzles are the shipped ones.
Campaign ms11Campaign() => campaignFrom('test/fixtures/ms11_worlds.json');

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
