import 'package:algorun/app.dart';
import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun/editor/script_view.dart';
import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/progress_ledger.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/screens/puzzle/puzzle_screen.dart';
import 'package:algorun/screens/results/results_screen.dart';
import 'package:algorun/shared/theme/app_theme.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';
import 'support/phone.dart';
import 'support/progress_fixtures.dart';

/// M1: puzzles that open with a program — complete, repair and predict — in
/// the editor, the save and the lists.
final _campaign = shippedCampaign();
final _flags = _campaign.puzzles['flag_lines']!; // complete, everything locked
final _posts = _campaign.puzzles['fence_posts']!; // repair, nothing locked
final _mirror = _campaign.puzzles['mirror_shelf']!; // complete, a hole in a locked block
final _gloves = _campaign.puzzles['glove_pairs']!; // repair, a missing instruction
final _halve = _campaign.puzzles['halve_or_step']!; // predict

const _engine = DefaultEngine();

/// The editor as the puzzle screen opens it: the saved program, else the
/// starter.
EditorController _editor(Puzzle puzzle, {BlockGraph? saved}) =>
    EditorController(puzzle: puzzle, initialGraph: saved ?? puzzle.starter?.graph);

/// Places the piece the picker offers for [to] — by catalog id and, for a
/// named piece, its name — the way a tap in the picker does.
String _place(EditorController c, String catalogId, PortRef to, {String? name, int? index}) {
  final offered = c.placementsFor(to, index: index);
  final pick = offered.where((p) => p.catalogId == catalogId && (name == null || p.literals['name'] == name));
  expect(pick, isNotEmpty, reason: 'the picker for ${to.blockId}.${to.port} offers $catalogId ${name ?? ''}');
  final id = c.place(pick.first, to: to, index: index);
  expect(id, isNotNull, reason: '${c.flash}');
  return id!;
}

ResultKind _run(EditorController c) => runPuzzle(_engine, c.graph, c.puzzle).suite.kind;

Future<void> _pumpEditor(WidgetTester tester, Widget home) async {
  usePhone(tester, 360, 800, dpr: 2);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: buildAppTheme(AppPalette.light),
      home: home,
      routes: {'/results': (_) => const ResultsScreen()},
    ),
  ));
  await tester.pumpAndSettle();
}

