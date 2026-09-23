import 'dart:convert';
import 'dart:io';

import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/file_progress_store.dart';
import 'package:algorun/progress/progress_store.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/campaign_files.dart';
import '../support/progress_fixtures.dart';

const _numbers = RunNumbers(ops: 23, peakAlloc: 4, peakDepth: 1, blocks: 9, hintsUsed: 2);

PlayerSave _richSave() => PlayerSave(
      puzzles: {
        'twin_beacons': PuzzleProgress(
          puzzleVersion: 1,
          completed: true,
          best: _numbers,
          solution: lengthGraph(),
          draft: lengthGraph(retId: 'edited'),
          lastRun: const RunRecord(result: ResultKind.wrongAnswer, numbers: _numbers),
          editedSinceRun: true,
        ),
        'smallest_cart': PuzzleProgress(puzzleVersion: 1, draft: lengthGraph()),
      },
      settings: const PlayerSettings(showBriefOnOpen: false),
      session: const CurrentSession(worldId: 'world_03', puzzleId: 'twin_beacons'),
    );

Map<String, Object?> _json(String text) => jsonDecode(text) as Map<String, Object?>;

String _with(void Function(Map<String, Object?> json) change) {
  final json = _json(encodeSave(_richSave()));
  change(json);
  return jsonEncode(json);
}

Map<String, Object?> _puzzleJson(Map<String, Object?> json, String id) =>
    (json['puzzles']! as Map<String, Object?>)[id]! as Map<String, Object?>;

/// Save [graph] as a draft, read it back, and return what came back.
BlockGraph _roundTripGraph(BlockGraph graph) {
  final save = PlayerSave(puzzles: {'p1': PuzzleProgress(puzzleVersion: 1, draft: graph)});
  final read = decodeSave(encodeSave(save));
  expect(read.issues, isEmpty);
  return read.save['p1']!.draft!;
}

Map<String, Object?> _block(String id, String catalogId,
        {Map<String, Object?> slots = const {}, Map<String, Object?> literals = const {}}) =>
    {'id': id, 'catalogId': catalogId, 'slots': slots, 'literals': literals};

