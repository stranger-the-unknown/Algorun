import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

/// MS13: the picker offers INCREMENT / DECREMENT once per variable the
/// connect rules accept — numbers only — exactly as it offers GET.
void main() {
  final graph = BlockGraph(blocks: const {}, variables: {
    'i': ValueType.number,
    'seen': ValueType.setOf(ValueType.number),
    'best': ValueType.number,
  });

  List<String?> named(String catalogId) => [
        for (final p in GraphTyping.compatiblePlacements(
          graph,
          to: PortRef.mainBody,
          allow: [catalogId],
        ))
          p.literals['name'] as String?,
      ];

  test('INCREMENT and DECREMENT are offered per number variable', () {
    expect(named(BlockIds.varInc), ['i', 'best']);
    expect(named(BlockIds.varDec), ['i', 'best']);
  });

  test('every offered placement connects', () {
    for (final p in GraphTyping.compatiblePlacements(
      graph,
      to: PortRef.mainBody,
      allow: [BlockIds.varInc, BlockIds.varDec],
    )) {
      final history = GraphHistory(graph);
      final add = AddBlockCommand(catalogId: p.catalogId, literals: p.literals);
      expect(history.apply(add).ok, isTrue);
      final connect = AttachStatementCommand(blockId: add.addedId!, to: PortRef.mainBody);
      expect(history.apply(connect).ok, isTrue, reason: '${p.catalogId} ${p.literals}');
    }
  });

  test('without a number variable nothing is offered', () {
    final none = BlockGraph(blocks: const {}, variables: {'seen': ValueType.setOf(ValueType.number)});
    expect(
      GraphTyping.compatiblePlacements(none, to: PortRef.mainBody, allow: [BlockIds.varInc]),
      isEmpty,
    );
  });
}
