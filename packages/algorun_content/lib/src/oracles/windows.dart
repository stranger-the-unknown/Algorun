import 'dart:math';

import 'oracle.dart';

// Quota Hours — every run, not a sliding window.
Object? quotaHours(Map<String, Object?> input) {
  final xs = ints(input['energy']);
  final q = integer(input['quota']);
  var best = 0;
  for (var s = 0; s < xs.length; s++) {
    var total = 0;
    for (var e = s; e < xs.length; e++) {
      total += xs[e];
      if (total >= q && (best == 0 || e - s + 1 < best)) best = e - s + 1;
    }
  }
  return best;
}

Map<String, Object?> quotaHoursSample(Random r) =>
    {'energy': randomInts(r, between(r, 0, 12), 1, 9), 'quota': between(r, 1, 40)};

// Rush Hour — add up every window.
Object? rushHour(Map<String, Object?> input) {
  final c = ints(input['counts']);
  final k = integer(input['k']);
  int? best;
  for (var i = 0; i + k <= c.length; i++) {
    final s = c.sublist(i, i + k).fold<int>(0, (a, b) => a + b);
    if (best == null || s > best) best = s;
  }
  return best;
}

Map<String, Object?> rushHourSample(Random r) {
  final c = randomInts(r, between(r, 1, 10), 0, 9);
  return {'counts': c, 'k': between(r, 1, c.length)};
}

// Patchy Signal — every window, counting its dropouts as it grows.
Object? patchySignal(Map<String, Object?> input) {
  final s = ints(input['signal']);
  final k = integer(input['k']);
  var best = 0;
  for (var i = 0; i < s.length; i++) {
    var zeros = 0;
    for (var j = i; j < s.length; j++) {
      if (s[j] == 0) zeros++;
      if (zeros <= k) best = max(best, j - i + 1);
    }
  }
  return best;
}

Map<String, Object?> patchySignalSample(Random r) =>
    {'signal': randomInts(r, between(r, 0, 12), 0, 1), 'k': between(r, 0, 3)};

// Market Variety — every window, collecting its kinds as it grows.
Object? marketVariety(Map<String, Object?> input) {
  final s = ints(input['stalls']);
  final k = integer(input['k']);
  var best = 0;
  for (var i = 0; i < s.length; i++) {
    final kinds = <int>{};
    for (var j = i; j < s.length; j++) {
      kinds.add(s[j]);
      if (kinds.length <= k) best = max(best, j - i + 1);
    }
  }
  return best;
}

Map<String, Object?> marketVarietySample(Random r) =>
    {'stalls': randomInts(r, between(r, 0, 12), 1, 4), 'k': between(r, 1, 3)};

const windowOracles = {
  'quota_hours': Oracle(id: 'quota_hours', solve: quotaHours, sample: quotaHoursSample),
  'rush_hour': Oracle(id: 'rush_hour', solve: rushHour, sample: rushHourSample),
  'patchy_signal': Oracle(id: 'patchy_signal', solve: patchySignal, sample: patchySignalSample),
  'market_variety': Oracle(id: 'market_variety', solve: marketVariety, sample: marketVarietySample),
};
