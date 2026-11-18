// L3: what the game adds on top of the algorun-lang port — pairs as fixture
// input, `blocks.texts`, and the text <-> number blocks under the game's own
// number model (fractions exist; conversions stay inside 2^53 - 1 so the
// phone and the web agree).
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

Expr _lit(Object? value, ValueType type) => LitExpr(value, type: type);
Expr _n(num value) => _lit(value, ValueType.number);
Expr _s(String value) => _lit(value, ValueType.string);
Expr _call(String callee, List<Expr> args, [ValueType type = ValueType.number]) => CallExpr(callee, args, type: type);

RunResult _eval(Expr value, {Map<String, RuntimeValue> input = const {}, List<Param> params = const []}) => runProgram(
      Program(functions: [
        FnDecl(name: 'main', params: params, body: [ReturnStmt(value: value)]),
      ]),
      input,
      RunLimits.standard,
    );

Object? _out(Expr value) {
  final r = _eval(value);
  expect(r.kind, ResultKind.correct, reason: r.message);
  return valueToJson(r.output!);
}

String _puzzle({String blocks = '"allow": ["var.get", "lit.str"]', String input = 'num', String sample = '1'}) => '''
{ "id": "l3", "title": "L3", "world": "world_01", "tier": 1, "mode": "build", "story": "s",
  "io": { "inputs": [{ "name": "x", "type": "$input" }], "output": { "type": "num" } },
  "blocks": { $blocks }, "limits": { "maxOps": 1000 },
  "fixtures": { "visible": [{ "id": "v", "in": { "x": $sample }, "out": 1 }],
                "hidden": [{ "id": "h", "in": { "x": $sample }, "out": 1 }] } }''';

