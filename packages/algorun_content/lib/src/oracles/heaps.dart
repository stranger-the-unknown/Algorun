import 'dart:math';

import 'oracle.dart';

// Milestone H, world 09 Heaps. The references use a heap; these answers come
// another way: sorting, scanning a list of free seats, counting events in
// time order, and re-sorting after every step.

// Top Scores — sort, add the k best (all of them when there are fewer).
Object? topScores(Map<String, Object?> input) {
  final scores = ints(input['scores'])..sort((a, b) => b.compareTo(a));
  return scores.take(integer(input['k'])).fold<int>(0, (a, b) => a + b);
}

Map<String, Object?> topScoresSample(Random r) {
  final n = between(r, 0, 8);
  return {'scores': randomInts(r, n, 0, 100), 'k': between(r, 0, n + 2)};
}

// Ticket Order — the language's own sort.
Object? ticketOrder(Map<String, Object?> input) => ints(input['tickets'])..sort();

Map<String, Object?> ticketOrderSample(Random r) => {'tickets': randomInts(r, between(r, 0, 10), 0, 50)};

// Rope Joining — always join the two shortest, found by sorting again.
Object? ropeJoining(Map<String, Object?> input) {
  final ropes = ints(input['ropes']);
  var cost = 0;
  while (ropes.length > 1) {
    ropes.sort();
    final joined = ropes.removeAt(0) + ropes.removeAt(0);
    cost += joined;
    ropes.add(joined);
  }
  return cost;
}

Map<String, Object?> ropeJoiningSample(Random r) => {'ropes': randomInts(r, between(r, 0, 8), 1, 20)};

// Last Stone — smash the two heaviest, found by sorting again.
Object? lastStone(Map<String, Object?> input) {
  final stones = ints(input['stones']);
  while (stones.length > 1) {
    stones.sort();
    final x = stones.removeLast();
    final y = stones.removeLast();
    if (x != y) stones.add(x - y);
  }
  return stones.isEmpty ? 0 : stones.single;
}

Map<String, Object?> lastStoneSample(Random r) => {'stones': randomInts(r, between(r, 1, 8), 1, 12)};

// Seat Desk — a list of free flags, scanned from seat 1 for every booking.
Object? seatDesk(Map<String, Object?> input) {
  final free = List.filled(integer(input['seats']) + 1, true);
  final handed = <int>[];
  for (final request in ints(input['requests'])) {
    if (request == 0) {
      final seat = free.indexWhere((f) => f, 1);
      free[seat] = false;
      handed.add(seat);
    } else {
      free[request] = true;
    }
  }
  return handed;
}

Map<String, Object?> seatDeskSample(Random r) {
  final seats = between(r, 1, 6);
  final booked = <int>{};
  final requests = <int>[];
  for (var i = between(r, 1, 10); i > 0; i--) {
    if (booked.isNotEmpty && r.nextInt(3) == 0) {
      final back = booked.elementAt(r.nextInt(booked.length));
      booked.remove(back);
      requests.add(back);
    } else if (booked.length < seats) {
      var seat = 1;
      while (booked.contains(seat)) {
        seat++;
      }
      booked.add(seat);
      requests.add(0);
    }
  }
  return {'seats': seats, 'requests': requests};
}

