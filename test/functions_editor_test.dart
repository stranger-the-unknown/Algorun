import 'package:algorun/editor/editor_controller.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// L2 in the editor: the puzzle's FUNCTION is there from the start, stays
/// put, is not counted, and only offers what a function can see.
void main() {
  final campaign = shippedCampaign();
  final coins = campaign.puzzles['coin_stack']!;

  test('the FUNCTION is there when the puzzle opens and is not the player\'s to remove', () {
    final c = EditorController(puzzle: coins);
    expect(c.graph.entryIds, ['fn_sum_from']);
    expect(c.blockCount, 0);
    expect(c.graph.variables['stack'], ValueType.array(ValueType.number));
    c.selectBlock('fn_sum_from');
    final info = c.selection!;
    expect(info.label, 'FUNCTION sum_from');
    expect(info.canDelete, isFalse);
    expect(info.canDuplicate, isFalse);
    expect(info.moves, isEmpty);
    expect(c.deleteTree('fn_sum_from'), isFalse);
    expect(c.graph.blocks.containsKey('fn_sum_from'), isTrue);
  });

  test('clearing the program keeps the FUNCTION', () {
    final c = EditorController(puzzle: coins);
    c.place(const Placement(catalogId: BlockIds.ctrlReturn), to: PortRef.mainBody);
    c.replaceGraph(BlockGraph(blocks: const {}, variables: c.graph.variables));
    expect(c.graph.entryIds, ['fn_sum_from']);
  });

  test('inside the FUNCTION the picker offers its parameters and CALL, not the givens', () {
    final c = EditorController(puzzle: coins);
    final ret = c.place(const Placement(catalogId: BlockIds.ctrlReturn), to: const PortRef('fn_sum_from', 'body'))!;
    final call = c.place(const Placement(catalogId: BlockIds.fnCall2, literals: {'name': 'sum_from'}), to: PortRef(ret, 'value'))!;
    final names = [
      for (final p in c.placementsFor(PortRef(call, 'a1')))
        if (p.catalogId == BlockIds.varGet) p.literals['name'],
    ];
    expect(names, contains('stack'));
    expect(names, isNot(contains('coins')), reason: 'a given must be passed in');

    // In the main program the given is offered.
    final main = c.place(const Placement(catalogId: BlockIds.ctrlReturn), to: PortRef.mainBody)!;
    final top = c.place(const Placement(catalogId: BlockIds.fnCall2, literals: {'name': 'sum_from'}), to: PortRef(main, 'value'))!;
    expect(
      [for (final p in c.placementsFor(PortRef(top, 'a1'))) if (p.catalogId == BlockIds.varGet) p.literals['name']],
      contains('coins'),
    );
  });
}
