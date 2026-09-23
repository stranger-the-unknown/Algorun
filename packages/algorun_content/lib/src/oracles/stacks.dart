import 'dart:math';

import 'oracle.dart';

// Relay Towers — look east from every tower, not a stack.
Object? relayTowers(Map<String, Object?> input) {
  final hs = ints(input['heights']);
  return [
    for (var i = 0; i < hs.length; i++)
      () {
        for (var j = i + 1; j < hs.length; j++) {
          if (hs[j] > hs[i]) return j - i;
        }
        return 0;
      }(),
  ];
}

Map<String, Object?> relayTowersSample(Random r) => {'heights': randomInts(r, between(r, 0, 12), 1, 6)};

// Sealed Crates — delete adjacent matching "open k, seal k" pairs until none
// are left; no stack.
Object? sealedCrates(Map<String, Object?> input) {
  final xs = ints(input['codes']);
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i + 1 < xs.length; i++) {
      if (xs[i] > 0 && xs[i + 1] == -xs[i]) {
        xs.removeRange(i, i + 2);
        changed = true;
        break;
      }
    }
  }
  return xs.isEmpty;
}

const _codes = [-3, -2, -1, 1, 2, 3];

Map<String, Object?> sealedCratesSample(Random r) {
  final out = <int>[];
  if (r.nextBool()) {
    // A correct log, sometimes broken by one change.
    final open = <int>[];
    for (var steps = between(r, 0, 10); steps > 0; steps--) {
      if (open.isNotEmpty && r.nextBool()) {
        out.add(-open.removeLast());
      } else {
        final k = between(r, 1, 3);
        open.add(k);
        out.add(k);
      }
    }
    while (open.isNotEmpty) {
      out.add(-open.removeLast());
    }
    if (out.isNotEmpty && r.nextBool()) out[r.nextInt(out.length)] = _codes[r.nextInt(_codes.length)];
  } else {
    for (var i = between(r, 0, 8); i > 0; i--) {
      out.add(_codes[r.nextInt(_codes.length)]);
    }
  }
  return {'codes': out};
}

// Undo Button — keep the note as a list of words.
Object? undoButton(Map<String, Object?> input) {
  final note = <int>[];
  for (final a in ints(input['actions'])) {
    if (a > 0) {
      note.add(a);
    } else if (note.isNotEmpty) {
      note.removeLast();
    }
  }
  return note.fold<int>(0, (a, b) => a + b);
}

Map<String, Object?> undoButtonSample(Random r) => {'actions': randomInts(r, between(r, 0, 10), 0, 5)};

// Largest Billboard — every run of neighbours with its lowest building.
Object? largestBillboard(Map<String, Object?> input) {
  final h = ints(input['heights']);
  var best = 0;
  for (var i = 0; i < h.length; i++) {
    var low = h[i];
    for (var j = i; j < h.length; j++) {
      low = min(low, h[j]);
      best = max(best, low * (j - i + 1));
    }
  }
  return best;
}

Map<String, Object?> largestBillboardSample(Random r) => {'heights': randomInts(r, between(r, 0, 10), 1, 6)};

const stackOracles = {
  'relay_towers': Oracle(id: 'relay_towers', solve: relayTowers, sample: relayTowersSample),
  'sealed_crates': Oracle(id: 'sealed_crates', solve: sealedCrates, sample: sealedCratesSample),
  'undo_button': Oracle(id: 'undo_button', solve: undoButton, sample: undoButtonSample),
  'largest_billboard': Oracle(id: 'largest_billboard', solve: largestBillboard, sample: largestBillboardSample),
};