/// Scrolls the program until [finder] is built: the script builds its
/// instructions lazily, so one below the fold is not in the tree yet.
Future<void> _see(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  final script = find.descendant(of: find.byType(ScriptView), matching: find.byType(Scrollable));
  await tester.scrollUntilVisible(finder, 120, scrollable: script.first);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Answers the question on screen with [number], on the game's number pad.
Future<void> _answer(WidgetTester tester, int number) async {
  await _tap(tester, find.byKey(const Key('predict-answer')));
  expect(find.byType(BottomSheet), findsOneWidget);
  for (final digit in '$number'.split('')) {
    await _tap(tester, find.byKey(Key('pad-$digit')));
  }
  await _tap(tester, find.byKey(const Key('pad-done')));
  expect(find.byType(BottomSheet), findsNothing);
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// A yes / no predict puzzle (none ships yet): `RETURN LENGTH nums > limit`.
Puzzle _boolPredict() => parsePuzzleJson('''
{
  "id": "long_enough", "title": "Long Enough", "world": "world_01", "tier": 1, "mode": "predict",
  "story": "Read the program.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }, { "name": "limit", "type": "num" }],
          "output": { "type": "bool" } },
  "blocks": { "allow": ["ctrl.return", "arr.len", "var.get", "cmp.gt"] },
  "limits": { "maxOps": 100 },
  "fixtures": {
    "visible": [
      { "id": "v1", "in": { "nums": [1, 2, 3], "limit": 2 }, "out": true },
      { "id": "v2", "in": { "nums": [4], "limit": 1 }, "out": false }
    ],
    "hidden": [{ "id": "h1", "in": { "nums": [], "limit": 0 }, "out": false }]
  },
  "starter": { "graph": {
    "variables": { "nums": "array<num>", "limit": "num" },
    "entryIds": ["ret"],
    "blocks": {
      "ret": { "id": "ret", "catalogId": "ctrl.return", "slots": { "value": { "ref": "gt" } } },
      "gt": { "id": "gt", "catalogId": "cmp.gt", "slots": { "left": { "ref": "len" }, "right": { "ref": "lim" } } },
      "len": { "id": "len", "catalogId": "arr.len", "slots": { "array": { "ref": "nums" } } },
      "nums": { "id": "nums", "catalogId": "var.get", "literals": { "name": "nums" } },
      "lim": { "id": "lim", "catalogId": "var.get", "literals": { "name": "limit" } }
    }
  } }
}
''');

void main() {
  group('the shipped set', () {
    final byMode = <PuzzleMode, List<Puzzle>>{};
    for (final p in _campaign.puzzles.values) {
      if (p.starter != null) (byMode[p.mode] ??= []).add(p);
    }

    test('three complete, three repair and three predict puzzles, in tiers 1 to 3', () {
      expect(byMode.keys.toSet(), {PuzzleMode.complete, PuzzleMode.repair, PuzzleMode.predict});
      for (final list in byMode.values) {
        expect(list, hasLength(3));
        for (final p in list) {
          expect(p.tier.index + 1, inInclusiveRange(1, 3), reason: p.id);
          expect(p.hints, hasLength(3), reason: p.id);
        }
      }
    });

    for (final p in _campaign.puzzles.values.where((p) => p.mode == PuzzleMode.complete || p.mode == PuzzleMode.repair)) {
      test('${p.id}: opens with its starter, which does not pass; its reference does', () {
        final c = _editor(p);
        expect(graphText(c.graph), graphText(_editor(p, saved: p.starter!.graph).graph));
        expect(c.blockCount, p.starter!.graph.playerBlockCount);
        expect(c.canUndo, isFalse, reason: 'the starter is where the puzzle begins, not an edit');
        expect(_run(c), isNot(ResultKind.correct));
        final world = _campaign.worldOf(p.id)!.id;
        expect(_run(_editor(p, saved: referenceSolution(world, p.id))), ResultKind.correct);
      });
    }

    for (final p in _campaign.puzzles.values.where((p) => p.isPredict)) {
      test('${p.id}: the fixture answers are what the program returns', () {
        final answers = {for (final c in p.visibleTests) c.id: c.output};
        final right = checkPredictions(_engine, p, answers);
        expect(right.suite.kind, ResultKind.correct, reason: '${right.suite.message}');
        // One answer off by one is a wrong answer, and only that one.
        final first = p.visibleTests.first;
        final off = {...answers, first.id: NumValue((first.output as NumValue).value + 1)};
        final wrong = checkPredictions(_engine, p, off);
        expect(wrong.suite.kind, ResultKind.wrongAnswer);
        expect(wrong.suite.visible.where((c) => !c.ok).map((c) => c.id), [first.id]);
        expect(wrong.suite.visible.first.expected, isNull, reason: 'the real answer stays in the engine');
      });
    }
  });

  group('complete and repair, played through the editor', () {
    test('flag_lines: the two missing instructions go into the locked loop', () {
      final c = _editor(_flags);
      const body = PortRef('b6', 'body');
      final first = _place(c, BlockIds.varSet, body, index: 0);
      c.setLiteral(first, 'name', 'total');
      final sum = _place(c, BlockIds.arithAdd, PortRef(first, 'value'));
      _place(c, BlockIds.varGet, PortRef(sum, 'left'), name: 'total');
      _place(c, BlockIds.varGet, PortRef(sum, 'right'), name: 'flags');
      final second = _place(c, BlockIds.varSet, body, index: 1);
      c.setLiteral(second, 'name', 'flags');
      final grow = _place(c, BlockIds.arithAdd, PortRef(second, 'value'));
      _place(c, BlockIds.varGet, PortRef(grow, 'left'), name: 'flags');
      final two = _place(c, BlockIds.litNum, PortRef(grow, 'right'));
      c.setLiteral(two, 'value', 2);
      expect(_run(c), ResultKind.correct);
      for (final id in _flags.starter!.locked) {
        expect(c.isLocked(id), isTrue, reason: '$id is still there');
      }
    });

    test('fence_posts: replacing the comparison repairs it', () {
      final c = _editor(_posts);
      expect(_run(c), ResultKind.wrongAnswer);
      // What REPLACE does: the value leaves its slot, another goes in.
      expect(c.deleteTree('b6'), isTrue);
      final le = _place(c, BlockIds.cmpLe, const PortRef('b7', 'condition'));
      _place(c, BlockIds.varGet, PortRef(le, 'left'), name: 'pos');
      _place(c, BlockIds.varGet, PortRef(le, 'right'), name: 'length');
      expect(_run(c), ResultKind.correct);
    });

    test('mirror_shelf: a locked block\'s empty slot can be filled', () {
      final c = _editor(_mirror);
      expect(c.isLocked('b6'), isTrue);
      expect(_run(c), ResultKind.invalidProgram, reason: 'hi has no value yet');
      final minus = _place(c, BlockIds.arithSub, const PortRef('b6', 'value'));
      final len = _place(c, BlockIds.arrLen, PortRef(minus, 'left'));
      _place(c, BlockIds.varGet, PortRef(len, 'array'), name: 'items');
      final one = _place(c, BlockIds.litNum, PortRef(minus, 'right'));
      c.setLiteral(one, 'value', 1);
      final check = _place(c, BlockIds.ctrlIf, const PortRef('b10', 'body'), index: 0);
      final differ = _place(c, BlockIds.cmpNe, PortRef(check, 'condition'));
      for (final (side, marker) in [('left', 'lo'), ('right', 'hi')]) {
        final at = _place(c, BlockIds.arrGet, PortRef(differ, side));
        _place(c, BlockIds.varGet, PortRef(at, 'array'), name: 'items');
        _place(c, BlockIds.varGet, PortRef(at, 'index'), name: marker);
      }
      final ret = _place(c, BlockIds.ctrlReturn, PortRef(check, 'then'));
      _place(c, BlockIds.litBool, PortRef(ret, 'value'));
      expect(_run(c), ResultKind.correct);
      // What the player put into the locked block is theirs to take out.
      expect(c.isLocked(minus), isFalse);
      expect(c.deleteTree(minus), isTrue);
    });

    test('glove_pairs: one missing instruction, added where it belongs', () {
      final c = _editor(_gloves);
      expect(_run(c), ResultKind.wrongAnswer);
      final inc = _place(c, BlockIds.varInc, const PortRef('b23', 'then'), name: 'j', index: 2);
      expect(c.graph.blocks[inc]!.literals['name'], 'j');
      expect(_run(c), ResultKind.correct);
    });
  });

  group('locked blocks', () {
    test('a locked block cannot be deleted, moved or changed', () {
      final c = _editor(_flags);
      final before = c.graph;
      c.selectBlock('b3'); // SET flags, locked
      final info = c.selection!;
      expect(info.locked, isTrue);
      expect(info.canDelete, isFalse);
      expect(info.moves, isEmpty);
      expect(c.deleteSelected(), isFalse);
      expect('${c.flash}', contains('part of the puzzle'));
      expect(c.moveSelected(MoveDirection.up), isFalse);
      c.setLiteral('b2', 'value', 9); // the 1 that flags starts at
      c.setLiteral('b3', 'name', 'total');
      expect(identical(c.graph, before), isTrue, reason: 'nothing changed, nothing to undo');
      expect(c.canUndo, isFalse);
      expect(c.canEdit('b2'), isFalse);
    });

    test('a block that holds a locked one cannot be deleted, but can still move', () {
      // The player wraps nothing here, so build the case: an unlocked IF
      // around the locked moves of mirror_shelf cannot exist — instead use a
      // puzzle whose lock sits inside an unlocked block.
      final json = _lockedInside();
      final c = _editor(json);
      c.selectBlock('loop');
      expect(c.selection!.locked, isFalse);
      expect(c.selection!.canDelete, isFalse, reason: 'it holds the locked step');
      expect(c.deleteTree('loop'), isFalse);
      expect(c.selection!.moves, contains(MoveDirection.down));
      expect(c.moveSelected(MoveDirection.down), isTrue);
      expect(c.graph.blocks.containsKey('step'), isTrue);
    });

    test('a program that never held the starter has no locks', () {
      // The campaign harness builds references from nothing, and the editor
      // hands out the same ids there: a block that merely shares a locked
      // block's id — even its kind and contents — must not be frozen.
      final c = EditorController(puzzle: _flags);
      final first = c.place(const Placement(catalogId: BlockIds.varSet, literals: {'name': 'total'}), to: PortRef.mainBody)!;
      expect(_flags.starter!.locked, contains(first));
      expect(_flags.starter!.graph.blocks[first]!.literals, {'name': 'total'});
      expect(c.isLocked(first), isFalse);
      c.setLiteral(first, 'name', 'flags');
      expect(c.graph.blocks[first]!.literals['name'], 'flags');
      expect(c.deleteTree(first), isTrue);
    });

    test('unlocked blocks next to locked ones edit as always, and UNDO works', () {
      final c = _editor(_posts);
      expect(c.isLocked('b6'), isFalse);
      c.selectBlock('b8');
      expect(c.selection!.canDelete, isTrue);
      expect(c.deleteSelected(), isTrue);
      expect(c.graph.blocks.containsKey('b8'), isFalse);
      c.undo();
      expect(c.graph.blocks.containsKey('b8'), isTrue);
    });

    testWidgets('the selection bar says a block is locked and offers nothing destructive', (tester) async {
      await _pumpEditor(tester, PuzzleEditor(puzzle: _flags, briefOpen: false));
      final set = find.descendant(of: find.byType(ScriptView), matching: find.text('SET'));
      expect(find.descendant(of: find.byType(ScriptView), matching: find.byIcon(Icons.lock_outline)), findsWidgets,
          reason: 'a locked instruction says so before it is tapped');
      await _tap(tester, set.first);
      expect(find.byKey(const Key('selection-locked')), findsOneWidget);
      await _tap(tester, find.text('DELETE'));
      expect(set, findsNWidgets(2));
      expect(_text(tester, 'block-count'), '9 / 26 blocks');
    });
  });

  group('start over', () {
    test('resetToStarter puts the starter back as one undo step', () {
      final c = _editor(_posts);
      final starter = graphText(c.graph);
      c.deleteTree('b7');
      final edited = graphText(c.graph);
      expect(edited, isNot(starter));
      c.resetToStarter();
      expect(graphText(c.graph), starter);
      expect('${c.flash}', contains('back to how the puzzle gave it'));
      c.undo();
      expect(graphText(c.graph), edited, reason: 'the player\'s version is one UNDO away');
    });

    test('a puzzle without a starter has nothing to go back to', () {
      final warm = _campaign.puzzles['warm_readings']!;
      final c = EditorController(puzzle: warm, initialGraph: referenceSolution('world_01', 'warm_readings'));
      final before = c.graph;
      c.resetToStarter();
      expect(identical(c.graph, before), isTrue);
    });

    testWidgets('the menu asks first; cancel keeps the work, confirm restores the starter', (tester) async {
      await _pumpEditor(
        tester,
        PuzzleEditor(puzzle: _posts, initialGraph: referenceSolution('world_01', 'fence_posts'), briefOpen: false),
      );
      Finder inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
      expect(inScript('LESS OR EQUAL'), findsOneWidget, reason: 'the saved, repaired program');

      await _tap(tester, find.byIcon(Icons.more_vert));
      expect(find.text('Clear the program'), findsNothing, reason: 'a starter puzzle goes back to its starter');
      await _tap(tester, find.text('Start over'));
      expect(find.text('Start over?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(inScript('LESS OR EQUAL'), findsOneWidget);

      await _tap(tester, find.byIcon(Icons.more_vert));
      await _tap(tester, find.text('Start over'));
      await _tap(tester, find.byKey(const Key('start-over-confirm')));
      expect(find.textContaining('back to how the puzzle gave it'), findsOneWidget);
      await _see(tester, inScript('LESS THAN'));
      expect(inScript('LESS OR EQUAL'), findsNothing);
      expect(inScript('LESS THAN'), findsOneWidget, reason: 'the program the puzzle gave');

      await _tap(tester, find.byTooltip('Undo'));
      await _see(tester, inScript('LESS OR EQUAL'));
      expect(inScript('LESS OR EQUAL'), findsOneWidget);
    });

    testWidgets('a puzzle without a starter still offers Clear the program', (tester) async {
      await _pumpEditor(tester, PuzzleEditor(puzzle: _campaign.puzzles['warm_readings']!, briefOpen: false));
      await _tap(tester, find.byIcon(Icons.more_vert));
      expect(find.text('Clear the program'), findsOneWidget);
      expect(find.text('Start over'), findsNothing);
    });
  });

  group('the brief', () {
    testWidgets('says what the mode asks', (tester) async {
      await _pumpEditor(tester, PuzzleEditor(puzzle: _posts));
      expect(find.byKey(const Key('mode-help')), findsOneWidget);
      expect(find.text('This program has a mistake. Find it and fix it, then RUN.'), findsOneWidget);
      expect(find.text('TIER 1 · repair'), findsOneWidget);
    });

    testWidgets('a build puzzle has no mode help', (tester) async {
      await _pumpEditor(tester, PuzzleEditor(puzzle: _campaign.puzzles['warm_readings']!));
      expect(find.byKey(const Key('mode-help')), findsNothing);
    });
  });

  group('saving', () {
    PlayerSave open(PlayerSave save, Puzzle puzzle) => openPuzzle(save, _campaign, puzzle).$1;

    test('a save from before M1 reads unchanged, and a starter puzzle then opens with its starter', () {
      // A version 1 save as the frozen build wrote it: one solved puzzle with
      // its best and its programs, one draft, settings, a session.
      final solution = referenceSolution('world_01', 'warm_readings');
      final draft = referenceSolution('world_01', 'highest_tide');
      final old = encodeSave(PlayerSave(
        puzzles: {
          'warm_readings': PuzzleProgress(
            puzzleVersion: 1,
            completed: true,
            best: const RunNumbers(ops: 40, peakAlloc: 0, peakDepth: 1, blocks: 12, hintsUsed: 1),
            lastRun: const RunRecord(
              result: ResultKind.wrongAnswer,
              numbers: RunNumbers(ops: 44, peakAlloc: 0, peakDepth: 1, blocks: 13, hintsUsed: 2),
            ),
            solution: solution,
            draft: solution,
          ),
          'highest_tide': PuzzleProgress(puzzleVersion: 1, draft: draft, editedSinceRun: true),
        },
        settings: const PlayerSettings(language: 'tr', theme: 'dark', showBriefOnOpen: false),
        session: const CurrentSession(worldId: 'world_01', puzzleId: 'highest_tide'),
      ));
      expect(old, contains('"saveVersion":1'));

      final read = decodeSave(old);
      expect(read.usable, isTrue);
      expect(read.issues, isEmpty);
      expect(encodeSave(read.save), old, reason: 'M1 adds nothing to the save format');
      expect(currentSaveVersion, 1);

      // Nothing saved for the new puzzles: each opens with its starter.
      for (final puzzle in [_flags, _posts]) {
        final (_, opened) = openPuzzle(read.save, _campaign, puzzle);
        expect(opened.graph, isNull);
        expect(opened.puzzleChanged, isFalse);
        expect(graphText(_editor(puzzle, saved: opened.graph).graph), graphText(_editor(puzzle).graph));
      }
      final progress = evaluateCampaign(_campaign, read.save);
      expect(progress.puzzleStatus('warm_readings'), PuzzleStatus.completed);
      expect(progress.puzzleStatus('highest_tide'), PuzzleStatus.inProgress);
      expect(progress.puzzleStatus('fence_posts'), PuzzleStatus.open);
    });

    test('the program the player edited is what comes back, not the starter', () {
      final c = _editor(_posts);
      c.deleteTree('b8'); // the player's own change
      var save = open(PlayerSave.fresh, _posts);
      save = saveDraft(save, _campaign, _posts, c.graphForSave);
      final (_, opened) = openPuzzle(reloaded(save), _campaign, _posts);
      expect(opened.graph, isNotNull);
      final restored = _editor(_posts, saved: opened.graph);
      expect(graphText(restored.graph), graphText(c.graph));
      expect(restored.graph.blocks.containsKey('b8'), isFalse);
      // …and the starter is still one Start over away.
      restored.resetToStarter();
      expect(graphText(restored.graph), graphText(_editor(_posts).graph));
    });

    test('a program the player emptied stays empty', () {
      final c = _editor(_posts);
      for (final id in [...c.graph.entryIds]) {
        c.deleteTree(id);
      }
      expect(c.graph.blocks, isEmpty);
      final save = saveDraft(open(PlayerSave.fresh, _posts), _campaign, _posts, c.graphForSave);
      final (_, opened) = openPuzzle(reloaded(save), _campaign, _posts);
      expect(opened.graph, isNotNull);
      expect(_editor(_posts, saved: opened.graph).graph.blocks, isEmpty);
    });

    test('locks hold on a restored program', () {
      final c = _editor(_mirror);
      _place(c, BlockIds.litNum, const PortRef('b6', 'value'));
      final save = saveDraft(open(PlayerSave.fresh, _mirror), _campaign, _mirror, c.graphForSave);
      final restored = _editor(_mirror, saved: openPuzzle(reloaded(save), _campaign, _mirror).$2.graph);
      expect(restored.isLocked('b6'), isTrue);
      expect(restored.deleteTree('b10'), isFalse);
    });

    test('a solved repair keeps the repaired program as its best solution', () {
      final fixed = referenceSolution('world_01', 'fence_posts');
      var save = open(PlayerSave.fresh, _posts);
      final (next, outcome) = recordRun(save, _campaign, _posts, fixed, runPuzzle(_engine, fixed, _posts).suite);
      save = reloaded(next);
      expect(outcome.firstCompletion, isTrue);
      expect(save['fence_posts']!.completed, isTrue);
      expect(graphText(save['fence_posts']!.solution!), graphText(fixed));
    });

    test('a predict puzzle saves its completion and its last result, and no program', () {
      var save = open(PlayerSave.fresh, _halve);
      final wrong = checkPredictions(_engine, _halve, const {'v1': NumValue(4)}, hintsUsed: 1).suite;
      final (afterWrong, first) = recordRun(save, _campaign, _halve, null, wrong);
      save = reloaded(afterWrong);
      expect(first.firstCompletion, isFalse);
      expect(save['halve_or_step']!.completed, isFalse);
      expect(save['halve_or_step']!.lastRun!.result, ResultKind.wrongAnswer);
      expect(save['halve_or_step']!.draft, isNull);
      expect(evaluateCampaign(_campaign, save).puzzleStatus('halve_or_step'), PuzzleStatus.inProgress);

      final answers = {for (final c in _halve.visibleTests) c.id: c.output};
      final right = checkPredictions(_engine, _halve, answers, hintsUsed: 1).suite;
      final (afterRight, second) = recordRun(save, _campaign, _halve, null, right);
      save = reloaded(afterRight);
      expect(second.firstCompletion, isTrue);
      expect(second.newSolution, isFalse);
      final progress = save['halve_or_step']!;
      expect(progress.completed, isTrue);
      expect(progress.best!.hintsUsed, 1);
      expect(progress.solution, isNull);
      expect(progress.draft, isNull);
      expect(encodeSave(save), isNot(contains('"draft"')));
      expect(evaluateCampaign(_campaign, save).puzzleStatus('halve_or_step'), PuzzleStatus.completed);

      // Solving it again with fewer hints is a new best on hints only.
      final clean = checkPredictions(_engine, _halve, answers).suite;
      expect(recordRun(save, _campaign, _halve, null, clean).$2.improved, {BestMetric.hintsUsed});
    });
  });

  group('predict', () {
    testWidgets('the program is shown read only', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _halve, briefOpen: false));
      Finder inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
      expect(find.byKey(const Key('predict-read-only')), findsOneWidget);
      expect(inScript('WHILE'), findsOneWidget);
      expect(inScript('FLOOR DIVIDE'), findsOneWidget);
      expect(find.text('add step'), findsNothing);
      expect(find.text('RUN'), findsNothing);

      // Tapping a block, a name or a number selects and opens nothing.
      await _tap(tester, inScript('WHILE'));
      await _tap(tester, inScript('moves').first);
      await _tap(tester, inScript('2').first);
      expect(find.text('SELECTED'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('DELETE'), findsNothing);
    });

    testWidgets('three right answers on the pad solve it', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _halve, briefOpen: false));
      expect(_text(tester, 'predict-question'), 'QUESTION 1 OF 3');
      expect(find.text('start = 6', findRichText: true), findsOneWidget);
      expect(_text(tester, 'predict-answered'), '0 of 3 answered');
      expect(tester.widget<FilledButton>(find.byKey(const Key('predict-check'))).onPressed, isNull);

      await _answer(tester, 4);
      expect(_text(tester, 'predict-question'), 'QUESTION 2 OF 3', reason: 'on to the next open question');
      expect(find.text('start = 7', findRichText: true), findsOneWidget);
      await _answer(tester, 5);
      await _answer(tester, 5);
      expect(_text(tester, 'predict-answered'), '3 of 3 answered');

      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('Every answer is what the program returns.'), findsOneWidget);
      expect(find.text('YOUR ANSWERS'), findsOneWidget);
      expect(find.text('WHAT IT COST'), findsNothing, reason: 'the program is not the player\'s');
      expect(find.text('BACK TO THE QUESTIONS'), findsOneWidget);
      for (final hidden in _halve.hiddenTests) {
        expect(find.textContaining(hidden.id), findsNothing);
      }
    });

    testWidgets('a wrong answer says which, never what the right one is', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _halve, briefOpen: false));
      await _answer(tester, 4);
      await _answer(tester, 9); // 7 takes 5 moves
      await _answer(tester, 5);
      await _tap(tester, find.byKey(const Key('predict-check')));

      expect(find.text('WRONG ANSWER'), findsOneWidget);
      expect(find.text('2 of 3 answers are what the program returns.'), findsOneWidget);
      final second = find.byKey(const Key('predict-result-2'));
      expect(find.descendant(of: second, matching: find.text('not what the program returns')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('your answer: 9')), findsOneWidget);
      expect(find.descendant(of: second, matching: find.text('start = 7')), findsOneWidget);
      expect(find.text('your answer: 5'), findsOneWidget, reason: 'only the third question was answered 5');
      expect(find.textContaining('The right answer is not shown'), findsOneWidget);

      // Back on the question that was wrong, with the answer still there.
      await _tap(tester, find.text('BACK TO THE QUESTIONS'));
      expect(_text(tester, 'predict-question'), 'QUESTION 2 OF 3');
      expect(find.descendant(of: find.byKey(const Key('predict-answer')), matching: find.text('9')), findsOneWidget);

      // Corrected: the pad opens on the old answer, selected, and replaces it.
      await _answer(tester, 5);
      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.text('CORRECT'), findsOneWidget);
    });

    testWidgets('closing the pad without choosing answers nothing', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _halve, briefOpen: false));
      await _tap(tester, find.byKey(const Key('predict-answer')));
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(180, 60)); // outside the sheet
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(_text(tester, 'predict-answered'), '0 of 3 answered');
      expect(find.text('Tap to answer'), findsOneWidget);
    });

    testWidgets('a yes / no program is answered with TRUE and FALSE', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _boolPredict(), briefOpen: false));
      expect(find.byKey(const Key('predict-answer')), findsNothing);
      expect(find.text('nums = [1, 2, 3]', findRichText: true), findsOneWidget);
      await _tap(tester, find.byKey(const Key('predict-true')));
      expect(_text(tester, 'predict-question'), 'QUESTION 2 OF 2');
      await _tap(tester, find.byKey(const Key('predict-true'))); // wrong: 1 is not above 1
      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.text('WRONG ANSWER'), findsOneWidget);
      expect(find.text('your answer: TRUE'), findsNWidgets(2));
      await _tap(tester, find.text('BACK TO THE QUESTIONS'));
      await _tap(tester, find.byKey(const Key('predict-false')));
      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.text('CORRECT'), findsOneWidget);
    });

    testWidgets('hints count on the result', (tester) async {
      await _pumpEditor(tester, PredictPuzzle(puzzle: _halve, briefOpen: false));
      await _tap(tester, find.byKey(const Key('hints-reveal')));
      await _answer(tester, 4);
      await _answer(tester, 5);
      await _answer(tester, 5);
      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.byKey(const Key('predict-hints')), findsOneWidget);
    });

    testWidgets('fits a 360 × 640 phone at the largest font, in Turkish wording too', (tester) async {
      usePhone(tester, 360, 640, textScale: 1.6);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(theme: buildAppTheme(AppPalette.dark), home: PredictPuzzle(puzzle: _halve)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('predict-check')), findsOneWidget);
    });
  });

  group('in the app', () {
    Future<MemoryProgressStore> launch(WidgetTester tester, [PlayerSave? save]) async {
      final store = save == null ? MemoryProgressStore() : MemoryProgressStore(encodeSave(save));
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(overrides: campaignOverrides(store, campaign: _campaign), child: const AlgorunApp()),
      );
      await tester.pumpAndSettle();
      return store;
    }

    Future<void> openPuzzleRow(WidgetTester tester, String world, String id) async {
      await _tap(tester, find.text('ENTER').evaluate().isEmpty ? find.text('CONTINUE') : find.text('ENTER'));
      if (find.text('Worlds').evaluate().isNotEmpty) {
        await _tap(tester, find.byKey(Key('world-$world')));
      }
      await tester.scrollUntilVisible(find.byKey(Key('puzzle-$id')), 200, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.byKey(Key('puzzle-$id')));
    }

    testWidgets('worlds and puzzle rows carry mode badges', (tester) async {
      await launch(tester);
      await _tap(tester, find.text('ENTER'));
      final foundations = find.byKey(const Key('world-world_01'));
      for (final mode in ['complete', 'repair', 'predict']) {
        expect(find.descendant(of: foundations, matching: find.byKey(Key('mode-badge-$mode'))), findsOneWidget);
      }
      expect(find.descendant(of: foundations, matching: find.text('REPAIR')), findsOneWidget);
      // A world without such puzzles shows none.
      final maps = find.byKey(const Key('world-world_03'));
      expect(find.descendant(of: maps, matching: find.byKey(const Key('mode-badge-repair'))), findsNothing);

      await _tap(tester, foundations);
      final row = find.byKey(const Key('puzzle-fence_posts'));
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: row, matching: find.text('REPAIR')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Tier 1 · repair')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('puzzle-warm_readings')), matching: find.byType(Tooltip)),
        findsNothing,
        reason: 'a build puzzle has no badge',
      );
    });

    testWidgets('a repair puzzle opens with its starter, saves the edit, and restores it', (tester) async {
      final store = await launch(tester);
      await openPuzzleRow(tester, 'world_01', 'fence_posts');
      Finder inScript(String text) => find.descendant(of: find.byType(ScriptView), matching: find.text(text));
      expect(inScript('LESS THAN'), findsOneWidget);
      expect(_text(tester, 'block-count'), '15 / 23 blocks');
      expect(decodeSave(store.text!).save['fence_posts']?.draft, isNull, reason: 'opening is not an edit');

      // Delete INCREMENT posts: an edit of the player's own.
      await _tap(tester, inScript('INCREMENT'));
      await _tap(tester, find.text('DELETE'));
      expect(_text(tester, 'block-count'), '14 / 23 blocks');
      await _tap(tester, find.byType(BackButton));
      final draft = decodeSave(store.text!).save['fence_posts']!.draft!;
      expect(draft.blocks, hasLength(14));

      await _tap(tester, find.byKey(const Key('puzzle-fence_posts')));
      expect(_text(tester, 'block-count'), '14 / 23 blocks', reason: 'the edited program, not the starter');
      expect(inScript('INCREMENT'), findsNothing);
    });

    testWidgets('a predict puzzle is solved in the app and saved without a program', (tester) async {
      final store = await launch(tester);
      await openPuzzleRow(tester, 'world_01', 'halve_or_step');
      expect(find.byKey(const Key('predict-read-only')), findsOneWidget);
      expect(find.text('Read the program. Without running it, say what it returns for each input, then CHECK.'),
          findsOneWidget);
      await _answer(tester, 4);
      await _answer(tester, 5);
      await _answer(tester, 5);
      await _tap(tester, find.byKey(const Key('predict-check')));
      expect(find.text('CORRECT'), findsOneWidget);
      expect(find.text('Puzzle solved.'), findsOneWidget);
      final saved = decodeSave(store.text!).save['halve_or_step']!;
      expect(saved.completed, isTrue);
      expect(saved.draft, isNull);
      expect(saved.solution, isNull);

      await _tap(tester, find.text('BACK TO THE QUESTIONS'));
      await _tap(tester, find.byType(BackButton));
      final row = find.byKey(const Key('puzzle-halve_or_step'));
      expect(find.descendant(of: row, matching: find.text('Solved')), findsOneWidget,
          reason: 'no "best steps" for a program the player only read');
    });
  });
}

