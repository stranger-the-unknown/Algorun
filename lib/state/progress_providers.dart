import 'dart:async';

import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progress/campaign.dart';
import '../progress/file_progress_store.dart';
import '../progress/progress_ledger.dart' as ledger;
import '../progress/progress_store.dart';
import '../progress/save_codec.dart';
import '../progress/save_data.dart';
import 'providers.dart';

/// Where the save lives. In memory unless `main` installs
/// [platformProgressStore], so tests never touch device storage.
final progressStoreProvider = Provider<ProgressStore>((ref) => MemoryProgressStore());

/// The device store: a JSON file in the app's support directory. Flutter web
/// is a preview only and keeps progress in memory.
ProgressStore platformProgressStore() =>
    kIsWeb ? MemoryProgressStore() : FileProgressStore.appSupport();

/// The worlds manifest and every puzzle a world lists.
final campaignProvider = FutureProvider<Campaign>((ref) async {
  final manifest = await ref.watch(worldsProvider.future);
  final repository = ref.watch(puzzleRepositoryProvider);
  final puzzles = <String, Puzzle>{};
  for (final world in manifest.worlds) {
    for (final id in world.puzzleIds) {
      puzzles[id] = await repository.loadPuzzle(world.id, id);
    }
  }
  return Campaign(manifest, puzzles);
});

final progressProvider = AsyncNotifierProvider<ProgressNotifier, PlayerSave>(ProgressNotifier.new);

/// The campaign, the save and what follows from them, together.
final class CampaignView {
  CampaignView(this.campaign, this.save) : progress = evaluateCampaign(campaign, save);

  final Campaign campaign;
  final PlayerSave save;
  final CampaignProgress progress;
}

final campaignViewProvider = Provider<AsyncValue<CampaignView>>((ref) {
  final campaign = ref.watch(campaignProvider);
  final save = ref.watch(progressProvider);
  if (campaign case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  final c = campaign.valueOrNull;
  final s = save.valueOrNull;
  if (c == null || s == null) return const AsyncLoading();
  return AsyncData(CampaignView(c, s));
});

/// The player's save in memory, and when it is written.
///
/// Autosave: an editor change updates the save at once and is written after
/// [debounce] of quiet; opening a puzzle, a RUN, a settings change, leaving a
/// puzzle and the app going to the background write immediately ([flush]).
/// Writes never overlap. Pointer movement, selection and the hint panel are
/// not saved; only the program (`BlockGraph`) is.
final class ProgressNotifier extends AsyncNotifier<PlayerSave> {
  static const debounce = Duration(milliseconds: 800);

  late ProgressStore _store;
  Timer? _timer;
  bool _dirty = false;
  Future<void> _writing = Future<void>.value();

  /// What the last load could not read and any failed write — developer
  /// output. The player is never blocked by it.
  final List<SaveIssue> issues = [];

  @override
  Future<PlayerSave> build() async {
    _store = ref.watch(progressStoreProvider);
    ref.onDispose(() => _timer?.cancel());
    StoreLoad loaded;
    try {
      loaded = await _store.load();
    } on Object catch (e) {
      loaded = StoreLoad(PlayerSave.fresh, [SaveIssue('', 'Loading failed ($e).')]);
    }
    loaded.issues.forEach(_report);
    return loaded.save;
  }

  PlayerSave get _current => state.valueOrNull ?? PlayerSave.fresh;

  /// Whether there are changes not written yet.
  bool get hasPendingWrite => _dirty;

  /// The saved progress of one puzzle, as of now.
  PuzzleProgress? progressOf(String puzzleId) => _current[puzzleId];

  /// The whole save, as of now.
  PlayerSave get current => _current;

  void _report(SaveIssue issue) {
    issues.add(issue);
    debugPrint('Algorun save: $issue');
  }

  void _set(PlayerSave next, {required bool now}) {
    if (identical(next, _current)) return;
    state = AsyncData(next);
    _dirty = true;
    if (now) {
      flush();
    } else {
      _timer?.cancel();
      _timer = Timer(debounce, flush);
    }
  }

  /// Writes pending changes now. Safe to call at any time.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return _writing;
    _dirty = false;
    final snapshot = _current;
    return _writing = _writing.then((_) => _store.save(snapshot)).catchError((Object e) {
      _report(SaveIssue('', 'Saving failed ($e).'));
    });
  }

  // Nothing is recorded before the save has loaded: a fresh save written over
  // a real one would lose it.

  ledger.OpenedPuzzle openPuzzle(Campaign campaign, Puzzle puzzle) {
    if (!state.hasValue) return const ledger.OpenedPuzzle();
    final (next, opened) = ledger.openPuzzle(_current, campaign, puzzle);
    _set(next, now: true);
    return opened;
  }

  /// [edited] false: only the layout changed (a fold), not the program.
  void saveDraft(Campaign campaign, Puzzle puzzle, BlockGraph graph, {bool edited = true}) {
    if (!state.hasValue) return;
    _set(ledger.saveDraft(_current, campaign, puzzle, graph, edited: edited), now: false);
  }

  ledger.RunRecordOutcome recordRun(Campaign campaign, Puzzle puzzle, BlockGraph graph, SuiteResult suite) {
    if (!state.hasValue) return const ledger.RunRecordOutcome();
    final (next, outcome) = ledger.recordRun(_current, campaign, puzzle, graph, suite);
    _set(next, now: true);
    return outcome;
  }

  void updateSettings(PlayerSettings settings) {
    if (!state.hasValue) return;
    _set(_current.copyWith(settings: settings), now: true);
  }

  /// Deletes every saved result, program and setting, except the language:
  /// that is how the player reads the game, not progress.
  Future<void> reset() async {
    // The language and the theme are the player's, not progress: they stay.
    final kept = PlayerSettings(language: _current.settings.language, theme: _current.settings.theme);
    _timer?.cancel();
    _dirty = false;
    await _writing;
    await _store.clear();
    state = const AsyncData(PlayerSave.fresh);
    if (kept.language != PlayerSettings.defaults.language || kept.theme != PlayerSettings.defaults.theme) {
      _set(PlayerSave(settings: kept), now: true);
      await flush();
    }
  }
}
