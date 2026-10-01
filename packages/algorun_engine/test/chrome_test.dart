import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('every catalog id has a player-facing label without dots', () {
    for (final id in BlockIds.all) {
      final chrome = BlockChrome.of(id);
      expect(chrome.label, isNotEmpty, reason: id);
      expect(chrome.label, isNot(contains('.')), reason: id);
      expect(chrome.label, isNot(equals(id)), reason: id);
    }
  });

  test('FUNCTION comes from the puzzle, CALL from the palette (L2)', () {
    expect(BlockChrome.hiddenFromEditor(BlockIds.fnDef), isTrue);
    for (final call in BlockIds.calls) {
      expect(BlockChrome.hiddenFromEditor(call), isFalse);
    }
    expect(BlockChrome.hiddenFromEditor(BlockIds.ctrlIf), isFalse);
  });
}
