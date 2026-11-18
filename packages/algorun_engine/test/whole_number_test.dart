// L3 "safe whole numbers": a number is a whole number inside +-(2^53 - 1);
// there are no fractions; DIVIDE truncates; a result outside the range is
// "This number is too big." on every platform. This file uses no dart:io, so
// it also runs compiled to JavaScript and to Wasm:
//
//   dart test test/whole_number_test.dart
//   dart test -p node test/whole_number_test.dart
//   dart test -p node -c dart2wasm test/whole_number_test.dart
import 'package:algorun_engine/algorun_engine.dart';
import 'package:test/test.dart';

const _max = maxSafeNumber;

Expr _n(num value) => LitExpr(value, type: ValueType.number);
Expr _x() => VarExpr('x', type: ValueType.number);
Expr _y() => VarExpr('y', type: ValueType.number);
Expr _bin(BinaryOp op, Expr a, Expr b) => BinaryExpr(op, a, b, type: ValueType.number);
Expr _un(UnaryOp op, Expr a) => UnaryExpr(op, a, type: ValueType.number);

RunResult _run(List<Stmt> body, {num x = 0, num y = 0, RunLimits limits = RunLimits.standard}) => runProgram(
      Program(functions: [
        FnDecl(name: 'main', params: const [Param('x', ValueType.number), Param('y', ValueType.number)], body: body),
      ]),
      {'x': NumValue(x), 'y': NumValue(y)},
      limits,
    );

/// The value of `x op y`, or the error message.
Object _calc(BinaryOp op, num x, num y) {
  final r = _run([ReturnStmt(value: _bin(op, _x(), _y()))], x: x, y: y);
  if (r.kind != ResultKind.correct) return '${r.kind.name}: ${r.message}';
  final value = (r.output as NumValue).value;
  expect(value, isA<int>(), reason: '$x ${op.name} $y');
  expect(value == 0 && value.isNegative, isFalse, reason: '$x ${op.name} $y gave a negative zero');
  return value;
}

const _tooBig = 'runtimeError: This number is too big.';

