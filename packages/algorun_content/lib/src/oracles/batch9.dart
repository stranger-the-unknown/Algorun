import 'dart:collection';
import 'dart:math';

import 'oracle.dart';

// MS16 part 3: Dynamic Programming, Advanced, Stack & Queue, Linked Lists.
// The references fill tables forwards, keep running states, use stacks and
// queues and re-link nodes; these answers come another way: every menu or
// every subset tried, a longest rising run of match positions, sums of
// rectangles, every split day, a depth-first walk, a fresh search after
// every friendship, every stretch, the smallest bead of every window, a
// recount of every prefix, the fixture's own `cycleTo`, and a plain sort.

// Weekly Menu — every menu for a short week; for a long one, "cheapest from
// this day on, given yesterday's dish", asked from the first day.
Object? weeklyMenu(Map<String, Object?> input) {
  final costs = intRows(input['costs']);
  if (costs.length <= 8) {
    var best = costs.isEmpty ? 0 : 1 << 40;
    void choose(int day, int last, int spent) {
      if (day == costs.length) {
        best = min(best, spent);
        return;
      }
      for (var d = 0; d < 3; d++) {
        if (d != last) choose(day + 1, d, spent + costs[day][d]);
      }
    }

    if (costs.isNotEmpty) choose(0, -1, 0);
    return best;
  }
  final memo = <int, int>{};
  int from(int day, int last) {
    if (day == costs.length) return 0;
    return memo[day * 4 + last + 1] ??= [
      for (var d = 0; d < 3; d++)
        if (d != last) costs[day][d] + from(day + 1, d),
    ].reduce(min);
  }

  return from(0, -1);
}

Map<String, Object?> weeklyMenuSample(Random r) {
  final days = between(r, 0, 7);
  // Small prices so the cheapest dish often repeats from day to day.
  return {
    'costs': [for (var i = 0; i < days; i++) randomInts(r, 3, 1, r.nextBool() ? 4 : 30)],
  };
}

// The Shared Route — the positions in the second diary where each peak of
// the first one appears, written from the back; the longest strictly rising
// run of those positions is the longest shared list.
Object? sharedRoute(Map<String, Object?> input) {
  final first = ints(input['first']);
  final second = ints(input['second']);
  final tails = <int>[];
  for (final peak in first) {
    for (var j = second.length - 1; j >= 0; j--) {
      if (second[j] != peak) continue;
      var lo = 0;
      var hi = tails.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (tails[mid] < j) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo == tails.length) {
        tails.add(j);
      } else {
        tails[lo] = j;
      }
    }
  }
  return tails.length;
}

Map<String, Object?> sharedRouteSample(Random r) {
  final hi = between(r, 2, 6);
  return {
    'first': randomInts(r, between(r, 0, 8), 1, hi),
    'second': randomInts(r, between(r, 0, 8), 1, hi),
  };
}

// The Square Plot — sums of rectangles: a square is all fertile when its
// sum is its area. Every corner and every side is tried.
Object? squarePlot(Map<String, Object?> input) {
  final field = intRows(input['field']);
  final rows = field.length;
  final cols = field.first.length;
  final sum = [for (var r = 0; r <= rows; r++) List.filled(cols + 1, 0)];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      sum[r + 1][c + 1] = field[r][c] + sum[r][c + 1] + sum[r + 1][c] - sum[r][c];
    }
  }
  var best = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      for (var s = 1; r + s <= rows && c + s <= cols; s++) {
        final inside = sum[r + s][c + s] - sum[r][c + s] - sum[r + s][c] + sum[r][c];
        if (inside == s * s && s > best) best = s;
      }
    }
  }
  return best * best;
}

Map<String, Object?> squarePlotSample(Random r) {
  final rows = between(r, 1, 6);
  final cols = between(r, 1, 6);
  final rocks = between(r, 0, 4);
  return {
    'field': [
      for (var i = 0; i < rows; i++) [for (var j = 0; j < cols; j++) r.nextInt(10) < rocks ? 0 : 1],
    ],
  };
}

// Two Loads of Salt — every day as the day between the deals: the best
// single deal up to it plus the best single deal from it on, each found by
// trying every pair of days.
Object? twoLoads(Map<String, Object?> input) {
  final prices = ints(input['prices']);
  int single(int from, int to) {
    var best = 0;
    for (var i = from; i <= to; i++) {
      for (var j = i + 1; j <= to; j++) {
        best = max(best, prices[j] - prices[i]);
      }
    }
    return best;
  }

  var best = 0;
  for (var day = 0; day < prices.length; day++) {
    best = max(best, single(0, day) + single(day, prices.length - 1));
  }
  return best;
}

Map<String, Object?> twoLoadsSample(Random r) => {'prices': randomInts(r, between(r, 0, 10), 1, r.nextBool() ? 9 : 60)};