// Meeting Rooms — every start and end in time order (an end first when they
// meet), counting the meetings under way.
Object? meetingRooms(Map<String, Object?> input) {
  final starts = ints(input['starts']);
  final ends = ints(input['ends']);
  final events = [
    for (final s in starts) (s, 1),
    for (final e in ends) (e, -1),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  var now = 0;
  var most = 0;
  for (final (_, change) in events) {
    now += change;
    most = max(most, now);
  }
  return most;
}

Map<String, Object?> meetingRoomsSample(Random r) {
  final n = between(r, 0, 7);
  final starts = sortedInts(r, n, 0, 20);
  return {
    'starts': starts,
    'ends': [for (final s in starts) s + between(r, 1, 8)],
  };
}

// Podium Place — sort, read the k-th largest.
Object? podiumPlace(Map<String, Object?> input) {
  final readings = ints(input['readings'])..sort((a, b) => b.compareTo(a));
  return readings[integer(input['k']) - 1];
}

Map<String, Object?> podiumPlaceSample(Random r) {
  final readings = randomInts(r, between(r, 1, 12), 0, 99);
  return {'readings': readings, 'k': between(r, 1, min(10, readings.length))};
}

// Running Median — sort the numbers so far after every new one.
Object? runningMedian(Map<String, Object?> input) {
  final seen = <int>[];
  return [
    for (final x in ints(input['stream'])) (seen..add(x)..sort())[(seen.length - 1) ~/ 2],
  ];
}

Map<String, Object?> runningMedianSample(Random r) => {'stream': randomInts(r, between(r, 0, 12), -20, 20)};

// --- second batch ---

// Halving Piles — find the biggest pile by sorting before every turn.
Object? halvingPiles(Map<String, Object?> input) {
  final piles = ints(input['piles']);
  for (var turn = integer(input['k']); turn > 0; turn--) {
    piles.sort();
    piles.last -= piles.last ~/ 2;
  }
  return piles.fold<int>(0, (a, b) => a + b);
}

Map<String, Object?> halvingPilesSample(Random r) => {'piles': randomInts(r, between(r, 1, 6), 1, 40), 'k': between(r, 0, 8)};

// Deadline Jobs — the best-paid jobs first, each on the latest free day it
// can still use.
Object? deadlineJobs(Map<String, Object?> input) {
  final deadlines = ints(input['deadlines']);
  final pays = ints(input['pays']);
  final order = [for (var i = 0; i < pays.length; i++) i]..sort((a, b) => pays[b].compareTo(pays[a]));
  final taken = <int>{};
  var total = 0;
  for (final job in order) {
    for (var day = deadlines[job]; day >= 1; day--) {
      if (taken.add(day)) {
        total += pays[job];
        break;
      }
    }
  }
  return total;
}

Map<String, Object?> deadlineJobsSample(Random r) {
  final n = between(r, 0, 7);
  return {'deadlines': sortedInts(r, n, 1, 4), 'pays': randomInts(r, n, 1, 20)};
}

// Bricks and Ladders — the furthest building whose climbs fit: the biggest
// climbs get the ladders, the rest must fit in the bricks.
Object? bricksLadders(Map<String, Object?> input) {
  final heights = ints(input['heights']);
  final bricks = integer(input['bricks']);
  final ladders = integer(input['ladders']);
  var furthest = 0;
  for (var j = 1; j < heights.length; j++) {
    final climbs = [
      for (var i = 0; i < j; i++)
        if (heights[i + 1] > heights[i]) heights[i + 1] - heights[i],
    ]..sort((a, b) => b.compareTo(a));
    final needed = climbs.skip(ladders).fold<int>(0, (a, b) => a + b);
    if (needed > bricks) break;
    furthest = j;
  }
  return furthest;
}

Map<String, Object?> bricksLaddersSample(Random r) =>
    {'heights': randomInts(r, between(r, 1, 8), 1, 20), 'bricks': between(r, 0, 15), 'ladders': between(r, 0, 2)};

// Print Shop — at every free moment, scan the jobs that have arrived for the
// fewest pages (the earlier job on a tie).
Object? printShop(Map<String, Object?> input) {
  final arrive = ints(input['arrive']);
  final pages = ints(input['pages']);
  final done = List.filled(arrive.length, false);
  final order = <int>[];
  var time = 0;
  while (order.length < arrive.length) {
    int? pick;
    for (var j = 0; j < arrive.length; j++) {
      if (!done[j] && arrive[j] <= time && (pick == null || pages[j] < pages[pick])) pick = j;
    }
    if (pick == null) {
      time = [for (var j = 0; j < arrive.length; j++) if (!done[j]) arrive[j]].reduce(min);
      continue;
    }
    done[pick] = true;
    order.add(pick);
    time += pages[pick];
  }
  return order;
}

Map<String, Object?> printShopSample(Random r) {
  final n = between(r, 0, 7);
  return {'arrive': sortedInts(r, n, 0, 15), 'pages': randomInts(r, n, 1, 6)};
}

// Factory Codes — three pointers into the codes found so far.
Object? factoryCodes(Map<String, Object?> input) {
  final n = integer(input['n']);
  final codes = [1];
  var i2 = 0, i3 = 0, i5 = 0;
  while (codes.length < n) {
    final next = min(codes[i2] * 2, min(codes[i3] * 3, codes[i5] * 5));
    codes.add(next);
    if (next == codes[i2] * 2) i2++;
    if (next == codes[i3] * 3) i3++;
    if (next == codes[i5] * 5) i5++;
  }
  return codes[n - 1];
}

Map<String, Object?> factoryCodesSample(Random r) => {'n': between(r, 1, 60)};

// Fuel Stops — the farthest the car can get with exactly t stops, station by
// station (a table, no heap).
Object? fuelStops(Map<String, Object?> input) {
  final target = integer(input['target']);
  final at = ints(input['at']);
  final gives = ints(input['gives']);
  final reach = List.filled(at.length + 1, -1)..[0] = integer(input['fuel']);
  for (var i = 0; i < at.length; i++) {
    for (var t = i; t >= 0; t--) {
      if (reach[t] >= at[i]) reach[t + 1] = max(reach[t + 1], reach[t] + gives[i]);
    }
  }
  for (var t = 0; t <= at.length; t++) {
    if (reach[t] >= target) return t;
  }
  return -1;
}

Map<String, Object?> fuelStopsSample(Random r) {
  final target = between(r, 10, 60);
  final at = {for (var i = between(r, 0, 5); i > 0; i--) between(r, 1, target - 1)}.toList()..sort();
  return {
    'target': target,
    'fuel': between(r, 1, 30),
    'at': at,
    'gives': randomInts(r, at.length, 1, 25),
  };
}

// Cheapest Crossing — relax every square from its neighbours until nothing
// improves (no heap, no order).
Object? cheapestCrossing(Map<String, Object?> input) {
  final grid = intRows(input['grid']);
  final rows = grid.length;
  final cols = grid.first.length;
  const far = 1 << 40;
  final best = List.generate(rows, (_) => List.filled(cols, far));
  best[0][0] = grid[0][0];
  var changed = true;
  while (changed) {
    changed = false;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nc < 0 || nr >= rows || nc >= cols || best[nr][nc] == far) continue;
          if (best[nr][nc] + grid[r][c] < best[r][c]) {
            best[r][c] = best[nr][nc] + grid[r][c];
            changed = true;
          }
        }
      }
    }
  }
  return best[rows - 1][cols - 1];
}

