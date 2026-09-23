import 'dart:math';

import 'oracle.dart';

// Twin Beacons — every pair, not a set of complements.
Object? twinBeacons(Map<String, Object?> input) {
  final xs = ints(input['strengths']);
  final t = integer(input['tuning']);
  for (var j = 0; j < xs.length; j++) {
    for (var i = 0; i < j; i++) {
      if (xs[i] + xs[j] == t) return j;
    }
  }
  return -1;
}

Map<String, Object?> twinBeaconsSample(Random r) =>
    {'strengths': randomInts(r, between(r, 0, 12), -10, 10), 'tuning': between(r, -15, 15)};

// Loudest Echo — count each distinct call separately, smallest first.
Object? loudestEcho(Map<String, Object?> input) {
  final calls = ints(input['calls']);
  final distinct = calls.toSet().toList()..sort();
  var best = distinct.first;
  var bestCount = -1;
  for (final v in distinct) {
    final c = calls.where((x) => x == v).length;
    if (c > bestCount) {
      best = v;
      bestCount = c;
    }
  }
  return best;
}

Map<String, Object?> loudestEchoSample(Random r) => {'calls': randomInts(r, between(r, 1, 10), -3, 3)};

// Level Stretches — every stretch.
Object? levelStretches(Map<String, Object?> input) {
  final xs = ints(input['changes']);
  final target = integer(input['target']);
  var count = 0;
  for (var i = 0; i < xs.length; i++) {
    var s = 0;
    for (var j = i; j < xs.length; j++) {
      s += xs[j];
      if (s == target) count++;
    }
  }
  return count;
}

Map<String, Object?> levelStretchesSample(Random r) =>
    {'changes': randomInts(r, between(r, 0, 10), -3, 3), 'target': between(r, -3, 3)};

// Longest Streak — sort the distinct numbers and scan.
Object? longestStreak(Map<String, Object?> input) {
  final u = ints(input['values']).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  for (var i = 0; i < u.length; i++) {
    run = i > 0 && u[i - 1] == u[i] - 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}

Map<String, Object?> longestStreakSample(Random r) => {'values': randomInts(r, between(r, 0, 10), -6, 6)};

const hashingOracles = {
  'twin_beacons': Oracle(id: 'twin_beacons', solve: twinBeacons, sample: twinBeaconsSample),
  'loudest_echo': Oracle(id: 'loudest_echo', solve: loudestEcho, sample: loudestEchoSample),
  'level_stretches': Oracle(id: 'level_stretches', solve: levelStretches, sample: levelStretchesSample),
  'longest_streak': Oracle(id: 'longest_streak', solve: longestStreak, sample: longestStreakSample),
};
