import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/services.dart';

/// Flutter-side loader. Parsing lives in algorun_engine (pure Dart).
final class AssetPuzzleRepository {
  const AssetPuzzleRepository();

  static const _worldsAsset = 'assets/worlds.json';

  /// Tries a failed load this many times in all.
  static const attempts = 3;

  Future<WorldsManifest> loadWorlds() async {
    final raw = await _load(_worldsAsset);
    return parseWorldsJson(raw);
  }

  Future<Puzzle> loadPuzzle(String worldId, String puzzleId) async {
    final raw = await _load('assets/puzzles/$worldId/$puzzleId.json');
    return parsePuzzleJson(raw);
  }

  /// In the browser every asset is a request, and a request can fail for a
  /// moment (GitHub Pages once answered 503). Try again after a pause; the
  /// bundle keeps a failed load, so it is evicted first.
  Future<String> _load(String key) => retrying(
        () => rootBundle.loadString(key),
        attempts: attempts,
        beforeRetry: () => rootBundle.evict(key),
      );
}

/// Runs [load] up to [attempts] times, waiting a little longer after each
/// failure; the last failure is thrown.
Future<T> retrying<T>(
  Future<T> Function() load, {
  int attempts = 3,
  Duration pause = const Duration(milliseconds: 400),
  void Function()? beforeRetry,
}) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await load();
    } on Object {
      if (attempt >= attempts) rethrow;
      beforeRetry?.call();
      await Future<void>.delayed(pause * attempt);
    }
  }
}
