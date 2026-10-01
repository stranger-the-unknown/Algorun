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

const heapOracles = {
  'top_scores': Oracle(id: 'top_scores', solve: topScores, sample: topScoresSample),
  'ticket_order': Oracle(id: 'ticket_order', solve: ticketOrder, sample: ticketOrderSample),
  'rope_joining': Oracle(id: 'rope_joining', solve: ropeJoining, sample: ropeJoiningSample),
  'last_stone': Oracle(id: 'last_stone', solve: lastStone, sample: lastStoneSample),
  'seat_desk': Oracle(id: 'seat_desk', solve: seatDesk, sample: seatDeskSample),
  'meeting_rooms': Oracle(id: 'meeting_rooms', solve: meetingRooms, sample: meetingRoomsSample),
  'podium_place': Oracle(id: 'podium_place', solve: podiumPlace, sample: podiumPlaceSample),
  'running_median': Oracle(id: 'running_median', solve: runningMedian, sample: runningMedianSample),
};
