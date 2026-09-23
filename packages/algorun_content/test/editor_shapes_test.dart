import 'dart:convert';
import 'dart:io';

import 'package:algorun_content/algorun_content.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// MS13: a program saved by the app's own editor stores an ELSE as a
/// one-item list, while hand-written references use a ref. The replay
/// accepts both: they are the same program.
void main() {
  final puzzle = parsePuzzleJson(File('../../assets/puzzles/world_01/ms13_stress_probe.json').readAsStringSync());
  final reference = jsonDecode(File('../../content/references/world_01/ms13_stress_probe.json').readAsStringSync())
      as Map<String, Object?>;
  final graph = BlockGraph.fromJson(reference['solution']! as Map<String, Object?>);

  test('the stress probe was saved by the editor, with its ELSE as a list', () {
    final elses = [
      for (final b in graph.blocks.values)
        if (b.catalogId == BlockIds.ctrlIf && b.slots['else'] != null) b.slots['else'],
    ];
    expect(elses, hasLength(2));
    expect(elses, everyElement(isA<ListBinding>()));
  });

  test('it replays through the editor commands', () {
    expect(replayInEditor(graph, puzzle).map((i) => '${i.path}: ${i.message}'), isEmpty);
  });

  test('the same ELSE written as a ref replays too', () {
    final json = jsonDecode(jsonEncode(graph.toJson())) as Map<String, Object?>;
    final blocks = json['blocks']! as Map<String, Object?>;
    for (final block in blocks.values.cast<Map<String, Object?>>()) {
      final slots = block['slots'] as Map<String, Object?>?;
      final elseSlot = slots?['else'] as Map<String, Object?>?;
      if (elseSlot != null) slots!['else'] = {'ref': (elseSlot['list']! as List<Object?>).single};
    }
    expect(replayInEditor(BlockGraph.fromJson(json), puzzle), isEmpty);
  });
}
