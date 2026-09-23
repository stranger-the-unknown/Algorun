import 'dart:math';

import 'oracle.dart';

int _trips(List<int> ws, int cap) {
  var used = 1;
  var load = 0;
  for (final w in ws) {
    if (load + w > cap) {
      used++;
      load = 0;
    }
    load += w;
  }
  return used;
}

// The Smallest Cart — try capacities upward, not a binary search.
Object? smallestCart(Map<String, Object?> input) {
  final ws = ints(input['weights']);
  final trips = integer(input['trips']);
  var cap = ws.reduce(max);
  while (_trips(ws, cap) > trips) {
    cap++;
  }
  return cap;
}

Map<String, Object?> smallestCartSample(Random r) {
  final ws = randomInts(r, between(r, 1, 8), 1, 9);
  return {'weights': ws, 'trips': between(r, 1, ws.length)};
}

// Lowest Balance — every balance written out, then the smallest.
Object? lowestBalance(Map<String, Object?> input) {
  final balances = [0];
  for (final c in ints(input['changes'])) {
    balances.add(balances.last + c);
  }
  return balances.reduce(min);
}

Map<String, Object?> lowestBalanceSample(Random r) => {'changes': randomInts(r, between(r, 0, 10), -10, 10)};

// Shelf Totals — add up every question's shelves.
Object? shelfTotals(Map<String, Object?> input) {
  final values = ints(input['values']);
  final starts = ints(input['starts']);
  final ends = ints(input['ends']);
  return [
    for (var q = 0; q < starts.length; q++) values.sublist(starts[q], ends[q] + 1).fold<int>(0, (a, b) => a + b),
  ];
}

Map<String, Object?> shelfTotalsSample(Random r) {
  final n = between(r, 1, 8);
  final starts = <int>[];
  final ends = <int>[];
  for (var q = between(r, 0, 6); q > 0; q--) {
    final a = r.nextInt(n);
    starts.add(a);
    ends.add(between(r, a, n - 1));
  }
  return {'values': randomInts(r, n, -5, 5), 'starts': starts, 'ends': ends};
}

// Departure Board — read the board from the top.
Object? departureBoard(Map<String, Object?> input) {
  final times = ints(input['times']);
  final t = integer(input['t']);
  for (var i = 0; i < times.length; i++) {
    if (times[i] >= t) return i;
  }
  return times.length;
}

Map<String, Object?> departureBoardSample(Random r) =>
    {'times': sortedInts(r, between(r, 0, 10), 0, 15), 't': between(r, 0, 17)};

const arrayOracles = {
  'smallest_cart': Oracle(id: 'smallest_cart', solve: smallestCart, sample: smallestCartSample),
  'lowest_balance': Oracle(id: 'lowest_balance', solve: lowestBalance, sample: lowestBalanceSample),
  'shelf_totals': Oracle(id: 'shelf_totals', solve: shelfTotals, sample: shelfTotalsSample),
  'departure_board': Oracle(id: 'departure_board', solve: departureBoard, sample: departureBoardSample),
};
