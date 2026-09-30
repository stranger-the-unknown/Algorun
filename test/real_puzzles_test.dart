import 'dart:convert';
import 'dart:io';

import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/puzzles/asset_repository.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/screens/world_select/world_select_screen.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/results_finders.dart';

/// The five MS8 puzzles as the app sees them: loaded from the bundle, played
/// through the same RUN path as the button.
const _real = {
  'world_02': 'smallest_cart',
  'world_03': 'twin_beacons',
  'world_05': 'quota_hours',
  'world_06': 'relay_towers',
  'world_10': 'fewest_rides',
};

/// Reference files are offline content tooling. Tests read them from disk to
/// prove the shipped puzzles are solvable; the app never bundles them.
Map<String, Object?> _reference(String world, String id) =>
    jsonDecode(File('content/references/$world/$id.json').readAsStringSync())
        as Map<String, Object?>;

BlockGraph _graph(Object? json) =>
    BlockGraph.fromJson(Map<String, dynamic>.from(json as Map));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repo = AssetPuzzleRepository();

  test('the five MS8 puzzles stay in their worlds, and no probe is listed', () async {
    // Since MS15 the worlds list 107 puzzles (campaign_test.dart); the five
    // from MS8 keep their places.
    final worlds = await repo.loadWorlds();
    for (final MapEntry(key: world, value: id) in _real.entries) {
      expect(worlds.byId(world)!.puzzleIds, contains(id));
    }
    final listed = {for (final w in worlds.worlds) ...w.puzzleIds};
    for (final probe in ['ms1_contract_probe', 'ms3_editor_probe', 'l1_list_probe', 'l1_tree_probe']) {
      expect(listed, isNot(contains(probe)), reason: 'probes are not player content');
    }
    for (final w in worlds.worlds) {
      for (final id in w.puzzleIds) {
        final puzzle = await repo.loadPuzzle(w.id, id);
        expect(puzzle.reference, isNotNull, reason: id);
        expect(puzzle.hints.length, greaterThanOrEqualTo(2), reason: id);
      }
    }
  });

  test('each real puzzle loads from the app bundle as a real puzzle', () async {
    for (final MapEntry(key: world, value: id) in _real.entries) {
      final puzzle = await repo.loadPuzzle(world, id);
      expect(puzzle.world, world);
      expect(puzzle.story, isNot(contains('probe')));
      expect(puzzle.blocks.allow, isNotEmpty);
      expect(puzzle.hints.length, greaterThanOrEqualTo(3));
      expect(puzzle.hiddenTests, isNotEmpty);
      expect(puzzle.reference, isNotNull);
    }
  });

  test('the reference solutions are not in the app bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('content/')));
    expect(pubspec, isNot(contains('references')));
  });

  test('RUN solves every real puzzle with its reference, hidden cases included', () async {
    for (final MapEntry(key: world, value: id) in _real.entries) {
      final puzzle = await repo.loadPuzzle(world, id);
      final solution = _graph(_reference(world, id)['solution']);
      final outcome = runPuzzle(const DefaultEngine(), solution, puzzle);
      expect(outcome.suite.kind, ResultKind.correct, reason: '$id: ${outcome.suite.message}');
      expect(outcome.suite.hiddenSummary!.passed, puzzle.hiddenTests.length, reason: id);
      expect(outcome.suite.visible.every((c) => c.ok), isTrue, reason: id);
    }
  });

  testWidgets('a correct but slow program shows as Operation Limit, hidden cases stay counts',
      (tester) async {
    final puzzle = parsePuzzleJson(
      File('assets/puzzles/world_03/twin_beacons.json').readAsStringSync(),
    );
    final rejects = _reference('world_03', 'twin_beacons')['rejects']! as List<Object?>;
    final everyPair = rejects
        .cast<Map<String, Object?>>()
        .singleWhere((r) => r['name'] == 'compare every pair');
    final outcome = runPuzzle(const DefaultEngine(), _graph(everyPair['graph']), puzzle);
    expect(outcome.suite.kind, ResultKind.operationLimit);
    expect(outcome.suite.visible.every((c) => c.ok), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/results',
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: RouteSettings(
            name: '/results',
            arguments: ResultsArgs(
              puzzle: puzzle,
              validation: outcome.validation,
              suite: outcome.suite,
            ),
          ),
          builder: (_) => const ResultsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPERATION LIMIT'), findsOneWidget);
    // Since MS10 the screen explains the budget instead of the bare
    // 'This program took too many steps.' (still the suite's own message).
    expect(outcome.suite.message, 'This program took too many steps.');
    expect(
      find.text('Every case that finished came out right, but this solution uses too '
          'many operations: it was still running after 300,000, and the budget is 60,000.'),
      findsOneWidget,
    );
    expect(costRow(tester, 'steps'), ['Steps', '300,000+', '60,000']);
    expect(costRow(tester, 'memory').last, '4,000');
    expect(costRow(tester, 'depth').last, '32');
    expect(costRow(tester, 'blocks').last, '30');
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('v2'), findsOneWidget);
    expect(find.textContaining('of 10 hidden cases passed'), findsOneWidget);
    for (final hidden in puzzle.hiddenTests) {
      expect(find.textContaining(hidden.id), findsNothing, reason: hidden.id);
    }
  });

  testWidgets('world cards show progression, never the probes', (tester) async {
    // Since MS11 a world's card says where the player stands (see
    // progression_ui_test.dart); since MS12 a fresh install starts at
    // Foundations.
    await tester.pumpWidget(
      ProviderScope(
        overrides: campaignOverrides(MemoryProgressStore()),
        child: const MaterialApp(home: WorldSelectScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('probe'), findsNothing);
    expect(find.text('0 of 12 solved'), findsOneWidget);
    expect(find.text('Hash Maps'), findsOneWidget);
    expect(find.text('Locked — learn variables first'), findsOneWidget);
    expect(find.text('Locked — learn arrays first'), findsWidgets);
  });
}
