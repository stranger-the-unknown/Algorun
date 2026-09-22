import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ValueType.accepts', () {
    test('num hole accepts num, not bool', () {
      expect(ValueType.number.accepts(ValueType.number), isTrue);
      expect(ValueType.number.accepts(ValueType.boolean), isFalse);
    });

    test('bool hole rejects num (no truthiness)', () {
      expect(ValueType.boolean.accepts(ValueType.number), isFalse);
    });

    test('nullable accepts null and T', () {
      final n = ValueType.number.asNullable;
      expect(n.accepts(ValueType.nil), isTrue);
      expect(n.accepts(ValueType.number), isTrue);
      expect(ValueType.number.accepts(ValueType.nil), isFalse);
    });

    test('non-nullable hole rejects nullable incoming', () {
      expect(ValueType.boolean.accepts(ValueType.boolean.asNullable), isFalse);
    });

    test('array<num> rejects array<bool>', () {
      final nums = ValueType.array(ValueType.number);
      final bools = ValueType.array(ValueType.boolean);
      expect(nums.accepts(nums), isTrue);
      expect(nums.accepts(bools), isFalse);
    });

    test('map<str,num> requires both params', () {
      final a = ValueType.mapOf(ValueType.string, ValueType.number);
      final b = ValueType.mapOf(ValueType.number, ValueType.number);
      expect(a.accepts(a), isTrue);
      expect(a.accepts(b), isFalse);
    });
  });

  group('parseValueType', () {
    test('parses atoms and generics', () {
      expect(parseValueType('num'), ValueType.number);
      expect(parseValueType('bool?'), ValueType.boolean.asNullable);
      expect(parseValueType('array<num>'), ValueType.array(ValueType.number));
      expect(
        parseValueType('map<str,num>'),
        ValueType.mapOf(ValueType.string, ValueType.number),
      );
      expect(
        parseValueType('listNode?'),
        ValueType.listNode.asNullable,
      );
    });
  });
}