/// A complete puzzle whose locked instruction sits inside an unlocked loop.
Puzzle _lockedInside() => parsePuzzleJson('''
{
  "id": "locked_inside", "title": "Locked inside", "world": "world_01", "tier": 1, "mode": "complete",
  "story": "Count them.",
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "ctrl.foreach", "var.get", "var.inc", "var.set", "lit.num"] },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  },
  "variables": { "pool": [{ "name": "count", "type": "num" }, { "name": "x", "type": "num" }] },
  "starter": {
    "locked": ["step"],
    "graph": {
      "variables": { "nums": "array<num>", "count": "num", "x": "num" },
      "entryIds": ["loop", "ret"],
      "blocks": {
        "loop": { "id": "loop", "catalogId": "ctrl.foreach", "literals": { "name": "x" },
                  "slots": { "collection": { "ref": "nums" }, "body": { "list": ["step"] } } },
        "nums": { "id": "nums", "catalogId": "var.get", "literals": { "name": "nums" } },
        "step": { "id": "step", "catalogId": "var.inc", "literals": { "name": "count" } },
        "ret": { "id": "ret", "catalogId": "ctrl.return", "slots": { "value": { "ref": "c" } } },
        "c": { "id": "c", "catalogId": "var.get", "literals": { "name": "count" } }
      }
    }
  }
}
''');
