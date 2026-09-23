import 'dart:math';

import 'oracle.dart';

// One Good Trade — every buying day with every later selling day.
Object? oneGoodTrade(Map<String, Object?> input) {
  final p = ints(input['prices']);
  var best = 0;
  for (var i = 0; i < p.length; i++) {
    for (var j = i + 1; j < p.length; j++) {
      best = max(best, p[j] - p[i]);
    }
  }
  return best;
}

Map<String, Object?> oneGoodTradeSample(Random r) => {'prices': randomInts(r, between(r, 0, 10), 1, 20)};

// Fuel Loop — drive a lap from every station.
Object? fuelLoop(Map<String, Object?> input) {
  final fuel = ints(input['fuel']);
  final cost = ints(input['cost']);
  final n = fuel.length;
  for (var s = 0; s < n; s++) {
    var tank = 0;
    var ok = true;
    for (var k = 0; k < n && ok; k++) {
      final i = (s + k) % n;
      tank += fuel[i] - cost[i];
      ok = tank >= 0;
    }
    if (ok) return s;
  }
  return -1;
}

Map<String, Object?> fuelLoopSample(Random r) {
  final n = between(r, 1, 8);
  return {'fuel': randomInts(r, n, 0, 6), 'cost': randomInts(r, n, 0, 6)};
}

// Quiet Street — the best total ending at each house, from any earlier house
// at least two doors away (a quadratic table, not two running states).
Object? quietStreet(Map<String, Object?> input) {
  final v = ints(input['values']);
  final ending = List.filled(v.length, 0);
  var best = 0;
  for (var i = 0; i < v.length; i++) {
    var before = 0;
    for (var j = 0; j + 1 < i; j++) {
      before = max(before, ending[j]);
    }
    ending[i] = before + v[i];
    best = max(best, ending[i]);
  }
  return best;
}

Map<String, Object?> quietStreetSample(Random r) => {'values': randomInts(r, between(r, 0, 10), 0, 20)};

// Exact Change — breadth-first over amounts reachable with k coins.
Object? exactChange(Map<String, Object?> input) {
  final coins = ints(input['coins']);
  final amount = integer(input['amount']);
  var frontier = {0};
  final seen = {0};
  for (var k = 0; frontier.isNotEmpty; k++) {
    if (frontier.contains(amount)) return k;
    final next = <int>{};
    for (final s in frontier) {
      for (final c in coins) {
        if (s + c <= amount && seen.add(s + c)) next.add(s + c);
      }
    }
    frontier = next;
  }
  return -1;
}

Map<String, Object?> exactChangeSample(Random r) {
  final coins = ({for (var k = between(r, 1, 4); k > 0; k--) between(r, 1, 12)}).toList()..sort();
  return {'coins': coins, 'amount': between(r, 0, 40)};
}

const greedyDpOracles = {
  'one_good_trade': Oracle(id: 'one_good_trade', solve: oneGoodTrade, sample: oneGoodTradeSample),
  'fuel_loop': Oracle(id: 'fuel_loop', solve: fuelLoop, sample: fuelLoopSample),
  'quiet_street': Oracle(id: 'quiet_street', solve: quietStreet, sample: quietStreetSample),
  'exact_change': Oracle(id: 'exact_change', solve: exactChange, sample: exactChangeSample),
};
