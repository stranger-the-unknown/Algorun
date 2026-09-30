import 'dart:math';

import 'oracle.dart';

// MS15 part 2: new puzzles in Arrays, Hash Maps, Two Pointers and Greedy.
// Each answer is computed another way than the reference: brute force, a
// library call, sorting, or a different algorithm (DP, relaxation).

// Last Sighting — the list's own lastIndexOf.
Object? lastSighting(Map<String, Object?> input) => ints(input['sightings']).lastIndexOf(integer(input['bird']));

Map<String, Object?> lastSightingSample(Random r) =>
    {'sightings': randomInts(r, between(r, 0, 10), 1, 4), 'bird': between(r, 1, 5)};

// Till Totals — every prefix added up from scratch.
Object? tillTotals(Map<String, Object?> input) {
  final sales = ints(input['sales']);
  return [for (var i = 0; i < sales.length; i++) sales.sublist(0, i + 1).fold<int>(0, (a, b) => a + b)];
}

Map<String, Object?> tillTotalsSample(Random r) => {'sales': randomInts(r, between(r, 0, 10), -20, 50)};

// Balance Point — both sides added up for every crate.
Object? balancePoint(Map<String, Object?> input) {
  final w = ints(input['weights']);
  int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
  for (var i = 0; i < w.length; i++) {
    if (sum(w.take(i)) == sum(w.skip(i + 1))) return i;
  }
  return -1;
}

Map<String, Object?> balancePointSample(Random r) {
  final left = randomInts(r, between(r, 0, 5), 0, 6);
  final shape = r.nextInt(3);
  if (shape == 0) return {'weights': randomInts(r, between(r, 0, 9), 0, 6)};
  final mid = between(r, 0, 9);
  return {'weights': [...left, mid, ...(shape == 1 ? left.reversed : left)]};
}

// Landslide — a full tally per candidate.
Object? landslide(Map<String, Object?> input) {
  final ballots = ints(input['ballots']);
  final tally = <int, int>{};
  for (final b in ballots) {
    tally[b] = (tally[b] ?? 0) + 1;
  }
  for (final e in tally.entries) {
    if (e.value * 2 > ballots.length) return e.key;
  }
  return 0;
}

Map<String, Object?> landslideSample(Random r) => {'ballots': randomInts(r, between(r, 0, 9), 1, 3)};

// Second Scan — the first position whose card is somewhere before it.
Object? secondScan(Map<String, Object?> input) {
  final cards = ints(input['cards']);
  for (var j = 0; j < cards.length; j++) {
    if (cards.sublist(0, j).contains(cards[j])) return j;
  }
  return -1;
}

Map<String, Object?> secondScanSample(Random r) => {'cards': randomInts(r, between(r, 0, 8), 1, 9)};

