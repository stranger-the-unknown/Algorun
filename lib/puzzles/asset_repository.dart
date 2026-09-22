import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/services.dart';

/// Flutter-side loader. Parsing lives in algorun_engine (pure Dart).
final class AssetPuzzleRepository {
  const AssetPuzzleRepository();

  static const _worldsAsset = 'assets/worlds.json';

  Future<WorldsManifest> loadWorlds() async {
    final raw = await rootBundle.loadString(_worldsAsset);
    return parseWorldsJson(raw);
  }

  Future<Puzzle> loadPuzzle(String worldId, String puzzleId) async {
    final raw = await rootBundle.loadString(
      'assets/puzzles/$worldId/$puzzleId.json',
    );
    return parsePuzzleJson(raw);
  }
}
