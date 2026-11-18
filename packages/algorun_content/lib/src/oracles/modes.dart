import 'dart:math';

import 'oracle.dart';

// M1: the complete / repair / predict puzzles. As everywhere, an oracle is
// not the reference's algorithm — for a predict puzzle that matters most,
// because there the reference *is* the program the player reads.

// Flag Lines — 1 + 3 + 5 + … over n lines is n squared.
Object? flagLines(Map<String, Object?> input) => integer(input['lines']) * integer(input['lines']);

Map<String, Object?> flagLinesSample(Random r) => {'lines': between(r, 0, 40)};

// Fence Posts — one post at 0, then one per whole gap that fits.
Object? fencePosts(Map<String, Object?> input) => integer(input['length']) ~/ integer(input['gap']) + 1;

Map<String, Object?> fencePostsSample(Random r) => {'length': between(r, 0, 60), 'gap': between(r, 1, 12)};

// Halve or Step — never played: every binary digit is halved away once
// (the last one is taken off instead), and every 1 digit costs one step.
Object? halveOrStep(Map<String, Object?> input) {
  final start = integer(input['start']);
  if (start == 0) return 0;
  final bits = start.toRadixString(2);
  return bits.length + '1'.allMatches(bits).length - 1;
}

Map<String, Object?> halveOrStepSample(Random r) => {'start': between(r, 0, 1000)};

// High-Water Marks — each mark is the largest of the levels up to that day.
Object? highWaterMarks(Map<String, Object?> input) {
  final levels = ints(input['levels']);
  return [for (var day = 0; day < levels.length; day++) levels.sublist(0, day + 1).reduce(max)];
}

Map<String, Object?> highWaterMarksSample(Random r) => {'levels': randomInts(r, between(r, 0, 10), 0, 9)};

// No Step Down — fine stairs are their own sorted copy.
Object? noStepDown(Map<String, Object?> input) {
  final heights = ints(input['heights']);
  final sorted = [...heights]..sort();
  for (var i = 0; i < heights.length; i++) {
    if (heights[i] != sorted[i]) return false;
  }
  return true;
}

Map<String, Object?> noStepDownSample(Random r) {
  final heights = randomInts(r, between(r, 0, 7), 0, 5);
  // Half the samples are fine stairs, so both answers are exercised.
  if (r.nextBool()) heights.sort();
  return {'heights': heights};
}

// One Pass — nothing is moved: a crate is swapped exactly when it is smaller
// than the largest crate anywhere before it.
Object? onePass(Map<String, Object?> input) {
  final crates = ints(input['crates']);
  var count = 0;
  for (var i = 1; i < crates.length; i++) {
    if (crates[i] < crates.sublist(0, i).reduce(max)) count++;
  }
  return count;
}

Map<String, Object?> onePassSample(Random r) => {'crates': randomInts(r, between(r, 0, 9), 0, 9)};

// Mirror Shelf — a mirror shelf is its own reverse.
Object? mirrorShelf(Map<String, Object?> input) {
  final items = ints(input['items']);
  final reversed = items.reversed.toList();
  for (var i = 0; i < items.length; i++) {
    if (items[i] != reversed[i]) return false;
  }
  return true;
}

Map<String, Object?> mirrorShelfSample(Random r) {
  final half = randomInts(r, between(r, 0, 4), 0, 3);
  // Half the samples are built as mirrors (with or without a middle item).
  if (r.nextBool()) {
    return {
      'items': [...half, if (r.nextBool()) between(r, 0, 3), ...half.reversed],
    };
  }
  return {'items': randomInts(r, between(r, 0, 7), 0, 3)};
}

// Glove Pairs — per size, as many pairs as the box with fewer of it holds.
Object? glovePairs(Map<String, Object?> input) {
  final lefts = ints(input['lefts']);
  final rights = ints(input['rights']);
  var pairs = 0;
  for (final size in lefts.toSet()) {
    pairs += min(lefts.where((s) => s == size).length, rights.where((s) => s == size).length);
  }
  return pairs;
}

Map<String, Object?> glovePairsSample(Random r) => {
      'lefts': randomInts(r, between(r, 0, 7), 1, 5)..sort(),
      'rights': randomInts(r, between(r, 0, 7), 1, 5)..sort(),
    };

// Closing In — the markers meet on a largest card.
Object? closingIn(Map<String, Object?> input) => ints(input['cards']).reduce(max);

Map<String, Object?> closingInSample(Random r) => {'cards': randomInts(r, between(r, 1, 9), 0, 9)};

const modeOracles = <String, Oracle>{
  'flag_lines': Oracle(id: 'flag_lines', solve: flagLines, sample: flagLinesSample),
  'fence_posts': Oracle(id: 'fence_posts', solve: fencePosts, sample: fencePostsSample),
  'halve_or_step': Oracle(id: 'halve_or_step', solve: halveOrStep, sample: halveOrStepSample),
  'high_water_marks': Oracle(id: 'high_water_marks', solve: highWaterMarks, sample: highWaterMarksSample),
  'no_step_down': Oracle(id: 'no_step_down', solve: noStepDown, sample: noStepDownSample),
  'one_pass': Oracle(id: 'one_pass', solve: onePass, sample: onePassSample),
  'mirror_shelf': Oracle(id: 'mirror_shelf', solve: mirrorShelf, sample: mirrorShelfSample),
  'glove_pairs': Oracle(id: 'glove_pairs', solve: glovePairs, sample: glovePairsSample),
  'closing_in': Oracle(id: 'closing_in', solve: closingIn, sample: closingInSample),
};
