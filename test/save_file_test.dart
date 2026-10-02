import 'package:algorun/app.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/progress/save_files.dart';
import 'package:algorun/state/progress_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// The browser version's save file (2026-10-02): download the save, load it
/// back, and never lose progress to a file that is not a save.
final class _FakeFiles implements SaveFiles {
  _FakeFiles({this.supported = true});

  @override
  final bool supported;

  String? picked;
  final downloads = <(String, String)>[];

  @override
  void download(String fileName, String text) => downloads.add((fileName, text));

  @override
  Future<String?> pick() async => picked;
}

PlayerSave _solved(List<String> ids) => PlayerSave(puzzles: {
      for (final id in ids) id: const PuzzleProgress(puzzleVersion: 1, completed: true),
    });

Set<String> _completed(PlayerSave save) => {
      for (final e in save.puzzles.entries)
        if (e.value.completed) e.key,
    };

Future<ProviderContainer> _loaded(ProgressStore store) async {
  final container = ProviderContainer(overrides: [progressStoreProvider.overrideWithValue(store)]);
  addTearDown(container.dispose);
  await container.read(progressProvider.future);
  return container;
}

void main() {
  group('the progress notifier', () {
    test('a downloaded save loads back whole, and is written at once', () async {
      final here = await _loaded(MemoryProgressStore(encodeSave(_solved(['smallest_cart', 'twin_beacons']))));
      final text = here.read(progressProvider.notifier).exportText();

      final elsewhere = MemoryProgressStore();
      final there = await _loaded(elsewhere);
      final loaded = await there.read(progressProvider.notifier).importText(text);
      expect(_completed(loaded!), {'smallest_cart', 'twin_beacons'});
      expect(_completed(decodeSave(elsewhere.text!).save), {'smallest_cart', 'twin_beacons'});
    });

    test('a file that is not a save changes nothing', () async {
      final store = MemoryProgressStore(encodeSave(_solved(['smallest_cart'])));
      final before = store.text;
      final container = await _loaded(store);
      for (final text in ['not json', '{"hello": 1}', '[]', '{"saveVersion": 99}']) {
        expect(await container.read(progressProvider.notifier).importText(text), isNull, reason: text);
      }
      expect(store.text, before);
      expect(_completed(container.read(progressProvider).value!), {'smallest_cart'});
    });
  });

  group('the settings screen', () {
    Future<void> launch(WidgetTester tester, ProgressStore store, SaveFiles files) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [...campaignOverrides(store, campaign: ms11Campaign()), saveFilesProvider.overrideWithValue(files)],
        child: const AlgorunApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('download the save, then load another one after a confirmation', (tester) async {
      final store = MemoryProgressStore(encodeSave(_solved(['smallest_cart'])));
      final files = _FakeFiles();
      await launch(tester, store, files);
      expect(find.text('SAVE FILE'), findsOneWidget);

      await tap(tester, find.byKey(const Key('settings-save-download')));
      final (name, text) = files.downloads.single;
      expect(name, matches(RegExp(r'^algorun-save-\d{4}-\d{2}-\d{2}\.json$')));
      expect(_completed(decodeSave(text).save), {'smallest_cart'});
      expect(find.text('Save file downloaded.'), findsOneWidget);

      files.picked = encodeSave(_solved(['smallest_cart', 'twin_beacons']));
      await tap(tester, find.byKey(const Key('settings-save-load')));
      expect(find.text('Load a save file?'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(_completed(decodeSave(store.text!).save), {'smallest_cart'}, reason: 'cancel changes nothing');

      await tap(tester, find.byKey(const Key('settings-save-load')));
      await tap(tester, find.byKey(const Key('settings-save-load-confirm')));
      expect(find.text('Save loaded: 2 solved puzzles.'), findsOneWidget);
      expect(_completed(decodeSave(store.text!).save), {'smallest_cart', 'twin_beacons'});
    });

    testWidgets('a file that is not a save is refused and nothing changes', (tester) async {
      final store = MemoryProgressStore(encodeSave(_solved(['smallest_cart'])));
      final before = store.text;
      final files = _FakeFiles()..picked = '{"photos": []}';
      await launch(tester, store, files);
      await tap(tester, find.byKey(const Key('settings-save-load')));
      await tap(tester, find.byKey(const Key('settings-save-load-confirm')));
      expect(find.text('That file is not an Algorun save. Nothing was changed.'), findsOneWidget);
      expect(store.text, before);
    });

    testWidgets('on the phone there is no save file section', (tester) async {
      await launch(tester, MemoryProgressStore(), _FakeFiles(supported: false));
      expect(find.text('SAVE FILE'), findsNothing);
      expect(find.byKey(const Key('settings-save-download')), findsNothing);
    });
  });
}