Map<String, Object?> cheapestCrossingSample(Random r) {
  final rows = between(r, 1, 5);
  final cols = between(r, 1, 5);
  return {
    'grid': [for (var i = 0; i < rows; i++) randomInts(r, cols, 1, 9)],
  };
}

const heapOracles = {
  'top_scores': Oracle(id: 'top_scores', solve: topScores, sample: topScoresSample),
  'ticket_order': Oracle(id: 'ticket_order', solve: ticketOrder, sample: ticketOrderSample),
  'rope_joining': Oracle(id: 'rope_joining', solve: ropeJoining, sample: ropeJoiningSample),
  'last_stone': Oracle(id: 'last_stone', solve: lastStone, sample: lastStoneSample),
  'seat_desk': Oracle(id: 'seat_desk', solve: seatDesk, sample: seatDeskSample),
  'meeting_rooms': Oracle(id: 'meeting_rooms', solve: meetingRooms, sample: meetingRoomsSample),
  'podium_place': Oracle(id: 'podium_place', solve: podiumPlace, sample: podiumPlaceSample),
  'running_median': Oracle(id: 'running_median', solve: runningMedian, sample: runningMedianSample),
  'halving_piles': Oracle(id: 'halving_piles', solve: halvingPiles, sample: halvingPilesSample),
  'deadline_jobs': Oracle(id: 'deadline_jobs', solve: deadlineJobs, sample: deadlineJobsSample),
  'bricks_ladders': Oracle(id: 'bricks_ladders', solve: bricksLadders, sample: bricksLaddersSample),
  'print_shop': Oracle(id: 'print_shop', solve: printShop, sample: printShopSample),
  'factory_codes': Oracle(id: 'factory_codes', solve: factoryCodes, sample: factoryCodesSample),
  'fuel_stops': Oracle(id: 'fuel_stops', solve: fuelStops, sample: fuelStopsSample),
  'cheapest_crossing': Oracle(id: 'cheapest_crossing', solve: cheapestCrossing, sample: cheapestCrossingSample),
};
