import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Placement goes through [EditorController.place], the same command the
/// screen uses. The assertion is the [BlockGraph], not a widget position.
Puzzle _puzzle() => parsePuzzleJson(r'''
{
  "id": "sibling_if_editor",
  "title": "Sibling IF",
  "world": "world_01",
  "tier": 1,
  "mode": "build",
  "story": "Two IFs on the main list.",
  "io": {
    "inputs": [{ "name": "x", "type": "num" }],
    "output": { "type": "num" }
  },
  "blocks": { "allow": ["ctrl.if", "var.set", "lit.num", "lit.bool"], "maxBlocks": 20 },
  "limits": { "maxOps": 1000 },
  "fixtures": {
    "visible": [{ "id": "v1", "in": { "x": 1 }, "out": 1 }],
    "hidden": [{ "id": "h1", "in": { "x": 1 }, "out": 1 }]
  }
}
''');

void main() {
  test('placing a second IF on the main list keeps it a sibling', () {
    final c = EditorController(puzzle: _puzzle());
    final first = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;
    final second = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;

    expect(c.graph.entryIds, [first, second]);
    expect(c.graph.slotList(first, 'then'), isEmpty);
    final parent = c.graph.parentOf(second);
    expect(parent?.blockId, BlockGraph.mainId);
    expect(parent?.port, 'body');
    expect(parent?.index, 1);
  });

  test('moving the later IF along the main list does not put it in THEN', () {
    final c = EditorController(puzzle: _puzzle());
    final first = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;
    final second = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;
    final third = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;

    c.selectBlock(second);
    expect(c.selection!.moves, contains(MoveDirection.down));
    expect(c.moveSelected(MoveDirection.down), isTrue);

    expect(c.graph.entryIds, [first, third, second]);
    expect(c.graph.slotList(first, 'then'), isEmpty);
    expect(c.graph.slotList(third, 'then'), isEmpty);
    expect(c.graph.parentOf(second)?.blockId, BlockGraph.mainId);
  });

  test('an IF placed into THEN is nested, and that graph is not the sibling graph', () {
    final c = EditorController(puzzle: _puzzle());
    final first = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef.mainBody)!;
    final nested = c.place(const Placement(catalogId: BlockIds.ctrlIf), to: PortRef(first, 'then'))!;

    expect(c.graph.entryIds, [first]);
    expect(c.graph.slotList(first, 'then'), [nested]);
    expect(c.graph.parentOf(nested)?.blockId, first);
  });
}