void main() {
  test('the range is +-(2^53 - 1)', () {
    expect(maxSafeNumber, 9007199254740991);
    expect(numberProblem(_max), isNull);
    expect(numberProblem(-_max), isNull);
    expect(numberProblem(_max + 1), NumberProblem.tooBig);
    expect(numberProblem(0.5), NumberProblem.fraction);
    expect(numberProblem(double.infinity), NumberProblem.tooBig);
    expect(numberProblem(double.nan), NumberProblem.tooBig);
    expect(wholeNumber(2.0), isA<int>());
    expect(wholeNumber(-0.0).isNegative, isFalse);
  });

  group('PLUS and MINUS', () {
    test('are exact up to the edge and an error past it', () {
      expect(_calc(BinaryOp.add, _max - 1, 1), _max);
      expect(_calc(BinaryOp.add, _max, 0), _max);
      expect(_calc(BinaryOp.add, _max, 1), _tooBig);
      expect(_calc(BinaryOp.add, _max, _max), _tooBig);
      expect(_calc(BinaryOp.add, -_max, -1), _tooBig);
      expect(_calc(BinaryOp.add, _max, -_max), 0);
      expect(_calc(BinaryOp.sub, -_max, 1), _tooBig);
      expect(_calc(BinaryOp.sub, -_max + 1, 1), -_max);
      expect(_calc(BinaryOp.sub, _max, -1), _tooBig);
      expect(_calc(BinaryOp.sub, 5, 5), 0);
    });
  });

  group('TIMES', () {
    test('is exact up to the edge', () {
      expect(_calc(BinaryOp.mul, 94906265, 94906265), 9007199136250225);
      expect(_calc(BinaryOp.mul, 3, 3002399751580330), 9007199254740990);
      expect(_calc(BinaryOp.mul, -1, _max), -_max);
      expect(_calc(BinaryOp.mul, _max, 1), _max);
    });

    test('is an error past it, also where 64 bits would wrap back into the range', () {
      expect(_calc(BinaryOp.mul, 94906266, 94906266), _tooBig);
      expect(_calc(BinaryOp.mul, _max, 2), _tooBig);
      // 2^32 * 2^32 wraps to 0 on the phone; 3037000500^2 wraps negative.
      expect(_calc(BinaryOp.mul, 4294967296, 4294967296), _tooBig);
      expect(_calc(BinaryOp.mul, 3037000500, 3037000500), _tooBig);
      expect(_calc(BinaryOp.mul, _max, _max), _tooBig);
      expect(_calc(BinaryOp.mul, -_max, _max), _tooBig);
    });

    test('zero has no sign', () {
      expect(_calc(BinaryOp.mul, 0, -3), 0);
      expect(_calc(BinaryOp.mul, -3, 0), 0);
    });
  });

  group('DIVIDE, FLOOR DIVIDE and REMAINDER', () {
    test('DIVIDE truncates toward zero', () {
      expect(_calc(BinaryOp.div, 7, 2), 3);
      expect(_calc(BinaryOp.div, -7, 2), -3);
      expect(_calc(BinaryOp.div, 7, -2), -3);
      expect(_calc(BinaryOp.div, -7, -2), 3);
      expect(_calc(BinaryOp.div, 1, 5), 0);
      expect(_calc(BinaryOp.div, -1, 5), 0);
      expect(_calc(BinaryOp.div, _max, 1), _max);
      expect(_calc(BinaryOp.div, _max, -1), -_max);
      expect(_calc(BinaryOp.div, _max, 2), 4503599627370495);
      expect(_calc(BinaryOp.div, _max, _max - 1), 1);
    });

    test('FLOOR DIVIDE rounds down', () {
      expect(_calc(BinaryOp.floorDiv, 7, 2), 3);
      expect(_calc(BinaryOp.floorDiv, -7, 2), -4);
      expect(_calc(BinaryOp.floorDiv, 7, -2), -4);
      expect(_calc(BinaryOp.floorDiv, -7, -2), 3);
      expect(_calc(BinaryOp.floorDiv, -1, 5), -1);
      expect(_calc(BinaryOp.floorDiv, -_max, 2), -4503599627370496);
      expect(_calc(BinaryOp.floorDiv, 6, 3), 2);
    });

    test('REMAINDER is never negative', () {
      expect(_calc(BinaryOp.mod, 7, 3), 1);
      expect(_calc(BinaryOp.mod, -7, 3), 2);
      expect(_calc(BinaryOp.mod, 7, -3), 1);
      expect(_calc(BinaryOp.mod, -7, -3), 2);
      expect(_calc(BinaryOp.mod, -6, 3), 0);
      expect(_calc(BinaryOp.mod, _max, 10), 1);
    });

    test('dividing by zero is still its own error', () {
      for (final op in [BinaryOp.div, BinaryOp.floorDiv, BinaryOp.mod]) {
        expect(_calc(op, 5, 0), 'runtimeError: You cannot divide by zero.');
      }
    });
  });

  test('MIN, MAX, NEGATE and ABSOLUTE stay inside the range', () {
    expect(_calc(BinaryOp.min, -_max, _max), -_max);
    expect(_calc(BinaryOp.max, -_max, _max), _max);
    Object unary(UnaryOp op, num x) {
      final r = _run([ReturnStmt(value: _un(op, _x()))], x: x);
      final value = (r.output as NumValue).value;
      expect(value, isA<int>());
      expect(value == 0 && value.isNegative, isFalse);
      return value;
    }

    expect(unary(UnaryOp.neg, _max), -_max);
    expect(unary(UnaryOp.neg, 0), 0);
    expect(unary(UnaryOp.abs, -_max), _max);
    expect(unary(UnaryOp.abs, 0), 0);
  });

  group('INCREMENT, DECREMENT and FOR', () {
    test('INCREMENT past the edge is too big', () {
      final r = _run([IncStmt(VarLValue('x')), ReturnStmt(value: _x())], x: _max);
      expect(r.kind, ResultKind.runtimeError);
      expect(r.message, 'This number is too big.');
      final ok = _run([IncStmt(VarLValue('x')), ReturnStmt(value: _x())], x: _max - 1);
      expect((ok.output as NumValue).value, _max);
      final down = _run([DecStmt(VarLValue('x')), ReturnStmt(value: _x())], x: -_max);
      expect(down.message, 'This number is too big.');
    });

    test('a FOR counter that steps past the edge is too big', () {
      final r = _run([
        ForRangeStmt(loopVar: 'i', start: _x(), end: _n(_max), step: _n(2), body: const []),
        ReturnStmt(value: _n(1)),
      ], x: _max - 3);
      // _max - 3, _max - 1, then _max + 1 does not exist.
      expect(r.kind, ResultKind.runtimeError);
      expect(r.message, 'This number is too big.');
    });
  });

  group('numbers on their way in', () {
    test('a fractional literal is refused, a whole 2.0 is 2', () {
      final r = _run([ReturnStmt(value: _n(2.5))]);
      expect(r.kind, ResultKind.invalidProgram);
      expect(r.message, 'Only whole numbers can be used.');
      final two = _run([ReturnStmt(value: _n(2.0))]);
      expect((two.output as NumValue).value, isA<int>());
      expect(valueToJson(two.output!), 2);
    });

    test('a literal outside the range is too big', () {
      final r = _run([ReturnStmt(value: _n(_max + 1))]);
      expect(r.kind, ResultKind.runtimeError);
      expect(r.message, 'This number is too big.');
    });

    test('a fractional input is refused before anything runs', () {
      final r = _run([ReturnStmt(value: _x())], x: 3.5);
      expect(r.kind, ResultKind.invalidProgram);
      expect(r.message, 'This program only works with whole numbers.');
      expect(r.metrics.ops, 0);
    });

    test('a fraction inside a list, a node, a map key or a graph is refused too', () {
      final inputs = <RuntimeValue>[
        ArrayValue([const NumValue(1), const NumValue(0.5)], elementType: ValueType.number),
        ListNodeValue(1.5),
        TreeNodeValue(2.5),
        MapValue({0.5: const NumValue(1)}, keyType: ValueType.number, valueType: ValueType.number),
        GraphValue({
          0: [0.5],
          0.5: [],
        }),
      ];
      for (final input in inputs) {
        final r = runProgram(
          Program(functions: [
            FnDecl(name: 'main', params: [Param('x', input.type)], body: [ReturnStmt(value: _n(1))]),
          ]),
          {'x': input},
          RunLimits.standard,
        );
        expect(r.kind, ResultKind.invalidProgram, reason: '${input.runtimeType}');
        expect(r.message, 'This program only works with whole numbers.');
      }
    });

    test('a whole 3.0 input is the number 3', () {
      final r = _run([ReturnStmt(value: _bin(BinaryOp.add, _x(), _n(1)))], x: 3.0);
      expect((r.output as NumValue).value, isA<int>());
      expect(valueToJson(r.output!), 4);
    });
  });

  test('a long calculation: the same digest on the phone, in JavaScript and in Wasm', () {
    // 400 values around every edge, every pair through every operator.
    final seeds = <int>[
      0, 1, -1, 2, -2, 3, 7, -7, 10, 94906265, 94906266, 94906267, -94906266, 4503599627370496, //
      _max - 1, _max, -_max, -_max + 1, 3037000499, 3037000500, 2147483647, 2147483648, -2147483648, 4294967296,
      1000000007, 999999937,
    ];
    var x = 12345;
    for (var i = 0; i < 80; i++) {
      x = (x * 48271) % 2147483647;
      final hi = x;
      x = (x * 48271) % 2147483647;
      seeds.add((hi % 4194303) * 2147483648 + x - (i.isEven ? 0 : _max));
    }
    var digest = 0;
    var tooBig = 0;
    for (final a in seeds) {
      for (final b in seeds) {
        for (final op in [BinaryOp.add, BinaryOp.sub, BinaryOp.mul, BinaryOp.div, BinaryOp.floorDiv, BinaryOp.mod]) {
          final text = '${_calc(op, a, b)}';
          if (text == _tooBig) tooBig++;
          for (final unit in text.codeUnits) {
            digest = (digest * 31 + unit) % 1000000007;
          }
        }
      }
    }
    // Pinned from the Dart VM; dart2js and dart2wasm must print the same.
    expect('$tooBig $digest', _digest);
  });
}

const _digest = '14962 969037989';
