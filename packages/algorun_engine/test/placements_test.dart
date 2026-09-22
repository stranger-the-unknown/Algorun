import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('IF condition does not offer NUMBER', () {
    final graph = _withIf();
    final places = GraphTyping.compatiblePlacements(
      graph,
      to: const PortRef('if1', 'condition'),
      allow: [
        BlockIds.litNum,
        BlockIds.litBool,
        BlockIds.cmpGt,
        BlockIds.cmpEq,
        BlockIds.logicAnd,
        BlockIds.arrGet,
        BlockIds.varGet,
      ],
    );
    final ids = places.map((p) => p.catalogId).toSet();
    expect(ids, isNot(contains(BlockIds.litNum)));
    expect(ids, contains(BlockIds.cmpGt));
    expect(ids, contains(BlockIds.litBool));
    expect(ids, contains(BlockIds.logicAnd));
  });

  test('numeric operand does not offer BOOL producer', () {
    final h = GraphHistory(const BlockGraph(blocks: {}));
    h.apply(AddBlockCommand(catalogId: BlockIds.arrGet, id: 'g1'));
    final places = GraphTyping.compatiblePlacements(
      h.current,
      to: const PortRef('g1', 'index'),
      allow: [
        BlockIds.litNum,
        BlockIds.litBool,
        BlockIds.cmpGt,
        BlockIds.logicAnd,
        BlockIds.varGet,
        BlockIds.arrLen,
      ],
    );
    final ids = places.map((p) => p.catalogId).toSet();
    expect(ids, contains(BlockIds.litNum));
    expect(ids, contains(BlockIds.arrLen));
    expect(ids, isNot(contains(BlockIds.litBool)));
    expect(ids, isNot(contains(BlockIds.cmpGt)));
    expect(ids, isNot(contains(BlockIds.logicAnd)));
  });

  test('ELSE only fits the IF else port', () {
    final graph = _withIf();
    final elseOnElse = GraphTyping.compatiblePlacements(
      graph,
      to: const PortRef('if1', 'else'),
      allow: [BlockIds.ctrlElse, BlockIds.ctrlReturn, BlockIds.varSet],
    );
    expect(
      elseOnElse.map((p) => p.catalogId),
      contains(BlockIds.ctrlElse),
    );
    expect(
      elseOnElse.map((p) => p.catalogId),
      isNot(contains(BlockIds.ctrlReturn)),
    );

    final elseOnThen = GraphTyping.compatiblePlacements(
      graph,
      to: const PortRef('if1', 'then'),
      allow: [BlockIds.ctrlElse, BlockIds.ctrlReturn],
    );
    expect(
      elseOnThen.map((p) => p.catalogId),
      isNot(contains(BlockIds.ctrlElse)),
    );
    expect(
      elseOnThen.map((p) => p.catalogId),
      contains(BlockIds.ctrlReturn),
    );

    final elseOnMain = GraphTyping.compatiblePlacements(
      graph,
      to: PortRef.mainBody,
      allow: [BlockIds.ctrlElse, BlockIds.ctrlIf],
    );
    expect(
      elseOnMain.map((p) => p.catalogId),
      isNot(contains(BlockIds.ctrlElse)),
    );
  });

  test('array<num> does not fit an array<bool> hole', () {
    final h = GraphHistory(
      BlockGraph(
        blocks: const {},
        variables: {
          'nums': ValueType.array(ValueType.number),
          'flags': ValueType.array(ValueType.boolean),
        },
      ),
    );
    h.apply(AddBlockCommand(catalogId: BlockIds.arrAppend, id: 'app'));
    h.apply(AddBlockCommand(catalogId: BlockIds.litBool, id: 'b'));
    h.apply(ConnectCommand(
      from: const PortRef('b', 'out'),
      to: const PortRef('app', 'value'),
    ));
    final places = GraphTyping.compatiblePlacements(
      h.current,
      to: const PortRef('app', 'array'),
      allow: [BlockIds.varGet],
    );
    final names = [
      for (final p in places)
        if (p.catalogId == BlockIds.varGet) p.literals['name'],
    ];
    expect(names, contains('flags'));
    expect(names, isNot(contains('nums')));
  });

  test('variable picker only shows typed-compatible names', () {
    final h = GraphHistory(
      BlockGraph(
        blocks: const {},
        variables: {
          'i': ValueType.number,
          'flag': ValueType.boolean,
          'nums': ValueType.array(ValueType.number),
        },
      ),
    );
    h.apply(AddBlockCommand(catalogId: BlockIds.arrGet, id: 'g1'));
    final places = GraphTyping.compatiblePlacements(
      h.current,
      to: const PortRef('g1', 'index'),
      allow: [BlockIds.varGet, BlockIds.litNum],
    );
    final getNames = [
      for (final p in places)
        if (p.catalogId == BlockIds.varGet) p.literals['name'],
    ];
    expect(getNames, ['i']);
  });
}

BlockGraph _withIf() {
  return const BlockGraph(
    blocks: {
      'if1': BlockInstance(id: 'if1', catalogId: BlockIds.ctrlIf),
    },
    entryIds: ['if1'],
  );
}
