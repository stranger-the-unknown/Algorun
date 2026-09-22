import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('add and remove block', () {
    final h = GraphHistory();
    final added = h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'if1'));
    expect(added.ok, isTrue);
    expect(h.current.blocks.containsKey('if1'), isTrue);
    expect(h.apply(RemoveBlockCommand('if1')).ok, isTrue);
    expect(h.current.blocks.containsKey('if1'), isFalse);
  });

  test('remove detaches references but keeps sibling blocks', () {
    final h = GraphHistory();
    h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'if1'));
    h.apply(AddBlockCommand(catalogId: BlockIds.litBool, id: 'b1'));
    h.apply(ConnectCommand(
      from: const PortRef('b1', 'out'),
      to: const PortRef('if1', 'condition'),
    ));
    h.apply(RemoveBlockCommand('if1'));
    expect(h.current.blocks.containsKey('if1'), isFalse);
    expect(h.current.blocks.containsKey('b1'), isTrue);
    expect(h.current.parentOf('b1'), isNull);
  });

  test('move only writes canvas metadata', () {
    final h = GraphHistory();
    h.apply(AddBlockCommand(catalogId: BlockIds.litNum, id: 'n', x: 0, y: 0));
    h.apply(MoveBlockCommand('n', x: 12, y: 40));
    expect(h.current.blocks['n']!.x, 12);
    expect(h.current.blocks['n']!.y, 40);
  });

  test('undo/redo restores graph identity', () {
    final h = GraphHistory();
    h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'if1'));
    h.apply(AddBlockCommand(catalogId: BlockIds.litBool, id: 'b1'));
    h.apply(ConnectCommand(
      from: const PortRef('b1', 'out'),
      to: const PortRef('if1', 'condition'),
    ));
    h.apply(AttachStatementCommand(
      blockId: _add(h, BlockIds.ctrlReturn, id: 'r1'),
      to: const PortRef('if1', 'then'),
    ));
    final connected = h.current;
    expect(connected.slotList('if1', 'condition'), ['b1']);
    expect(connected.slotList('if1', 'then'), ['r1']);

    h.undo(); // detach return
    expect(h.current.parentOf('r1'), isNull);
    h.undo(); // remove return
    h.undo(); // disconnect bool
    expect(h.current.parentOf('b1'), isNull);
    h.redo();
    expect(h.current.slotList('if1', 'condition'), ['b1']);
    h.undo();
    h.undo(); // remove bool
    h.undo(); // remove if
    expect(h.current.blocks, isEmpty);
    h.redo();
    expect(h.current.blocks.containsKey('if1'), isTrue);
  });

  test('failed command does not push undo', () {
    final h = GraphHistory();
    h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'if1'));
    h.apply(AddBlockCommand(catalogId: BlockIds.litNum, id: 'n1'));
    expect(h.canUndo, isTrue);
    final stacked = h.current;
    final denied = h.apply(ConnectCommand(
      from: const PortRef('n1', 'out'),
      to: const PortRef('if1', 'condition'),
    ));
    expect(denied.ok, isFalse);
    expect(h.current.blocks.keys, stacked.blocks.keys);
    h.undo();
    h.undo();
    expect(h.current.blocks, isEmpty);
  });

  test('top-level statement stack uses @main.body', () {
    final h = GraphHistory();
    h.apply(AddBlockCommand(catalogId: BlockIds.ctrlIf, id: 'if1'));
    expect(
      h.apply(AttachStatementCommand(
        blockId: 'if1',
        to: PortRef.mainBody,
      )).ok,
      isTrue,
    );
    expect(h.current.entryIds, ['if1']);
    h.apply(DetachStatementCommand('if1'));
    expect(h.current.entryIds, isEmpty);
    expect(h.current.blocks.containsKey('if1'), isTrue);
  });
}

String _add(GraphHistory h, String catalogId, {required String id}) {
  h.apply(AddBlockCommand(catalogId: catalogId, id: id));
  return id;
}
