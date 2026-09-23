import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/state/progress_providers.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campaign_files.dart';
import '../support/progress_fixtures.dart';

final _campaign = ms11Campaign();

/// One app launch over [store]: a fresh container, the save loaded.
Future<(ProviderContainer, ProgressNotifier)> _launch(ProgressStore store) async {
  final container = ProviderContainer(overrides: campaignOverrides(store, campaign: _campaign));
  addTearDown(container.dispose);
  await container.read(progressProvider.future);
  return (container, container.read(progressProvider.notifier));
}

Future<CampaignView> _view(ProviderContainer container) async {
  await container.read(campaignProvider.future);
  return container.read(campaignViewProvider).requireValue;
}

final class _BrokenStore implements ProgressStore {
  @override
  Future<StoreLoad> load() async => const StoreLoad(PlayerSave.fresh);

  @override
  Future<void> save(PlayerSave save) async => throw StateError('disk full');

  @override
  Future<void> clear() async {}
}

void main() {
  final cart = _campaign.puzzles['smallest_cart']!;

  test('28. the last puzzle is remembered across a restart', () async {
    final store = MemoryProgressStore();
    final (_, first) = await _launch(store);
    first.openPuzzle(_campaign, cart);
    await first.flush();

    final (second, _) = await _launch(store);
    final view = await _view(second);
    expect(view.progress.currentPuzzleId, 'smallest_cart');
    expect(view.save.session!.worldId, 'world_02');
  });

  test('29. the program being edited comes back after a restart', () async {
    final store = MemoryProgressStore();
    final (_, first) = await _launch(store);
    final opened = first.openPuzzle(_campaign, cart);
    expect(opened.graph, isNull, reason: 'nothing saved yet');
    first.saveDraft(_campaign, cart, lengthGraph(retId: 'mine'));
    await first.flush();

    final (_, second) = await _launch(store);
    final back = second.openPuzzle(_campaign, cart);
    expect(graphText(back.graph!), graphText(lengthGraph(retId: 'mine')));
    expect(second.progressOf('smallest_cart')!.editedSinceRun, isTrue);
  });

  test('30. a solved puzzle reopens with its solution', () async {
    final store = MemoryProgressStore();
    final (_, first) = await _launch(store);
    first.openPuzzle(_campaign, cart);
    final solution = referenceSolution('world_02', 'smallest_cart');
    final outcome = first.recordRun(_campaign, cart, solution, runPuzzle(const DefaultEngine(), solution, cart).suite);
    expect(outcome.firstCompletion, isTrue);
    await first.flush();

    final (container, second) = await _launch(store);
    final back = second.openPuzzle(_campaign, cart);
    expect(graphText(back.graph!), graphText(solution));
    expect(graphText(second.progressOf('smallest_cart')!.solution!), graphText(solution));
    expect((await _view(container)).progress.puzzleStatus('smallest_cart'), PuzzleStatus.completed);
    // Without a draft, the best solution is what opens.
    final noDraft = decodeSave(store.text!).save;
    final solvedOnly = noDraft.withPuzzle('smallest_cart', noDraft['smallest_cart']!.copyWith(draft: null));
    final (_, third) = await _launch(MemoryProgressStore(encodeSave(solvedOnly)));
    expect(graphText(third.openPuzzle(_campaign, cart).graph!), graphText(solution));
  });

  test('31. an edited, unsolved puzzle survives a restart', () async {
    final store = MemoryProgressStore();
    final (_, first) = await _launch(store);
    first.openPuzzle(_campaign, cart);
    final wrong = BlockGraph.fromJson({
      'variables': {'weights': 'array<num>', 'trips': 'num'},
      'entryIds': ['ret'],
      'blocks': {
        'ret': {'id': 'ret', 'catalogId': 'ctrl.return', 'slots': {'value': {'ref': 'zero'}}},
        'zero': {'id': 'zero', 'catalogId': 'lit.num', 'literals': {'value': 0}},
      },
    });
    first.recordRun(_campaign, cart, wrong, runPuzzle(const DefaultEngine(), wrong, cart).suite);
    first.saveDraft(_campaign, cart, lengthGraph(retId: 'after_the_run'));
    expect(first.hasPendingWrite, isTrue, reason: 'edits wait for a quiet moment');
    await first.flush(); // what leaving the puzzle or backgrounding the app does

    final (container, second) = await _launch(store);
    final saved = second.progressOf('smallest_cart')!;
    expect(saved.completed, isFalse);
    expect(saved.lastRun!.result, isNot(ResultKind.correct));
    expect(saved.editedSinceRun, isTrue);
    expect(graphText(saved.draft!), graphText(lengthGraph(retId: 'after_the_run')));
    expect((await _view(container)).progress.puzzleStatus('smallest_cart'), PuzzleStatus.inProgress);
  });

  test('edits are written after a quiet moment, not on every change', () async {
    final store = MemoryProgressStore();
    final (_, notifier) = await _launch(store);
    notifier.openPuzzle(_campaign, cart);
    await Future<void>.delayed(Duration.zero);
    final writesAfterOpen = store.writes;
    for (var i = 0; i < 5; i++) {
      notifier.saveDraft(_campaign, cart, lengthGraph(retId: 'edit$i'));
    }
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, writesAfterOpen);
    await Future<void>.delayed(ProgressNotifier.debounce + const Duration(milliseconds: 200));
    expect(store.writes, writesAfterOpen + 1);
    expect(decodeSave(store.text!).save['smallest_cart']!.draft!.entryIds, ['edit4']);
  });

  test('a RUN is written at once', () async {
    final store = MemoryProgressStore();
    final (_, notifier) = await _launch(store);
    notifier.openPuzzle(_campaign, cart);
    notifier.recordRun(_campaign, cart, lengthGraph(), suite(ResultKind.wrongAnswer));
    await Future<void>.delayed(Duration.zero);
    expect(decodeSave(store.text!).save['smallest_cart']!.lastRun!.result, ResultKind.wrongAnswer);
    expect(notifier.hasPendingWrite, isFalse);
  });

  test('a failing store is reported, never thrown at the player', () async {
    final (container, notifier) = await _launch(_BrokenStore());
    notifier.openPuzzle(_campaign, cart);
    await notifier.flush();
    expect(notifier.issues.single.message, contains('Saving failed'));
    expect(container.read(progressProvider).requireValue.session!.puzzleId, 'smallest_cart');
  });

  test('an unreadable save starts fresh, is kept aside and reported', () async {
    final store = MemoryProgressStore('{"saveVersion": "one"}');
    final (_, notifier) = await _launch(store);
    expect(notifier.issues.single.path, 'saveVersion');
    expect(store.keptAside, ['{"saveVersion": "one"}']);
    expect(notifier.progressOf('smallest_cart'), isNull);
  });

  test('settings and reset', () async {
    final store = MemoryProgressStore();
    final (_, first) = await _launch(store);
    first.updateSettings(const PlayerSettings(showBriefOnOpen: false));
    first.openPuzzle(_campaign, cart);
    await first.flush();
    final (container, second) = await _launch(store);
    expect(container.read(progressProvider).requireValue.settings.showBriefOnOpen, isFalse);
    await second.reset();
    expect(store.text, isNull);
    expect(container.read(progressProvider).requireValue.session, isNull);
  });
}
