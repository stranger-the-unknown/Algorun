import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('catalog ids are unique and dotted', () {
    expect(BlockIds.all.length, greaterThan(50));
    expect(BlockIds.all.length, BlockIds.all.toSet().length);
    for (final id in BlockIds.all) {
      expect(id, contains('.'));
      expect(BlockIds.exists(id), isTrue);
    }
    expect(BlockIds.exists('not.a.block'), isFalse);
  });

  test('every catalog id has a port definition', () {
    for (final id in BlockIds.all) {
      final def = BlockCatalog.of(id);
      expect(def, isNotNull, reason: id);
      expect(def!.id, id);
      expect(def.ports, isNotEmpty, reason: id);
      final outputs = def.ports.where((p) => p.isOutput).length;
      expect(outputs, 1, reason: '$id should expose exactly one output plug');
    }
  });
}