// Matching Bags — both bags sorted and compared.
Object? matchingBags(Map<String, Object?> input) {
  final a = ints(input['left'])..sort();
  final b = ints(input['right'])..sort();
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Map<String, Object?> matchingBagsSample(Random r) {
  final left = randomInts(r, between(r, 0, 6), 1, 4);
  final right = r.nextBool() ? (List.of(left)..shuffle(r)) : randomInts(r, between(r, 0, 6), 1, 4);
  return {'left': left, 'right': right};
}

// Lonely Numbers — each value's count by scanning the whole drum.
Object? lonelyNumbers(Map<String, Object?> input) {
  final t = ints(input['tickets']);
  return t.where((v) => t.where((w) => w == v).length == 1).length;
}

Map<String, Object?> lonelyNumbersSample(Random r) => {'tickets': randomInts(r, between(r, 0, 10), 1, 5)};

// Sorted Shelf — the distinct numbers as a set.
Object? sortedShelf(Map<String, Object?> input) => ints(input['books']).toSet().length;

Map<String, Object?> sortedShelfSample(Random r) => {'books': sortedInts(r, between(r, 0, 10), -3, 5)};

// Recipe Steps — the longest common subsequence covers the whole recipe.
Object? recipeSteps(Map<String, Object?> input) {
  final log = ints(input['log']);
  final recipe = ints(input['recipe']);
  final dp = List.generate(log.length + 1, (_) => List.filled(recipe.length + 1, 0));
  for (var i = 1; i <= log.length; i++) {
    for (var j = 1; j <= recipe.length; j++) {
      dp[i][j] = log[i - 1] == recipe[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[log.length][recipe.length] == recipe.length;
}

Map<String, Object?> recipeStepsSample(Random r) =>
    {'log': randomInts(r, between(r, 0, 9), 1, 4), 'recipe': randomInts(r, between(r, 0, 4), 1, 4)};

// Every Rise — best cash when holding or not holding a share, day by day.
Object? everyRise(Map<String, Object?> input) {
  final p = ints(input['prices']);
  if (p.isEmpty) return 0;
  var cash = 0;
  var hold = -p[0];
  for (final price in p.skip(1)) {
    final nextCash = max(cash, hold + price);
    final nextHold = max(hold, cash - price);
    cash = nextCash;
    hold = nextHold;
  }
  return cash;
}

Map<String, Object?> everyRiseSample(Random r) => {'prices': randomInts(r, between(r, 0, 10), 1, 9)};

// One Room — interval scheduling by DP over talks sorted by end.
Object? oneRoom(Map<String, Object?> input) {
  final s = ints(input['starts']);
  final e = ints(input['ends']);
  final n = s.length;
  final best = List.filled(n + 1, 0);
  for (var i = 1; i <= n; i++) {
    var p = i - 1;
    while (p > 0 && e[p - 1] > s[i - 1]) {
      p--;
    }
    best[i] = max(best[i - 1], best[p] + 1);
  }
  return best[n];
}

Map<String, Object?> oneRoomSample(Random r) {
  final talks = [
    for (var i = between(r, 0, 7); i > 0; i--)
      () {
        final start = between(r, 0, 12);
        return (start, start + between(r, 1, 4));
      }(),
  ]..sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$1 - b.$1);
  return {'starts': [for (final t in talks) t.$1], 'ends': [for (final t in talks) t.$2]};
}

// Medals in a Row — raise any runner who breaks the rule until nobody does.
Object? medalRow(Map<String, Object?> input) {
  final t = ints(input['times']);
  final m = List.filled(t.length, 1);
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < t.length; i++) {
      for (final j in [i - 1, i + 1]) {
        if (j < 0 || j >= t.length) continue;
        if (t[i] < t[j] && m[i] <= m[j]) {
          m[i] = m[j] + 1;
          changed = true;
        }
      }
    }
  }
  return m.fold<int>(0, (a, b) => a + b);
}

Map<String, Object?> medalRowSample(Random r) => {'times': randomInts(r, between(r, 0, 9), 1, 5)};

const batch3Oracles = {
  'last_sighting': Oracle(id: 'last_sighting', solve: lastSighting, sample: lastSightingSample),
  'till_totals': Oracle(id: 'till_totals', solve: tillTotals, sample: tillTotalsSample),
  'balance_point': Oracle(id: 'balance_point', solve: balancePoint, sample: balancePointSample),
  'landslide': Oracle(id: 'landslide', solve: landslide, sample: landslideSample),
  'second_scan': Oracle(id: 'second_scan', solve: secondScan, sample: secondScanSample),
  'matching_bags': Oracle(id: 'matching_bags', solve: matchingBags, sample: matchingBagsSample),
  'lonely_numbers': Oracle(id: 'lonely_numbers', solve: lonelyNumbers, sample: lonelyNumbersSample),
  'sorted_shelf': Oracle(id: 'sorted_shelf', solve: sortedShelf, sample: sortedShelfSample),
  'recipe_steps': Oracle(id: 'recipe_steps', solve: recipeSteps, sample: recipeStepsSample),
  'every_rise': Oracle(id: 'every_rise', solve: everyRise, sample: everyRiseSample),
  'one_room': Oracle(id: 'one_room', solve: oneRoom, sample: oneRoomSample),
  'medal_row': Oracle(id: 'medal_row', solve: medalRow, sample: medalRowSample),
};
