import 'dart:convert';
import 'dart:io';

import 'package:algorun/progress/campaign.dart';
import 'package:algorun/progress/save_codec.dart';
import 'package:algorun/progress/save_data.dart';
import 'package:algorun_engine/algorun_engine.dart';

/// A minimal valid puzzle: `return LENGTH OF nums`.
Puzzle tinyPuzzle(
  String id, {
  String world = 'world_01',
  List<String> prerequisites = const [],
  int version = 1,
}) =>
    parsePuzzleJson('''
{
  "id": "$id", "version": $version, "title": "${id.toUpperCase()}", "world": "$world", "tier": 1,
  "mode": "build", "story": "Count them.", "prerequisites": ${jsonEncode(prerequisites)},
  "io": { "inputs": [{ "name": "nums", "type": "array<num>" }], "output": { "type": "num" } },
  "blocks": { "allow": ["ctrl.return", "arr.len", "var.get"] },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "nums": [1, 2, 3] }, "out": 3 }],
    "hidden": [{ "id": "h1", "in": { "nums": [9] }, "out": 1 }]
  }
}
''');

/// A world for [tinyCampaign]: `(id, concepts, prerequisites, puzzles)`.
typedef TinyWorld = (String id, List<String> concepts, List<String> prerequisites, List<String> puzzles);

/// A campaign of tiny puzzles. [puzzlePrerequisites] adds a puzzle's own
/// prerequisites.
Campaign tinyCampaign(List<TinyWorld> worlds, {Map<String, List<String>> puzzlePrerequisites = const {}}) {
  final manifest = WorldsManifest([
    for (final (i, (id, concepts, prerequisites, puzzles)) in worlds.indexed)
      WorldDef(
        id: id,
        title: 'World ${i + 1}',
        index: i + 1,
        puzzleIds: puzzles,
        concepts: concepts,
        prerequisites: prerequisites,
      ),
  ]);
  return Campaign(manifest, {
    for (final (world, _, _, puzzles) in worlds)
      for (final id in puzzles) id: tinyPuzzle(id, world: world, prerequisites: puzzlePrerequisites[id] ?? const []),
  });
}

/// A suite result with just the numbers the ledger reads.
SuiteResult suite(
  ResultKind kind, {
  int ops = 10,
  int peakAlloc = 0,
  int peakDepth = 1,
  int blocks = 3,
  int hintsUsed = 0,
}) =>
    SuiteResult(
      kind: kind,
      visible: const [],
      metrics: RunMetrics(ops: ops, peakAlloc: peakAlloc, peakDepth: peakDepth, blocks: blocks, hintsUsed: hintsUsed),
    );

/// `return LENGTH OF nums`, with a distinguishing literal-free shape.
BlockGraph lengthGraph({String retId = 'ret'}) => BlockGraph.fromJson({
      'variables': {'nums': 'array<num>'},
      'entryIds': [retId],
      'blocks': {
        retId: {'id': retId, 'catalogId': 'ctrl.return', 'slots': {'value': {'ref': 'len'}}},
        'len': {'id': 'len', 'catalogId': 'arr.len', 'slots': {'array': {'ref': 'nums'}}},
        'nums': {'id': 'nums', 'catalogId': 'var.get', 'literals': {'name': 'nums'}},
      },
    });

Map<String, Object?> referenceFile(String world, String id) =>
    jsonDecode(File('content/references/$world/$id.json').readAsStringSync()) as Map<String, Object?>;

BlockGraph referenceSolution(String world, String id) =>
    BlockGraph.fromJson(referenceFile(world, id)['solution']! as Map<String, Object?>);

BlockGraph referenceReject(String world, String id, String name) {
  final rejects = (referenceFile(world, id)['rejects']! as List<Object?>).cast<Map<String, Object?>>();
  return BlockGraph.fromJson(rejects.singleWhere((r) => r['name'] == name)['graph']! as Map<String, Object?>);
}

/// A save as its stored text and back: what an app restart sees.
PlayerSave reloaded(PlayerSave save) => decodeSave(encodeSave(save)).save;

/// A graph's JSON with sorted keys, for comparing programs.
String graphText(BlockGraph graph) => jsonEncode(_sorted(graph.toJson()));

Object? _sorted(Object? value) => switch (value) {
      final Map<Object?, Object?> map => {
          for (final key in map.keys.map((k) => '$k').toList()..sort()) key: _sorted(map[key]),
        },
      final List<Object?> list => [for (final item in list) _sorted(item)],
      _ => value,
    };
