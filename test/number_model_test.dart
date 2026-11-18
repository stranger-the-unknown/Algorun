import 'dart:convert';
import 'dart:io';

import 'package:algorun/guide/guide_data.dart';
import 'package:algorun/l10n/engine_text.dart';
import 'package:algorun/l10n/l10n.dart';
import 'package:algorun/state/run_puzzle.dart';
import 'package:algorun_engine/algorun_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_files.dart';

/// L3 "safe whole numbers" as the player meets them: what the block
/// reference says about DIVIDE, the sentences in both languages, and the one
/// puzzle that offers DIVIDE. The model itself is tested in the engine
/// (packages/algorun_engine/test/whole_number_test.dart).
void main() {
  final en = stringsFor('en');
  final tr = stringsFor('tr');

  test('the block reference describes DIVIDE as it works now, in both languages', () {
    final divide = blockGuide[BlockIds.arithDiv]!;
    expect(divide.en, contains('7 DIVIDE 2 is 3,'));
    expect(divide.en, contains('-7 DIVIDE 2 is -3'));
    expect(divide.en, isNot(contains('3.5')));
    expect(divide.trText, contains('7 DIVIDE 2 sonucu 3,'));
    expect(divide.trText, contains('-7 DIVIDE 2 sonucu -3'));
    expect(divide.trText, isNot(contains('3.5')));
    final floor = blockGuide[BlockIds.arithFloorDiv]!;
    expect(floor.en, contains('-7 FLOOR DIVIDE 2 is -4'));
    expect(floor.trText, contains('-7 FLOOR DIVIDE 2 sonucu -4'));
  });

  test('the concepts explain that numbers are whole and have a largest one', () {
    final number = conceptGuide.singleWhere((c) => c.term == 'Number');
    expect(number.tr, 'Sayı');
    expect(number.en, contains('9,007,199,254,740,991'));
    expect(number.en, contains('This number is too big.'));
    expect(number.trText, contains('9.007.199.254.740.991'));
    expect(number.trText, contains(engineText('This number is too big.', tr)));
    // Appended, so the positions other tests and screens use do not move.
    expect(conceptGuide.last, same(number));
  });

  test('the number sentences have Turkish; the ones that cannot happen any more are gone', () {
    for (final sentence in [
      'This number is too big.',
      'Only whole numbers can be used.',
      'This program only works with whole numbers.',
    ]) {
      expect(engineText(sentence, en), sentence);
      expect(engineText(sentence, tr), isNot(sentence), reason: sentence);
    }
    expect(engineText('This number is too big.', tr), 'Bu sayı çok büyük.');
    expect(engineText('Only whole numbers can be used.', tr), 'Yalnızca tam sayılar kullanılabilir.');
    final engine = [
      for (final f in Directory('packages/algorun_engine/lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart')) f.readAsStringSync(),
    ].join();
    expect(engine, isNot(contains('A position has to be a whole number.')));
    expect(engine, isNot(contains('NUMBER AS TEXT needs a whole number.')));
  });

  test('The Smallest Cart: a DIVIDE midpoint now solves it, at the same cost; nothing in the puzzle changed', () {
    final puzzle = shippedPuzzle('world_02', 'smallest_cart');
    expect(puzzle.blocks.allow, contains(BlockIds.arithDiv));
    final reference =
        jsonDecode(File('content/references/world_02/smallest_cart.json').readAsStringSync()) as Map<String, Object?>;
    final solution = BlockGraph.fromJson(Map<String, dynamic>.from(reference['solution']! as Map));
    final withDivide = solution.copyWith(blocks: {
      for (final e in solution.blocks.entries)
        e.key: e.value.catalogId == BlockIds.arithFloorDiv
            ? BlockInstance(id: e.value.id, catalogId: BlockIds.arithDiv, slots: e.value.slots)
            : e.value,
    });
    const engine = DefaultEngine();
    final asShipped = runPuzzle(engine, solution, puzzle).suite;
    final divided = runPuzzle(engine, withDivide, puzzle).suite;
    expect(asShipped.kind, ResultKind.correct);
    expect(divided.kind, ResultKind.correct);
    expect(divided.metrics.ops, asShipped.metrics.ops);
    expect((reference['metrics']! as Map)['ops'], asShipped.metrics.ops, reason: 'the recorded cost did not move');
  });
}
