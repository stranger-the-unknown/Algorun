import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('JSON round trip preserves slots, literals, positions, variables', () {
    final original = BlockGraph(
      variables: {'nums': ValueType.array(ValueType.number)},
      entryIds: ['if1'],
      blocks: {
        'if1': BlockInstance(
          id: 'if1',
          catalogId: BlockIds.ctrlIf,
          x: 8,
          y: 16,
          slots: {
            'condition': RefBinding('b1'),
            'then': ListBinding(['r1']),
          },
        ),
        'b1': BlockInstance(
          id: 'b1',
          catalogId: BlockIds.litBool,
          literals: {'value': true},
        ),
        'r1': BlockInstance(
          id: 'r1',
          catalogId: BlockIds.ctrlReturn,
        ),
      },
    );
    final json = original.toJsonString();
    final restored = BlockGraph.fromJsonString(json);
    expect(restored.entryIds, original.entryIds);
    expect(restored.variables, original.variables);
    expect(restored.blocks['if1']!.x, 8);
    expect(restored.blocks['if1']!.y, 16);
    expect(
      (restored.blocks['if1']!.slots['condition'] as RefBinding).blockId,
      'b1',
    );
    expect(
      (restored.blocks['if1']!.slots['then'] as ListBinding).blockIds,
      ['r1'],
    );
    expect(restored.blocks['b1']!.literals['value'], true);
    expect(restored.toJsonString(), json);
  });

  test('malformed JSON is rejected', () {
    expect(() => BlockGraph.fromJsonString('[]'), throwsFormatException);
    expect(
      () => BlockGraph.fromJsonString('{"blocks":{"a":{"id":"a","catalogId":"nope"}}}'),
      throwsFormatException,
    );
    expect(
      () => BlockGraph.fromJsonString('{"blocks":{"a":{"catalogId":"ctrl.if"}}}'),
      throwsFormatException,
    );
  });

  test('malformed graph is rejected by structure checks', () {
    const missing = BlockGraph(
      blocks: {
        'if1': BlockInstance(
          id: 'if1',
          catalogId: BlockIds.ctrlIf,
          slots: {'condition': RefBinding('ghost')},
        ),
      },
    );
    expect(
      GraphStructure.validate(missing).messages.any((m) => m.code == 'missing_block'),
      isTrue,
    );

    const exprInStack = BlockGraph(
      entryIds: ['n1'],
      blocks: {
        'n1': BlockInstance(id: 'n1', catalogId: BlockIds.litNum),
      },
    );
    expect(
      GraphStructure.validate(exprInStack).messages.any((m) => m.code == 'wrong_kind'),
      isTrue,
    );

    const twoParents = BlockGraph(
      blocks: {
        'if1': BlockInstance(
          id: 'if1',
          catalogId: BlockIds.ctrlIf,
          slots: {'condition': RefBinding('b1')},
        ),
        'w1': BlockInstance(
          id: 'w1',
          catalogId: BlockIds.ctrlWhile,
          slots: {'condition': RefBinding('b1')},
        ),
        'b1': BlockInstance(id: 'b1', catalogId: BlockIds.litBool),
      },
    );
    expect(
      GraphStructure.validate(twoParents).messages.any((m) => m.code == 'two_parents'),
      isTrue,
    );
  });

  test('unknown slot name is malformed', () {
    const g = BlockGraph(
      blocks: {
        'if1': BlockInstance(
          id: 'if1',
          catalogId: BlockIds.ctrlIf,
          slots: {'banana': RefBinding('b1')},
        ),
        'b1': BlockInstance(id: 'b1', catalogId: BlockIds.litBool),
      },
    );
    expect(
      GraphStructure.validate(g).messages.any((m) => m.code == 'unknown_port'),
      isTrue,
    );
  });
}