// Assembly Hours — depth first: a step is done one hour after the latest
// step it waits for; meeting a step that is still being worked out is a
// circle.
Object? assemblyHours(Map<String, Object?> input) {
  final next = adjacency(input['steps']);
  final waitsFor = {for (final u in next.keys) u: <int>[]};
  for (final e in next.entries) {
    for (final v in e.value) {
      waitsFor[v]!.add(e.key);
    }
  }
  final hour = <int, int>{};
  final open = <int>{};
  var circle = false;
  int done(int u) {
    final known = hour[u];
    if (known != null) return known;
    if (!open.add(u)) {
      circle = true;
      return 0;
    }
    var latest = 0;
    for (final before in waitsFor[u]!) {
      latest = max(latest, done(before));
      if (circle) return 0;
    }
    open.remove(u);
    return hour[u] = latest + 1;
  }

  var last = 0;
  for (final u in next.keys) {
    last = max(last, done(u));
    if (circle) return -1;
  }
  return last;
}

Map<String, Object?> assemblyHoursSample(Random r) {
  final n = between(r, 1, 8);
  final order = [for (var i = 0; i < n; i++) i]..shuffle(r);
  final adj = [for (var i = 0; i < n; i++) <int>{}];
  // Rules that follow a hidden order can never form a circle …
  for (var k = between(r, 0, n * 2); k > 0 && n > 1; k--) {
    final a = r.nextInt(n);
    final b = r.nextInt(n);
    if (a < b) adj[order[a]].add(order[b]);
  }
  // … and one rule against it sometimes does.
  if (n > 1 && r.nextInt(3) == 0) {
    final a = r.nextInt(n - 1);
    final b = a + 1 + r.nextInt(n - 1 - a);
    adj[order[b]].add(order[a]);
  }
  return {
    'steps': graphJson([for (final s in adj) s.toList()]),
  };
}

// Friend Groups — after every friendship the camp is searched again from
// scratch, breadth first.
Object? friendGroups(Map<String, Object?> input) {
  final people = integer(input['people']);
  final a = ints(input['a']);
  final b = ints(input['b']);
  final friends = [for (var i = 0; i < people; i++) <int>[]];
  final out = <int>[];
  for (var k = 0; k < a.length; k++) {
    friends[a[k]].add(b[k]);
    friends[b[k]].add(a[k]);
    final seen = List.filled(people, false);
    var groups = 0;
    for (var start = 0; start < people; start++) {
      if (seen[start]) continue;
      groups++;
      seen[start] = true;
      final line = Queue<int>()..add(start);
      while (line.isNotEmpty) {
        for (final f in friends[line.removeFirst()]) {
          if (!seen[f]) {
            seen[f] = true;
            line.add(f);
          }
        }
      }
    }
    out.add(groups);
  }
  return out;
}

Map<String, Object?> friendGroupsSample(Random r) {
  final people = between(r, 2, 9);
  final count = between(r, 0, 12);
  final a = <int>[];
  final b = <int>[];
  for (var k = 0; k < count; k++) {
    final x = r.nextInt(people);
    var y = r.nextInt(people - 1);
    if (y >= x) y++;
    a.add(x);
    b.add(y);
  }
  return {'people': people, 'a': a, 'b': b};
}

// Festival Stage — every set of bands for a short list; for a long one, the
// best chain of bands ending with each band.
Object? festivalStage(Map<String, Object?> input) {
  final starts = ints(input['starts']);
  final ends = ints(input['ends']);
  final crowd = ints(input['crowd']);
  final n = starts.length;
  var best = 0;
  if (n <= 14) {
    for (var mask = 0; mask < 1 << n; mask++) {
      var total = 0;
      var ok = true;
      for (var i = 0; i < n && ok; i++) {
        if (mask & (1 << i) == 0) continue;
        total += crowd[i];
        for (var j = i + 1; j < n; j++) {
          if (mask & (1 << j) != 0 && starts[i] < ends[j] && starts[j] < ends[i]) ok = false;
        }
      }
      if (ok) best = max(best, total);
    }
    return best;
  }
  final chain = List.filled(n, 0);
  for (var j = 0; j < n; j++) {
    var before = 0;
    for (var i = 0; i < n; i++) {
      if (ends[i] <= starts[j] && chain[i] > before) before = chain[i];
    }
    // A band that ends before this one starts is earlier in the list, so its
    // own chain is already known.
    chain[j] = before + crowd[j];
    best = max(best, chain[j]);
  }
  return best;
}

Map<String, Object?> festivalStageSample(Random r) {
  final n = between(r, 0, 9);
  final slots = [
    for (var i = 0; i < n; i++) (start: between(r, 0, 20), length: between(r, 1, 8), crowd: between(r, 1, 60)),
  ]..sort((x, y) => (x.start + x.length).compareTo(y.start + y.length));
  return {
    'starts': [for (final s in slots) s.start],
    'ends': [for (final s in slots) s.start + s.length],
    'crowd': [for (final s in slots) s.crowd],
  };
}