void main() {
  group('persistence', () {
    test('1. a save survives the round trip field by field', () {
      final read = decodeSave(encodeSave(_richSave()));
      expect(read.usable, isTrue);
      expect(read.issues, isEmpty);
      final twin = read.save['twin_beacons']!;
      expect(twin.completed, isTrue);
      expect(twin.best!.ops, 23);
      expect(twin.best!.hintsUsed, 2);
      expect(twin.lastRun!.result, ResultKind.wrongAnswer);
      expect(twin.editedSinceRun, isTrue);
      expect(graphText(twin.solution!), graphText(lengthGraph()));
      expect(graphText(twin.draft!), graphText(lengthGraph(retId: 'edited')));
      expect(read.save['smallest_cart']!.completed, isFalse);
      expect(read.save.settings.showBriefOnOpen, isFalse);
      expect(read.save.session!.puzzleId, 'twin_beacons');
      expect(encodeSave(read.save), encodeSave(_richSave()));
    });

    test('2. serialization is deterministic: sorted keys, same text every time', () {
      final a = encodeSave(_richSave());
      final reordered = _richSave();
      final b = encodeSave(reordered.copyWith(puzzles: {
        for (final id in reordered.puzzles.keys.toList().reversed) id: reordered.puzzles[id]!,
      }));
      expect(b, a);
      expect(encodeSave(_richSave()), a);
      final json = _json(a);
      expect(json.keys.toList(), ['puzzles', 'saveVersion', 'session', 'settings']);
      expect((json['puzzles']! as Map).keys.toList(), ['smallest_cart', 'twin_beacons']);
      expect(json['saveVersion'], currentSaveVersion);
    });

    test('3. a fresh install needs no save', () async {
      final loaded = await MemoryProgressStore().load();
      expect(loaded.issues, isEmpty);
      expect(loaded.save.puzzles, isEmpty);
      expect(loaded.save.session, isNull);
      expect(loaded.save.settings.showBriefOnOpen, isTrue);
      expect(_json(encodeSave(PlayerSave.fresh)), {
        'puzzles': <String, Object?>{},
        'saveVersion': 1,
        'settings': {'showBriefOnOpen': true},
      });
    });

    test('4. text that is not JSON is kept aside and play starts fresh', () async {
      for (final text in ['{"saveVersion": 1, "puzzles": ', 'not json', '[1, 2]', '"text"', 'null']) {
        final read = decodeSave(text);
        expect(read.usable, isFalse, reason: text);
        expect(read.save.puzzles, isEmpty);
        expect(read.issues, isNotEmpty);
      }
      final store = MemoryProgressStore('not json');
      final loaded = await store.load();
      expect(loaded.save.puzzles, isEmpty);
      expect(store.keptAside, ['not json']);
    });

    test('5. a missing, invalid or newer save version is not read as this one', () {
      for (final version in [null, 0, -1, '1', 1.5, currentSaveVersion + 1]) {
        final text = _with((json) => version == null ? json.remove('saveVersion') : json['saveVersion'] = version);
        final read = decodeSave(text);
        expect(read.usable, isFalse, reason: '$version');
        expect(read.save.puzzles, isEmpty, reason: '$version');
        expect(read.issues.single.path, 'saveVersion');
      }
      expect(decodeSave(_with((json) => json['saveVersion'] = 2)).issues.single.message, contains('newer build'));
    });

    test('6. damaged puzzle progress loses only the damaged part, and never gains a completion', () {
      final text = _with((json) {
        final twin = _puzzleJson(json, 'twin_beacons');
        twin['best'] = 'fast';
        twin['lastRun'] = {'result': 'exploded', 'ops': 1};
        twin['draft'] = {'blocks': 'none'};
        final cart = _puzzleJson(json, 'smallest_cart');
        cart['completed'] = 'yes';
        cart['best'] = {'ops': 1, 'peakAlloc': 0, 'peakDepth': 1, 'blocks': 1, 'hintsUsed': 0};
        cart['solution'] = cart['draft'];
      });
      final read = decodeSave(text);
      expect(read.usable, isTrue);
      final twin = read.save['twin_beacons']!;
      expect(twin.completed, isTrue);
      expect(twin.best, isNull);
      expect(twin.lastRun, isNull);
      expect(twin.draft, isNull);
      expect(twin.solution, isNotNull, reason: 'the undamaged solution stays');
      final cart = read.save['smallest_cart']!;
      expect(cart.completed, isFalse, reason: '"yes" is not a completion');
      expect(cart.best, isNull);
      expect(cart.solution, isNull);
      expect(cart.draft, isNotNull);
      expect(read.save.session!.puzzleId, 'twin_beacons');
      expect(read.issues.map((i) => i.path), containsAll([
        'puzzles.twin_beacons.best',
        'puzzles.twin_beacons.lastRun.result',
        'puzzles.twin_beacons.draft',
        'puzzles.smallest_cart.completed',
        'puzzles.smallest_cart.best',
        'puzzles.smallest_cart.solution',
      ]));
    });

    test('6b. a program that does not hold together is dropped, not shown', () {
      final dangling = {
        'variables': <String, Object?>{},
        'entryIds': ['ret'],
        'blocks': {'ret': _block('ret', 'ctrl.return', slots: {'value': {'ref': 'gone'}})},
      };
      final unknown = {
        'variables': <String, Object?>{},
        'entryIds': ['x'],
        'blocks': {'x': _block('x', 'future.block')},
      };
      final badType = {'variables': {'n': 'number!'}, 'entryIds': <String>[], 'blocks': <String, Object?>{}};
      for (final graph in [dangling, unknown, badType]) {
        final read = decodeSave(_with((json) => _puzzleJson(json, 'smallest_cart')['draft'] = graph));
        expect(read.save['smallest_cart']!.draft, isNull, reason: '$graph');
        expect(read.issues.single.path, 'puzzles.smallest_cart.draft');
      }
    });

    test('7. an unknown puzzle id is kept but plays no part; a malformed id is dropped', () {
      final text = _with((json) {
        final puzzles = json['puzzles']! as Map<String, Object?>;
        puzzles['retired_puzzle'] = {'puzzleVersion': 1, 'completed': true};
        puzzles['Not An Id!'] = {'puzzleVersion': 1, 'completed': true};
        puzzles['twin_beacons_draft'] = 'not an object';
      });
      final read = decodeSave(text);
      expect(read.save.puzzles.keys, containsAll(['retired_puzzle', 'twin_beacons', 'smallest_cart']));
      expect(read.save.puzzles.keys, isNot(contains('Not An Id!')));
      expect(read.save.puzzles.keys, isNot(contains('twin_beacons_draft')));
      final progress = evaluateCampaign(shippedCampaign(), read.save);
      expect(progress.puzzles.keys, isNot(contains('retired_puzzle')));
      expect(progress.puzzleCount, 5);
    });

    test('8. a deleted puzzle: its progress and session are ignored, everything else stands', () {
      // The campaign no longer lists twin_beacons (world 03 is emptied).
      final full = shippedCampaign();
      final manifest = WorldsManifest([
        for (final w in full.manifest.worlds)
          w.id == 'world_03'
              ? WorldDef(id: w.id, title: w.title, index: w.index, puzzleIds: const [], concepts: w.concepts,
                  prerequisites: w.prerequisites)
              : w,
      ]);
      final campaign = Campaign(manifest, full.puzzles);
      final save = PlayerSave(
        puzzles: {
          'smallest_cart': const PuzzleProgress(puzzleVersion: 1, completed: true),
          'twin_beacons': const PuzzleProgress(puzzleVersion: 1, completed: true),
        },
        session: const CurrentSession(worldId: 'world_03', puzzleId: 'twin_beacons'),
      );
      final progress = evaluateCampaign(campaign, reloaded(save));
      expect(progress.puzzles.keys, isNot(contains('twin_beacons')));
      expect(progress.currentPuzzleId, isNull, reason: 'CONTINUE does not point at a puzzle that is gone');
      expect(progress.puzzleStatus('smallest_cart'), PuzzleStatus.completed);
      expect(progress.worldStatus('world_03'), WorldStatus.empty);
      expect(reloaded(save)['twin_beacons']!.completed, isTrue, reason: 'kept, in case it comes back');
    });

    test('9. a damaged section does not take the others with it', () {
      final noPuzzles = decodeSave(_with((json) => json['puzzles'] = ['not', 'a', 'map']));
      expect(noPuzzles.usable, isTrue);
      expect(noPuzzles.save.puzzles, isEmpty);
      expect(noPuzzles.save.settings.showBriefOnOpen, isFalse);
      expect(noPuzzles.save.session!.puzzleId, 'twin_beacons');

      final noSettings = decodeSave(_with((json) {
        json['settings'] = {'showBriefOnOpen': 'sometimes'};
        json['session'] = {'worldId': 7};
      }));
      expect(noSettings.save.settings.showBriefOnOpen, isTrue);
      expect(noSettings.save.session, isNull);
      expect(noSettings.save.puzzles, hasLength(2));
      expect(noSettings.issues.map((i) => i.path), ['settings.showBriefOnOpen', 'session']);
    });

    test('unknown fields are read past and not written back', () {
      final read = decodeSave(_with((json) {
        json['achievements'] = ['first_blood'];
        _puzzleJson(json, 'twin_beacons')['stars'] = 3;
      }));
      expect(read.usable, isTrue);
      expect(read.issues, isEmpty);
      final written = encodeSave(read.save);
      expect(written, isNot(contains('achievements')));
      expect(written, isNot(contains('stars')));
      expect(written, encodeSave(_richSave()));
    });

    test('a save holds only player state: no hidden cases, no references, no IR', () {
      final campaign = shippedCampaign();
      final puzzle = campaign.puzzles['twin_beacons']!;
      final json = _json(encodeSave(_richSave()));
      expect(json.keys.toSet(), {'saveVersion', 'puzzles', 'settings', 'session'});
      for (final entry in (json['puzzles']! as Map<String, Object?>).values) {
        expect((entry! as Map).keys.toSet().difference(
            {'puzzleVersion', 'completed', 'best', 'lastRun', 'solution', 'draft', 'editedSinceRun'}), isEmpty);
      }
      final text = encodeSave(_richSave());
      for (final hidden in puzzle.hiddenTests) {
        expect(text, isNot(contains(hidden.id)));
      }
      for (final word in ['fixtures', 'hidden', 'rejects', 'notes', 'functions', '"kind"']) {
        expect(text, isNot(contains(word)), reason: word);
      }
    });
  });

  group('programs', () {
    test('10. a simple program', () {
      final graph = lengthGraph();
      expect(graphText(_roundTripGraph(graph)), graphText(graph));
    });

    test('11. nested IF with ELSE', () {
      final graph = BlockGraph.fromJson({
        'variables': {'nums': 'array<num>', 'x': 'num'},
        'entryIds': ['outer'],
        'blocks': {
          'outer': _block('outer', 'ctrl.if', slots: {
            'condition': {'ref': 't1'},
            'then': {'list': ['inner']},
            'else': {'ref': 'else1'},
          }),
          't1': _block('t1', 'lit.bool', literals: {'value': true}),
          'inner': _block('inner', 'ctrl.if', slots: {
            'condition': {'ref': 't2'},
            'then': {'list': ['ret1']},
          }),
          't2': _block('t2', 'lit.bool', literals: {'value': false}),
          'ret1': _block('ret1', 'ctrl.return', slots: {'value': {'ref': 'one'}}),
          'one': _block('one', 'lit.num', literals: {'value': 1}),
          'else1': _block('else1', 'ctrl.else', slots: {'body': {'list': ['ret2']}}),
          'ret2': _block('ret2', 'ctrl.return', slots: {'value': {'ref': 'two'}}),
          'two': _block('two', 'lit.num', literals: {'value': 2}),
        },
      });
      final back = _roundTripGraph(graph);
      expect(graphText(back), graphText(graph));
      expect(back.slotList('outer', 'then'), ['inner']);
      expect(back.slotList('outer', 'else'), ['else1']);
    });

    test('12. loops keep their bodies in order', () {
      final graph = BlockGraph.fromJson({
        'variables': {'nums': 'array<num>', 'i': 'num', 'c': 'num'},
        'entryIds': ['set0', 'loop', 'w'],
        'blocks': {
          'set0': _block('set0', 'var.set', slots: {'value': {'ref': 'z'}}, literals: {'name': 'c'}),
          'z': _block('z', 'lit.num', literals: {'value': 0}),
          'loop': _block('loop', 'ctrl.for_range', literals: {'name': 'i'}, slots: {
            'start': {'ref': 'a'},
            'end': {'ref': 'b'},
            'body': {'list': ['inc1', 'inc2']},
          }),
          'a': _block('a', 'lit.num', literals: {'value': 0}),
          'b': _block('b', 'lit.num', literals: {'value': 3}),
          'inc1': _block('inc1', 'var.inc', literals: {'name': 'c'}),
          'inc2': _block('inc2', 'var.inc', literals: {'name': 'c'}),
          'w': _block('w', 'ctrl.while', slots: {'condition': {'ref': 'f'}, 'body': {'list': ['inc3']}}),
          'f': _block('f', 'lit.bool', literals: {'value': false}),
          'inc3': _block('inc3', 'var.inc', literals: {'name': 'c'}),
        },
      });
      final back = _roundTripGraph(graph);
      expect(graphText(back), graphText(graph));
      expect(back.slotList('loop', 'body'), ['inc1', 'inc2']);
      expect(back.entryIds, ['set0', 'loop', 'w']);
    });

    test('13. variables and literals keep their types and values', () {
      final graph = BlockGraph.fromJson({
        'variables': {
          'nums': 'array<num>',
          'seen': 'set<num>',
          'node': 'listNode?',
          'counts': 'map<str,num>',
          'flag': 'bool',
        },
        'entryIds': ['s1', 's2'],
        'blocks': {
          's1': _block('s1', 'var.set', slots: {'value': {'ref': 'n'}}, literals: {'name': 'x'}),
          'n': _block('n', 'lit.num', literals: {'value': -999999}),
          's2': _block('s2', 'var.set', slots: {'value': {'ref': 'b'}}, literals: {'name': 'flag'}),
          'b': _block('b', 'lit.bool', literals: {'value': false}),
        },
      });
      final back = _roundTripGraph(graph);
      expect(back.variables['node'], ValueType.listNode.asNullable);
      expect(back.variables['counts'], ValueType.mapOf(ValueType.string, ValueType.number));
      expect(back.variables['seen'], ValueType.setOf(ValueType.number));
      expect(back.blocks['n']!.literals['value'], -999999);
      expect(back.blocks['b']!.literals['value'], false);
      expect(graphText(back), graphText(graph));
    });

    test('14. L1: IS NOTHING / IS NOT NOTHING programs come back and run the same', () {
      for (final id in ['l1_list_probe', 'l1_tree_probe']) {
        final puzzle = shippedPuzzle('world_01', id);
        final graph = referenceSolution('world_01', id);
        final back = _roundTripGraph(graph);
        expect(graphText(back), graphText(graph));
        final catalogIds = back.blocks.values.map((b) => b.catalogId);
        expect(catalogIds, anyOf(contains(BlockIds.logicIsNotNothing), contains(BlockIds.logicIsNothing)));

        final before = runPuzzle(const DefaultEngine(), graph, puzzle).suite;
        final after = runPuzzle(const DefaultEngine(), back, puzzle).suite;
        expect(after.kind, ResultKind.correct, reason: id);
        expect(after.kind, before.kind);
        expect(after.metrics.ops, before.metrics.ops);
        expect(after.metrics.blocks, before.metrics.blocks);
        expect([for (final c in after.visible) c.actual], [for (final c in before.visible) c.actual]);
        expect(after.hiddenSummary!.passed, before.hiddenSummary!.passed);
      }
    });

    test('14b. the lowered program is identical after a save', () {
      final graph = referenceSolution('world_01', 'l1_list_probe');
      final puzzle = shippedPuzzle('world_01', 'l1_list_probe');
      final before = lower(graph, puzzle).program!.toJson();
      final after = lower(_roundTripGraph(graph), puzzle).program!.toJson();
      expect(jsonEncode(after), jsonEncode(before));
    });

    test('15. editor positions and folds are kept', () {
      final graph = BlockGraph.fromJson({
        'variables': {'nums': 'array<num>'},
        'entryIds': ['ret'],
        'blocks': {
          'ret': {..._block('ret', 'ctrl.return', slots: {'value': {'ref': 'len'}}), 'x': 12.5, 'y': 40, 'collapsed': true},
          'len': {..._block('len', 'arr.len'), 'x': -3, 'y': 7.25},
        },
      });
      final back = _roundTripGraph(graph);
      expect(back.blocks['ret']!.x, 12.5);
      expect(back.blocks['ret']!.y, 40);
      expect(back.blocks['ret']!.collapsed, isTrue);
      expect(back.blocks['len']!.x, -3);
      expect(back.blocks['len']!.y, 7.25);
    });
  });

  group('file store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('algorun_save_'));
    tearDown(() => dir.deleteSync(recursive: true));

    FileProgressStore store() => FileProgressStore(() async => dir);
    File saveFile() => File('${dir.path}${Platform.pathSeparator}${FileProgressStore.fileName}');

    test('writes one JSON file, atomically, and reads it back', () async {
      expect((await store().load()).save.puzzles, isEmpty);
      await store().save(_richSave());
      expect(saveFile().existsSync(), isTrue);
      expect(File('${saveFile().path}.tmp').existsSync(), isFalse);
      expect(saveFile().readAsStringSync(), encodeSave(_richSave()));
      final loaded = await store().load();
      expect(loaded.issues, isEmpty);
      expect(encodeSave(loaded.save), encodeSave(_richSave()));
      await store().save(PlayerSave.fresh);
      expect((await store().load()).save.puzzles, isEmpty);
    });

    test('an unreadable save is copied aside, never deleted', () async {
      saveFile().writeAsStringSync('{"saveVersion": 99}');
      final loaded = await store().load();
      expect(loaded.save.puzzles, isEmpty);
      expect(loaded.issues.single.path, 'saveVersion');
      final aside = dir.listSync().whereType<File>().where((f) => f.path.contains('.unreadable-')).toList();
      expect(aside, hasLength(1));
      expect(aside.single.readAsStringSync(), '{"saveVersion": 99}');
      expect(saveFile().readAsStringSync(), '{"saveVersion": 99}', reason: 'untouched until the next save');
    });

    test('clear removes the save', () async {
      await store().save(_richSave());
      await store().clear();
      expect(saveFile().existsSync(), isFalse);
      expect((await store().load()).save.puzzles, isEmpty);
    });
  });
}
