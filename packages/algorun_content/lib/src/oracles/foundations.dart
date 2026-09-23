import 'dart:math';

import 'oracle.dart';

// Warm Readings — filter and count.
Object? warmReadings(Map<String, Object?> input) {
  final limit = integer(input['limit']);
  return ints(input['readings']).where((r) => r > limit).length;
}

Map<String, Object?> warmReadingsSample(Random r) =>
    {'readings': randomInts(r, between(r, 0, 10), -5, 5), 'limit': between(r, -5, 5)};

// Highest Tide — the maximum first, then where it first appears.
Object? highestTide(Map<String, Object?> input) {
  final tides = ints(input['tides']);
  if (tides.isEmpty) return -1;
  return tides.indexOf(tides.reduce(max));
}

Map<String, Object?> highestTideSample(Random r) => {'tides': randomInts(r, between(r, 0, 10), -3, 3)};

const foundationOracles = {
  'warm_readings': Oracle(id: 'warm_readings', solve: warmReadings, sample: warmReadingsSample),
  'highest_tide': Oracle(id: 'highest_tide', solve: highestTide, sample: highestTideSample),
};