// Every Cold Spell — every stretch, with its coldest reading kept as the
// stretch grows.
Object? coldSpells(Map<String, Object?> input) {
  final temps = ints(input['temps']);
  var total = 0;
  for (var i = 0; i < temps.length; i++) {
    var coldest = temps[i];
    for (var j = i; j < temps.length; j++) {
      coldest = min(coldest, temps[j]);
      total += coldest;
    }
  }
  return total;
}

Map<String, Object?> coldSpellsSample(Random r) =>
    {'temps': randomInts(r, between(r, 0, 10), r.nextBool() ? 0 : -6, r.nextBool() ? 3 : 9)};

// The Smallest Ribbon — bead by bead: the next kept bead is the smallest one
// that still leaves enough beads behind it, the earliest such when equal.
Object? smallestRibbon(Map<String, Object?> input) {
  final beads = ints(input['beads']);
  final keep = integer(input['keep']);
  final out = <int>[];
  var from = 0;
  for (var left = keep; left > 0; left--) {
    var at = from;
    for (var i = from; i <= beads.length - left; i++) {
      if (beads[i] < beads[at]) at = i;
    }
    out.add(beads[at]);
    from = at + 1;
  }
  return out;
}

Map<String, Object?> smallestRibbonSample(Random r) {
  final beads = randomInts(r, between(r, 1, 9), 1, r.nextBool() ? 4 : 9);
  return {'beads': beads, 'keep': between(r, 0, beads.length)};
}

// The Lone Request — after every call the whole list so far is recounted
// (one tally per call) and read again from its start.
Object? loneRequest(Map<String, Object?> input) {
  final songs = ints(input['songs']);
  final out = <int>[];
  for (var k = 1; k <= songs.length; k++) {
    final sofar = songs.sublist(0, k);
    final asked = <int, int>{};
    for (final s in sofar) {
      asked[s] = (asked[s] ?? 0) + 1;
    }
    out.add(sofar.firstWhere((s) => asked[s] == 1, orElse: () => -1));
  }
  return out;
}

Map<String, Object?> loneRequestSample(Random r) => {'songs': randomInts(r, between(r, 0, 12), 1, between(r, 2, 6))};

// The Twice-Read Clue — the fixture says where the last card points.
Object? twiceReadClue(Map<String, Object?> input) => chainCycle(input['head']) ?? -1;

Map<String, Object?> twiceReadClueSample(Random r) {
  final n = between(r, 0, 9);
  if (n == 0) return {'head': null};
  final values = randomInts(r, n, 0, 3);
  return {
    'head': {'type': 'listNode', 'values': values, if (r.nextInt(3) != 0) 'cycleTo': r.nextInt(n)},
  };
}

// Two Trains, One Track — all the car numbers, sorted.
Object? twoTrains(Map<String, Object?> input) =>
    chainJson([...chainValues(input['left']), ...chainValues(input['right'])]..sort());

Map<String, Object?> twoTrainsSample(Random r) => {
      'left': chainJson(sortedInts(r, between(r, 0, 6), 0, 9)),
      'right': chainJson(sortedInts(r, between(r, 0, 6), 0, 9)),
    };

const Map<String, Oracle> batch9Oracles = {
  'weekly_menu': Oracle(id: 'weekly_menu', solve: weeklyMenu, sample: weeklyMenuSample),
  'shared_route': Oracle(id: 'shared_route', solve: sharedRoute, sample: sharedRouteSample),
  'square_plot': Oracle(id: 'square_plot', solve: squarePlot, sample: squarePlotSample),
  'two_loads': Oracle(id: 'two_loads', solve: twoLoads, sample: twoLoadsSample),
  'assembly_hours': Oracle(id: 'assembly_hours', solve: assemblyHours, sample: assemblyHoursSample),
  'friend_groups': Oracle(id: 'friend_groups', solve: friendGroups, sample: friendGroupsSample),
  'festival_stage': Oracle(id: 'festival_stage', solve: festivalStage, sample: festivalStageSample),
  'cold_spells': Oracle(id: 'cold_spells', solve: coldSpells, sample: coldSpellsSample),
  'smallest_ribbon': Oracle(id: 'smallest_ribbon', solve: smallestRibbon, sample: smallestRibbonSample),
  'lone_request': Oracle(id: 'lone_request', solve: loneRequest, sample: loneRequestSample),
  'twice_read_clue': Oracle(id: 'twice_read_clue', solve: twiceReadClue, sample: twiceReadClueSample),
  'two_trains': Oracle(id: 'two_trains', solve: twoTrains, sample: twoTrainsSample),
};
