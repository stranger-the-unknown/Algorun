import 'package:algorun/app.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/progress_fixtures.dart';

final _campaign = shippedCampaign();
final _cart = _campaign.puzzles['smallest_cart']!;
final _solution = referenceSolution('world_02', 'smallest_cart');

/// A store holding [save], as a device that already played would.
MemoryProgressStore _device(PlayerSave save) => MemoryProgressStore(encodeSave(save));

/// The save after solving The Smallest Cart with its reference program.
PlayerSave _cartSolved({BlockGraph? draft, bool session = false}) {
  var save = openPuzzle(PlayerSave.fresh, _campaign, _cart).$1;
  save = recordRun(save, _campaign, _cart, _solution, runPuzzle(const DefaultEngine(), _solution, _cart).suite).$1;
  if (draft != null) save = saveDraft(save, _campaign, _cart, draft);
  return session ? save : save.copyWith(session: null);
}

Future<void> _launch(WidgetTester tester, ProgressStore store) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

PlayerSave _stored(MemoryProgressStore store) => decodeSave(store.text!).save;

void main() {
  testWidgets('fresh install: ENTER, Arrays open, the rest locked, the first puzzle plays', (tester) async {
    final store = MemoryProgressStore();
    await _launch(tester, store);
    expect(find.text('ENTER'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
    expect(find.text('0 of 5 puzzles solved'), findsOneWidget);

    await _tap(tester, find.text('ENTER'));
    expect(find.text('Worlds'), findsOneWidget);
    expect(find.text('0 of 1 solved'), findsOneWidget);
    expect(find.text('Locked — learn arrays first'), findsNWidgets(4));
    expect(find.text('Locked — learn two pointers first'), findsOneWidget);
    expect(find.textContaining('probe'), findsNothing);

    await _tap(tester, find.byKey(const Key('world-world_03')));
    expect(find.text('Worlds'), findsOneWidget, reason: 'a locked world does not open');

    await _tap(tester, find.byKey(const Key('world-world_02')));
    expect(find.text('The Smallest Cart'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('puzzle-smallest_cart')));
    expect(find.text('RUN'), findsOneWidget);
    expect(find.text('The Smallest Cart'), findsOneWidget);
    expect(_stored(store).session!.puzzleId, 'smallest_cart', reason: 'opening is saved at once');
  });

  testWidgets('a solved puzzle shows as solved and opens the next worlds', (tester) async {
    await _launch(tester, _device(_cartSolved()));
    expect(find.text('1 of 5 puzzles solved'), findsOneWidget);
    await _tap(tester, find.text('ENTER'));
    expect(find.text('Solved'), findsOneWidget); // Arrays
    expect(find.text('0 of 1 solved'), findsNWidgets(3)); // Hash Maps, Sliding Window, Stack & Queue
    expect(find.text('No puzzles yet'), findsWidgets);
    expect(find.text('Locked — learn stack first'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await _tap(tester, find.byKey(const Key('world-world_02')));
    expect(find.text('Solved · best 65,204 steps · 55 blocks'), findsOneWidget);
  });

  testWidgets('a locked puzzle does not open even by its route', (tester) async {
    await _launch(tester, MemoryProgressStore());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/puzzle', arguments: {'worldId': 'world_03', 'puzzleId': 'twin_beacons'});
    await tester.pumpAndSettle();
    expect(find.text('This puzzle is locked. It opens once you have learned arrays.'), findsOneWidget);
    expect(find.text('RUN'), findsNothing);
  });

  testWidgets('CONTINUE reopens the last puzzle with its saved program', (tester) async {
    final draft = lengthGraph(retId: 'mine');
    final store = _device(saveDraft(openPuzzle(PlayerSave.fresh, _campaign, _cart).$1, _campaign, _cart, draft));
    await _launch(tester, store);
    expect(find.text('Last played: The Smallest Cart · Arrays'), findsOneWidget);
    expect(find.text('ENTER'), findsNothing);

    await _tap(tester, find.byKey(const Key('home-continue')));
    expect(find.text('RUN'), findsOneWidget);
    expect(find.text('LENGTH'), findsOneWidget, reason: 'the restored program');
    expect(find.text('RETURN'), findsOneWidget);
  });

  testWidgets('the best solution can be loaded back, and leaving saves the program', (tester) async {
    final store = _device(_cartSolved(draft: lengthGraph(retId: 'experiment'), session: true));
    await _launch(tester, store);
    await _tap(tester, find.byKey(const Key('home-continue')));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('LENGTH'), findsOneWidget);

    await _tap(tester, find.byTooltip('Load best solution'));
    expect(find.text('LENGTH'), findsNothing);
    expect(find.textContaining('Your best solution is loaded'), findsOneWidget);

    await _tap(tester, find.byType(BackButton));
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(graphText(_stored(store)['smallest_cart']!.draft!), graphText(_solution));
  });

  testWidgets('RUN solves the puzzle: the results say so and progress is saved', (tester) async {
    final store = _device(saveDraft(openPuzzle(PlayerSave.fresh, _campaign, _cart).$1, _campaign, _cart, _solution));
    await _launch(tester, store);
    await _tap(tester, find.byKey(const Key('home-continue')));
    await _tap(tester, find.text('RUN'));

    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.text('Puzzle solved.'), findsOneWidget);
    expect(find.text('Now open: Hash Maps, Sliding Window, Stack & Queue.'), findsOneWidget);
    final saved = _stored(store)['smallest_cart']!;
    expect(saved.completed, isTrue);
    expect(saved.best!.ops, 65204);

    await _tap(tester, find.text('BACK TO PUZZLE'));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a failed RUN says nothing about progress and saves only the last run', (tester) async {
    final slow = referenceReject('world_02', 'smallest_cart', 'raise the capacity one unit at a time');
    final store = _device(saveDraft(openPuzzle(PlayerSave.fresh, _campaign, _cart).$1, _campaign, _cart, slow));
    await _launch(tester, store);
    await _tap(tester, find.byKey(const Key('home-continue')));
    await _tap(tester, find.text('RUN'));

    expect(find.text('OPERATION LIMIT'), findsOneWidget);
    expect(find.text('PROGRESS'), findsNothing);
    final saved = _stored(store)['smallest_cart']!;
    expect(saved.completed, isFalse);
    expect(saved.lastRun!.result, ResultKind.operationLimit);
  });

  testWidgets('settings: the brief preference sticks, reset asks first and clears everything', (tester) async {
    final store = _device(_cartSolved(session: true));
    await _launch(tester, store);
    await _tap(tester, find.text('Settings'));
    await _tap(tester, find.byKey(const Key('settings-brief')));
    expect(_stored(store).settings.showBriefOnOpen, isFalse);

    await _tap(tester, find.byKey(const Key('settings-reset')));
    expect(find.text('Reset progress?'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(_stored(store)['smallest_cart']!.completed, isTrue);

    await _tap(tester, find.byKey(const Key('settings-reset')));
    await _tap(tester, find.byKey(const Key('settings-reset-confirm')));
    expect(store.text, isNull);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('ENTER'), findsOneWidget);
    expect(find.text('0 of 5 puzzles solved'), findsOneWidget);
  });

  testWidgets('a puzzle opens with the brief closed when the player chose so', (tester) async {
    final save = PlayerSave.fresh.copyWith(settings: const PlayerSettings(showBriefOnOpen: false));
    await _launch(tester, _device(save));
    await _tap(tester, find.text('ENTER'));
    await _tap(tester, find.byKey(const Key('world-world_02')));
    await _tap(tester, find.byKey(const Key('puzzle-smallest_cart')));
    expect(find.text(_cart.story), findsNothing);
    await _tap(tester, find.text('BRIEF'));
    expect(find.text(_cart.story), findsOneWidget);
  });

  test('progress lines name what changed, in player words', () {
    expect(progressLines(null), isEmpty);
    expect(progressLines(const RunRecordOutcome()), isEmpty);
    final world = _campaign.manifest.byId('world_03')!;
    expect(
      progressLines(RunRecordOutcome(
        firstCompletion: true,
        opened: [world],
      )),
      ['Puzzle solved.', 'Now open: Hash Maps.'],
    );
    expect(
      progressLines(const RunRecordOutcome(improved: {BestMetric.blocks, BestMetric.ops})),
      ['New best: fewest steps, fewest blocks.'],
    );
  });
}
