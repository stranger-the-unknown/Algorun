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

// --- MS15: the rest of Foundations. Each answer comes from the story's
// definition or a different calculation, never the reference's loop.

// Museum Tickets — the three age bands, read straight from the story.
Object? ticketPrice(Map<String, Object?> input) {
  final age = integer(input['age']);
  if (age < 6) return 0;
  if (age >= 65) return 4;
  return 10;
}

Map<String, Object?> ticketPriceSample(Random r) => {'age': between(r, 0, 120)};

// Stair Lights — multiples of the gap up to the top step, by division.
Object? stairLights(Map<String, Object?> input) => integer(input['steps']) ~/ integer(input['gap']);

Map<String, Object?> stairLightsSample(Random r) => {'steps': between(r, 0, 40), 'gap': between(r, 1, 12)};

// Party Tables — the smallest number of tables whose seats cover the guests.
Object? partyTables(Map<String, Object?> input) {
  final guests = integer(input['guests']);
  final seats = integer(input['seats']);
  var tables = 0;
  while (tables * seats < guests) {
    tables++;
  }
  return tables;
}

Map<String, Object?> partyTablesSample(Random r) => {'guests': between(r, 0, 60), 'seats': between(r, 1, 12)};

// Doubling Jar — coins × 2^k ≥ goal: k from the bit length of the needed
// factor, not by doubling.
Object? doublingJar(Map<String, Object?> input) {
  final coins = integer(input['coins']);
  final goal = integer(input['goal']);
  if (coins >= goal) return 0;
  final factor = (goal + coins - 1) ~/ coins; // the jar must grow at least this much
  return (factor - 1).bitLength;
}

Map<String, Object?> doublingJarSample(Random r) => {'coins': between(r, 1, 50), 'goal': between(r, 1, 5000)};

// Digit Wheels — the number written out.
Object? digitWheels(Map<String, Object?> input) => integer(input['number']).toString().length;

Map<String, Object?> digitWheelsSample(Random r) {
  final digits = between(r, 1, 9);
  final lo = digits == 1 ? 0 : pow(10, digits - 1).toInt();
  return {'number': lo + r.nextInt(pow(10, digits).toInt() - lo)};
}

// Three Planks — sorted, the two shortest must beat the longest.
Object? threePlanks(Map<String, Object?> input) {
  final sides = [integer(input['a']), integer(input['b']), integer(input['c'])]..sort();
  return sides[0] + sides[1] > sides[2];
}

Map<String, Object?> threePlanksSample(Random r) =>
    {'a': between(r, 1, 12), 'b': between(r, 1, 12), 'c': between(r, 1, 12)};

// Lighthouse and Bell — inclusion–exclusion: flashes plus rings, minus both
// twice (a shared second is neither counted as a flash nor as a ring).
Object? lighthouseBell(Map<String, Object?> input) {
  final seconds = integer(input['seconds']);
  final flash = integer(input['flash']);
  final ring = integer(input['ring']);
  var both = flash;
  while (both % ring != 0) {
    both += flash;
  }
  return seconds ~/ flash + seconds ~/ ring - 2 * (seconds ~/ both);
}

Map<String, Object?> lighthouseBellSample(Random r) =>
    {'seconds': between(r, 0, 60), 'flash': between(r, 1, 8), 'ring': between(r, 1, 8)};

// Longest Dry Spell — every start day, extended while it stays dry.
Object? dryRun(Map<String, Object?> input) {
  final rain = ints(input['rain']);
  var best = 0;
  for (var start = 0; start < rain.length; start++) {
    var end = start;
    while (end < rain.length && rain[end] == 0) {
      end++;
    }
    if (end - start > best) best = end - start;
  }
  return best;
}

Map<String, Object?> dryRunSample(Random r) =>
    {'rain': [for (var i = between(r, 0, 14); i > 0; i--) r.nextInt(3) == 0 ? between(r, 1, 9) : 0]};

// Hill Tops — every interior point against both neighbours.
Object? hillTops(Map<String, Object?> input) {
  final h = ints(input['heights']);
  return [for (var i = 1; i < h.length - 1; i++) i].where((i) => h[i] > h[i - 1] && h[i] > h[i + 1]).length;
}

Map<String, Object?> hillTopsSample(Random r) => {'heights': randomInts(r, between(r, 0, 12), -3, 3)};

// Lift Trips — the queue split into trips, each a list of people.
Object? liftTrips(Map<String, Object?> input) {
  final capacity = integer(input['capacity']);
  final trips = <List<int>>[];
  for (final w in ints(input['weights'])) {
    if (trips.isEmpty || trips.last.fold<int>(0, (a, b) => a + b) + w > capacity) {
      trips.add([w]);
    } else {
      trips.last.add(w);
    }
  }
  return trips.length;
}

Map<String, Object?> liftTripsSample(Random r) {
  final capacity = between(r, 150, 400);
  return {'weights': randomInts(r, between(r, 0, 10), 1, 150), 'capacity': capacity};
}

const foundationOracles = {
  'warm_readings': Oracle(id: 'warm_readings', solve: warmReadings, sample: warmReadingsSample),
  'highest_tide': Oracle(id: 'highest_tide', solve: highestTide, sample: highestTideSample),
  'ticket_price': Oracle(id: 'ticket_price', solve: ticketPrice, sample: ticketPriceSample),
  'stair_lights': Oracle(id: 'stair_lights', solve: stairLights, sample: stairLightsSample),
  'party_tables': Oracle(id: 'party_tables', solve: partyTables, sample: partyTablesSample),
  'doubling_jar': Oracle(id: 'doubling_jar', solve: doublingJar, sample: doublingJarSample),
  'digit_wheels': Oracle(id: 'digit_wheels', solve: digitWheels, sample: digitWheelsSample),
  'three_planks': Oracle(id: 'three_planks', solve: threePlanks, sample: threePlanksSample),
  'lighthouse_bell': Oracle(id: 'lighthouse_bell', solve: lighthouseBell, sample: lighthouseBellSample),
  'dry_spell': Oracle(id: 'dry_spell', solve: dryRun, sample: dryRunSample),
  'hill_tops': Oracle(id: 'hill_tops', solve: hillTops, sample: hillTopsSample),
  'lift_trips': Oracle(id: 'lift_trips', solve: liftTrips, sample: liftTripsSample),
};