void main() {
  group('pair fixtures', () {
    final type = parseValueType('pair<str,num>');

    test('a pair has a fixture type and reads back what it writes', () {
      expect(fixtureTypeProblem(type), isNull);
      const json = {'type': 'pair', 'first': 'ada', 'second': 3};
      final value = valueFromJson(json, type: type);
      expect(value, isA<PairValue>());
      expect(((value as PairValue).first as StrValue).value, 'ada');
      expect(valueToJson(value), json);
    });

    test('both sides are typed and required', () {
      expect(() => valueFromJson({'type': 'pair', 'first': 3, 'second': 3}, type: type),
          throwsA(isA<FixtureFormatException>().having((e) => e.path, 'path', r'$.first')));
      expect(() => valueFromJson({'type': 'pair', 'first': 'a'}, type: type), throwsA(isA<FixtureFormatException>()));
      expect(() => valueFromJson({'type': 'pair', 'first': 'a', 'second': 1, 'third': 2}, type: type),
          throwsA(isA<FixtureFormatException>()));
    });

    test('a pair of something without a fixture form has none either', () {
      expect(fixtureTypeProblem(parseValueType('pair<num,heap<num>>')), isNotNull);
      expect(fixtureTypeProblem(parseValueType('array<pair<str,num>>')), isNull);
    });

    test('a puzzle can take a list of pairs, and the program reads them', () {
      final read = readPuzzleJson(_puzzle(
        input: 'array<pair<str,num>>',
        sample: '[{"type": "pair", "first": "ada", "second": 3}]',
      ));
      expect(read.issues, isEmpty, reason: '${read.issues}');
      final pairs = parseValueType('array<pair<str,num>>');
      final first = IndexExpr(VarExpr('x', type: pairs), _n(0), type: parseValueType('pair<str,num>'));
      final r = _eval(
        _call(BlockIds.pairSecond, [first]),
        input: read.puzzle!.visibleTests.single.input,
        params: [Param('x', pairs)],
      );
      expect(valueToJson(r.output!), 3);
    });

    test('expected pairs compare by value', () {
      final a = valueFromJson({'type': 'pair', 'first': 'a', 'second': 1});
      final b = valueFromJson({'type': 'pair', 'first': 'a', 'second': 1});
      final c = valueFromJson({'type': 'pair', 'first': 'a', 'second': 2});
      expect(valuesEqual(a, b), isTrue);
      expect(valuesEqual(a, c), isFalse);
    });
  });

  group('blocks.texts', () {
    test('lists the texts the TEXT block offers; the empty text comes first', () {
      final read = readPuzzleJson(_puzzle(blocks: '"allow": ["var.get", "lit.str"], "texts": [" ", "a", "yes"]'));
      expect(read.issues, isEmpty, reason: '${read.issues}');
      expect(read.puzzle!.blocks.texts, [' ', 'a', 'yes']);
      expect(read.puzzle!.blocks.textChoices, ['', ' ', 'a', 'yes']);
    });

    test('a puzzle without the field offers the empty text only', () {
      expect(readPuzzleJson(_puzzle()).puzzle!.blocks.textChoices, ['']);
    });

    for (final (name, texts, at) in [
      ('the empty text', '[""]', 'blocks.texts[0]'),
      ('a repeat', '["a", "a"]', 'blocks.texts[1]'),
      ('a number', '[1]', 'blocks.texts[0]'),
      ('a long text', '["${'x' * 25}"]', 'blocks.texts[0]'),
      ('too many', '[${[for (var i = 0; i < 25; i++) '"t$i"'].join(', ')}]', 'blocks.texts'),
    ]) {
      test('refuses $name', () {
        final read = readPuzzleJson(_puzzle(blocks: '"allow": ["var.get", "lit.str"], "texts": $texts'));
        expect(read.puzzle, isNull);
        expect(read.issues.map((i) => i.path), contains(at));
      });
    }

    test('needs the TEXT block in the palette', () {
      final read = readPuzzleJson(_puzzle(blocks: '"allow": ["var.get"], "texts": ["a"]'));
      expect(read.issues.map((i) => i.path), contains('blocks.texts'));
    });
  });

  group('text positions under the game number model', () {
    test('LETTER AT and PART OF TEXT need whole positions', () {
      final at = _eval(_call(BlockIds.strCharAt, [_s('abc'), _n(1.5)], ValueType.string));
      expect(at.kind, ResultKind.runtimeError);
      expect(at.message, 'A position has to be a whole number.');
      final part = _eval(_call(BlockIds.strSubstring, [_s('abc'), _n(0), _n(2.5)], ValueType.string));
      expect(part.message, 'A position has to be a whole number.');
    });

    test('a whole fraction is a position', () {
      expect(_out(_call(BlockIds.strCharAt, [_s('abc'), _n(2.0)], ValueType.string)), 'c');
    });

    test('positions outside the text are refused, the end cut is allowed', () {
      expect(_eval(_call(BlockIds.strCharAt, [_s('abc'), _n(3)], ValueType.string)).message,
          'That position is outside the text.');
      expect(_eval(_call(BlockIds.strCharAt, [_s(''), _n(0)], ValueType.string)).message,
          'That position is outside the text.');
      expect(_out(_call(BlockIds.strSubstring, [_s('abc'), _n(3), _n(3)], ValueType.string)), '');
      expect(_eval(_call(BlockIds.strSubstring, [_s('abc'), _n(2), _n(1)], ValueType.string)).message,
          'That position is outside the text.');
    });
  });

  group('NUMBER AS TEXT', () {
    Expr text(Expr n) => _call(BlockIds.strFromNum, [n], ValueType.string);

    test('writes whole numbers as digits', () {
      expect(_out(text(_n(0))), '0');
      expect(_out(text(_n(-12))), '-12');
      expect(_out(text(_n(9007199254740991))), '9007199254740991');
      expect(_out(text(_n(-9007199254740991))), '-9007199254740991');
    });

    test('a whole fraction prints without a decimal point, on every platform', () {
      // 7 / 2 * 2 is 7.0 on the phone and 7 in a browser; both must read "7".
      final seven = BinaryExpr(
        BinaryOp.mul,
        BinaryExpr(BinaryOp.div, _n(7), _n(2), type: ValueType.number),
        _n(2),
        type: ValueType.number,
      );
      expect(_out(text(seven)), '7');
      expect(_out(text(_n(-0.0))), '0');
    });

    test('a fraction has no digits to write', () {
      final r = _eval(text(_n(3.5)));
      expect(r.kind, ResultKind.runtimeError);
      expect(r.message, 'NUMBER AS TEXT needs a whole number.');
    });

    test('a number the web cannot hold exactly is too big', () {
      for (final n in [9007199254740992, -9007199254740992, 1e300]) {
        final r = _eval(text(_n(n)));
        expect(r.kind, ResultKind.runtimeError, reason: '$n');
        expect(r.message, 'This number is too big.');
      }
    });
  });

  group('TEXT AS NUMBER', () {
    Object? number(String s) => _out(_call(BlockIds.strToNum, [_s(s)], ValueType.number.asNullable));

    test('reads digits with an optional minus', () {
      expect(number('0'), 0);
      expect(number('42'), 42);
      expect(number('-42'), -42);
      expect(number('007'), 7);
      expect(number('-0'), 0);
      expect(number('9007199254740991'), 9007199254740991);
      expect(number('-9007199254740991'), -9007199254740991);
    });

    test('anything else is NOTHING', () {
      for (final s in ['', '-', '+1', '1.5', ' 1', '1 ', '1e3', 'abc', '--1', '٣']) {
        expect(number(s), isNull, reason: '"$s"');
      }
    });

    test('a number past 2^53 - 1 is NOTHING rather than a rounded value', () {
      for (final s in ['9007199254740992', '-9007199254740992', '9223372036854775807', '1${'0' * 40}']) {
        expect(number(s), isNull, reason: s);
      }
    });

    test('NUMBER AS TEXT and TEXT AS NUMBER undo each other', () {
      for (final n in [0, 1, -1, 10, 999999, -9007199254740991]) {
        final back = _call(BlockIds.strToNum, [
          _call(BlockIds.strFromNum, [_n(n)], ValueType.string),
        ]);
        expect(_out(back), n);
      }
    });
  });
}
