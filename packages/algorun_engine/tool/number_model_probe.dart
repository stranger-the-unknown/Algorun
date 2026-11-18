// L3 measurement, not part of the game: the prototype of "safe whole numbers"
// (docs/MILESTONE_L3_PLAN.md, option C) that the owner's decision was based
// on. The engine now has this model (lib/src/runtime/whole_number.dart, the
// interpreter's _safe / _mul / _unsigned0); test/whole_number_test.dart pins
// the real thing. Run the prototype on the three targets the game has and
// compare the digest line:
//
//   dart compile exe tool/number_model_probe.dart -o /tmp/probe && /tmp/probe
//   dart compile js -O2 tool/number_model_probe.dart -o /tmp/probe.js
//   node -e "globalThis.self=globalThis; require('/tmp/probe.js')"
//   dart compile wasm tool/number_model_probe.dart -o /tmp/probe.wasm   (run with the generated .mjs)
//
// 2026-11-18: results 1088014, tooBig 265067, digest 345775110 on all three.
// ignore_for_file: avoid_print
//
// Whole numbers only; every result must stay inside +-(2^53 - 1), anything
// else is "This number is too big." Written so that the Dart VM (phone),
// dart2js and dart2wasm agree bit for bit.
const maxSafe = 9007199254740991;

class TooBig implements Exception {}

int _check(int r) {
  if (r > maxSafe || r < -maxSafe) throw TooBig();
  return r;
}

int add(int a, int b) => _check(a + b);
int sub(int a, int b) => _check(a - b);
int mul(int a, int b) {
  // On the VM a * b can wrap around 64 bits back into the safe range, so the
  // size is judged on the (monotonically rounded) double product.
  final d = a.toDouble() * b.toDouble();
  if (d > maxSafe || d < -maxSafe) throw TooBig();
  return _z(a * b);
}

/// JavaScript has a negative zero (0 * -3, -1 ~/ 5); the VM does not.
int _z(int r) => r == 0 ? 0 : r;

int divTrunc(int a, int b) => _z(a ~/ b);
int divFloor(int a, int b) {
  final q = _z(a ~/ b);
  return (q * b != a && ((a < 0) != (b < 0))) ? q - 1 : q;
}

int mod(int a, int b) => _z(a % b);

/// Decimal digits -> number or null, without int.parse (which differs on JS).
int? toNum(String s) {
  var i = 0;
  var neg = false;
  if (s.startsWith('-')) {
    neg = true;
    i = 1;
  }
  if (i >= s.length) return null;
  var n = 0;
  for (; i < s.length; i++) {
    final c = s.codeUnitAt(i) - 48;
    if (c < 0 || c > 9) return null;
    if (n > (maxSafe - c) ~/ 10) return null; // would leave the safe range
    n = n * 10 + c;
  }
  return neg ? _z(-n) : n;
}

String r(int Function() f) {
  try {
    return f().toString();
  } on TooBig {
    return 'TOO_BIG';
  }
}

void main() {
  // Deterministic values around every interesting boundary.
  final seeds = <int>[
    0,
    1,
    -1,
    2,
    -2,
    3,
    7,
    -7,
    10,
    94906265,
    94906266,
    94906267,
    -94906266,
    4503599627370496,
    9007199254740990,
    9007199254740991,
    -9007199254740991,
    -9007199254740990,
    3037000499,
    3037000500,
    2147483647,
    2147483648,
    -2147483648,
    4294967296,
    1000000007,
    999999937,
  ];
  var x = 12345;
  for (var i = 0; i < 400; i++) {
    x =
        (x * 48271) %
        2147483647; // Lehmer LCG: products stay under 2^47 on every target
    final hi = x;
    x = (x * 48271) % 2147483647;
    seeds.add((hi % 4194303) * 2147483648 + x - (i.isEven ? 0 : maxSafe));
  }
  var digest = 0;
  var tooBig = 0, total = 0;
  void feed(String s) {
    for (var i = 0; i < s.length; i++) {
      digest = (digest * 31 + s.codeUnitAt(i)) % 1000000007;
    }
    total++;
    if (s == 'TOO_BIG') tooBig++;
  }

  for (final a in seeds) {
    for (final b in seeds) {
      feed(r(() => add(a, b)));
      feed(r(() => sub(a, b)));
      feed(r(() => mul(a, b)));
      if (b != 0) {
        feed(r(() => divTrunc(a, b)));
        feed(r(() => divFloor(a, b)));
        feed(r(() => mod(a, b)));
      }
    }
    feed('${toNum(a.toString())}');
  }
  for (final s in [
    '9007199254740991',
    '9007199254740992',
    '-9007199254740991',
    '-9007199254740992',
    '00012',
    '-',
    '',
    '12a',
    '99999999999999999999',
    '-0',
  ]) {
    feed('${toNum(s)}');
  }
  print('results $total  tooBig $tooBig  digest $digest');

  // Speed: one billion-ish checked operations is too slow on JS; 20 million.
  final sw = Stopwatch()..start();
  var acc = 1;
  for (var i = 1; i <= 20000000; i++) {
    acc = add(mod(mul(acc, 31), 1000003), i % 7);
  }
  sw.stop();
  print(
    'safe model   20M x (mul, mod, add): ${sw.elapsedMilliseconds} ms (acc $acc)',
  );
  final sw2 = Stopwatch()..start();
  num acc2 = 1;
  for (var i = 1; i <= 20000000; i++) {
    acc2 = ((acc2 * 31) % 1000003) + i % 7;
  }
  sw2.stop();
  print(
    'unchecked num 20M x (mul, mod, add): ${sw2.elapsedMilliseconds} ms (acc $acc2)',
  );
}
