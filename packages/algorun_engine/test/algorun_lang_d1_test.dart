// algorun-lang only (not in the game): deviation D1, see docs/spec.md §12.
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  test('generic type names parse, so IR JSON round-trips', () {
    expect(parseValueType('K'), ValueType.k);
    expect(parseValueType('T?').nullable, isTrue);
    expect(parseValueType('map<K,V>').param, ValueType.k);
  });
  test('unknown lower-case names are still rejected', () {
    expect(() => parseValueType('foo'), throwsFormatException);
  });
}
