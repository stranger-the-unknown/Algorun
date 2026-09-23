import 'dart:math';

import 'oracle.dart';

// Matched Pair — every pair.
Object? matchedPair(Map<String, Object?> input) {
  final xs = ints(input['values']);
  final target = integer(input['target']);
  for (var i = 0; i < xs.length; i++) {
    for (var j = i + 1; j < xs.length; j++) {
      if (xs[i] + xs[j] == target) return true;
    }
  }
  return false;
}

Map<String, Object?> matchedPairSample(Random r) =>
    {'values': sortedInts(r, between(r, 0, 10), -10, 10), 'target': between(r, -15, 15)};

// Widest Basin — every pair of walls.
Object? widestBasin(Map<String, Object?> input) {
  final h = ints(input['heights']);
  var best = 0;
  for (var i = 0; i < h.length; i++) {
    for (var j = i + 1; j < h.length; j++) {
      best = max(best, min(h[i], h[j]) * (j - i));
    }
  }
  return best;
}

Map<String, Object?> widestBasinSample(Random r) => {'heights': randomInts(r, between(r, 0, 10), 1, 10)};

const pointerOracles = {
  'matched_pair': Oracle(id: 'matched_pair', solve: matchedPair, sample: matchedPairSample),
  'widest_basin': Oracle(id: 'widest_basin', solve: widestBasin, sample: widestBasinSample),
};
