import 'package:algorun/app.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/puzzles/asset_repository.dart';
import 'package:algorun/state/progress_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// In the browser every puzzle is a request (2026-10-02: GitHub Pages once
/// answered 503). A failed load is tried again; if it still fails, the
/// player is told and can try again.
void main() {
  group('retrying', () {
    test('a load that fails twice and then works gives its value', () async {
      var calls = 0;
      var evicted = 0;
      final value = await retrying(
        () async => ++calls < 3 ? throw StateError('503') : 'ok',
        pause: Duration.zero,
        beforeRetry: () => evicted++,
      );
      expect(value, 'ok');
      expect((calls, evicted), (3, 2));
    });

    test('a load that keeps failing throws after the last attempt', () async {
      var calls = 0;
      await expectLater(
        retrying(() async => throw StateError('503 ${++calls}'), attempts: 3, pause: Duration.zero),
        throwsA(isA<StateError>().having((e) => e.message, 'message', '503 3')),
      );
    });
  });

  testWidgets('when the puzzles cannot be loaded, home and the world list say so and TRY AGAIN loads them',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final campaign = ms11Campaign();
    var online = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...campaignOverrides(MemoryProgressStore(), campaign: campaign),
        campaignProvider.overrideWith((ref) async => online ? campaign : throw StateError('offline')),
      ],
      child: const AlgorunApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('The puzzles could not be loaded. Check the connection and try again.'), findsOneWidget);
    expect(find.text('PROGRESS'), findsNothing);

    await tester.tap(find.text('ENTER'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('load-retry')), findsOneWidget, reason: 'the world list says so too');
    expect(find.textContaining('offline'), findsNothing, reason: 'no raw error text');

    online = true;
    await tester.tap(find.byKey(const Key('load-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('load-failed')), findsNothing);
    expect(find.byKey(const Key('world-world_02')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PROGRESS'), findsOneWidget);
  });
}
