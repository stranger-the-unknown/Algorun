import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../puzzles/asset_repository.dart';

final engineProvider = Provider<AlgorunEngine>((ref) {
  return const DefaultEngine();
});

final puzzleRepositoryProvider = Provider<AssetPuzzleRepository>((ref) {
  return const AssetPuzzleRepository();
});

final worldsProvider = FutureProvider<WorldsManifest>((ref) {
  return ref.watch(puzzleRepositoryProvider).loadWorlds();
});
