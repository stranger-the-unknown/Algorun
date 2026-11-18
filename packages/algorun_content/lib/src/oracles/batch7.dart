import 'dart:math';

import 'oracle.dart';

// MS16 part 1: Arrays, Hash Maps, Two Pointers. Each answer is a direct
// reading of the puzzle's definition (every board, every seat, every
// arrangement, every run, every lunch, every place across the wall, every
// minute), never the reference's technique.

// The Turned Belt — where the smallest number is, by looking at all of them.
Object? turnedBelt(Map<String, Object?> input) {
  final plates = ints(input['plates']);
  return plates.indexOf(plates.reduce(min));
}

Map<String, Object?> turnedBeltSample(Random r) {
  final n = between(r, 1, 12);
  final sorted = ({for (var i = 0; i < n * 3; i++) between(r, -40, 40)}.toList()..sort()).take(n).toList();
  final at = r.nextInt(sorted.length);
  return {
    'plates': [...sorted.sublist(at), ...sorted.sublist(0, at)],
  };
}

// Coats of Paint — every board asks every shift whether it was painted.
Object? fenceCoats(Map<String, Object?> input) {
  final starts = ints(input['starts']);
  final ends = ints(input['ends']);
  final coats = ints(input['coats']);
  return [
    for (var board = 0; board < integer(input['boards']); board++)
      [
        for (var k = 0; k < starts.length; k++)
          if (starts[k] <= board && board <= ends[k]) coats[k],
      ].fold<int>(0, (a, b) => a + b),
  ];
}

Map<String, Object?> fenceCoatsSample(Random r) {
  final boards = between(r, 1, 10);
  final shifts = between(r, 0, 6);
  final starts = [for (var k = 0; k < shifts; k++) r.nextInt(boards)];
  return {
    'boards': boards,
    'starts': starts,
    // One shift in three runs to the very last board.
    'ends': [for (final s in starts) r.nextInt(3) == 0 ? boards - 1 : between(r, s, boards - 1)],
    'coats': randomInts(r, shifts, 1, 5),
  };
}

// Cheap Seats — every seat counted.
Object? cheapSeats(Map<String, Object?> input) {
  final budget = integer(input['budget']);
  return intRows(input['prices']).expand((row) => row).where((price) => price <= budget).length;
}

Map<String, Object?> cheapSeatsSample(Random r) {
  final rows = between(r, 1, 5);
  final cols = between(r, 1, 5);
  final hall = [for (var i = 0; i < rows; i++) List.filled(cols, 0)];
  for (var i = 0; i < rows; i++) {
    for (var j = 0; j < cols; j++) {
      final floor = max(i > 0 ? hall[i - 1][j] : 5, j > 0 ? hall[i][j - 1] : 5);
      hall[i][j] = floor + r.nextInt(4);
    }
  }
  return {'prices': hall, 'budget': between(r, 3, hall.last.last + 2)};
}

// Tomorrow's Set List — a short list: every arrangement, sorted like a
// dictionary, and the one after tonight's. A long list: keep the longest
// possible beginning, raise the next song by as little as possible, then
// the smallest ending the left-over songs can make.
Object? nextLineup(Map<String, Object?> input) {
  final order = ints(input['order']);
  int compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  if (order.length <= 7) {
    final all = <String, List<int>>{};
    void arrange(List<int> left, List<int> made) {
      if (left.isEmpty) {
        all[made.join(',')] = List.of(made);
        return;
      }
      for (var i = 0; i < left.length; i++) {
        arrange([...left.sublist(0, i), ...left.sublist(i + 1)], [...made, left[i]]);
      }
    }

    arrange(order, []);
    final ranked = all.values.toList()..sort(compare);
    final tonight = ranked.indexWhere((o) => compare(o, order) == 0);
    return ranked[(tonight + 1) % ranked.length];
  }
  for (var keep = order.length - 2; keep >= 0; keep--) {
    final tail = order.sublist(keep + 1);
    final bigger = tail.where((x) => x > order[keep]).toList();
    if (bigger.isEmpty) continue;
    final next = bigger.reduce(min);
    final rest = [...tail, order[keep]]
      ..remove(next)
      ..sort();
    return [...order.sublist(0, keep), next, ...rest];
  }
  return List.of(order)..sort();
}

Map<String, Object?> nextLineupSample(Random r) => {'order': randomInts(r, between(r, 1, 6), 1, between(r, 2, 5))};

// Level Score — every run of goals, counted.
Object? levelScore(Map<String, Object?> input) {
  final goals = ints(input['goals']);
  var best = 0;
  for (var from = 0; from < goals.length; from++) {
    var home = 0;
    for (var to = from; to < goals.length; to++) {
      home += goals[to];
      final length = to - from + 1;
      if (home * 2 == length && length > best) best = length;
    }
  }
  return best;
}

Map<String, Object?> levelScoreSample(Random r) {
  final home = between(r, 20, 80);
  return {
    'goals': [for (var i = between(r, 0, 14); i > 0; i--) r.nextInt(100) < home ? 1 : 0],
  };
}

// The Spy's Cipher — two messages fit when they have the same shape: every
// position names the place where its number first appeared.
Object? spyCipher(Map<String, Object?> input) {
  List<int> shape(List<int> message) => [for (final x in message) message.indexOf(x)];
  final plain = shape(ints(input['plain']));
  final coded = shape(ints(input['coded']));
  for (var i = 0; i < plain.length; i++) {
    if (plain[i] != coded[i]) return false;
  }
  return true;
}

Map<String, Object?> spyCipherSample(Random r) {
  final plain = randomInts(r, between(r, 0, 8), 1, 5);
  final table = [for (var i = 0; i <= 5; i++) i + 10]..shuffle(r);
  final coded = switch (r.nextInt(4)) {
    // A real cipher.
    0 || 1 => [for (final x in plain) table[x]],
    // Two plain numbers fall on one coded number.
    2 => [for (final x in plain) table[x ~/ 2]],
    // One plain number gets two coded numbers.
    _ => [for (var i = 0; i < plain.length; i++) table[plain[i]] + (i == plain.length - 1 ? r.nextInt(2) : 0)],
  };
  return {'plain': plain, 'coded': coded};
}

// Four Shelves — every lunch, one by one.
Object? fourShelves(Map<String, Object?> input) {
  final target = integer(input['target']);
  var lunches = 0;
  for (final a in ints(input['starters'])) {
    for (final b in ints(input['mains'])) {
      for (final c in ints(input['sides'])) {
        for (final d in ints(input['desserts'])) {
          if (a + b + c + d == target) lunches++;
        }
      }
    }
  }
  return lunches;
}

Map<String, Object?> fourShelvesSample(Random r) => {
      'starters': randomInts(r, between(r, 0, 4), 1, 5),
      'mains': randomInts(r, between(r, 0, 4), 1, 5),
      'sides': randomInts(r, between(r, 0, 4), 1, 5),
      'desserts': randomInts(r, between(r, 0, 4), 1, 5),
      'target': between(r, 6, 16),
    };

// One Straight Cut — every place across the wall, and the rows it saws.
Object? plankWall(Map<String, Object?> input) {
  final rows = intRows(input['rows']);
  final joints = [
    for (final row in rows)
      {
        for (var j = 1; j < row.length; j++) row.sublist(0, j).fold<int>(0, (a, b) => a + b),
      },
  ];
  final width = rows.first.fold<int>(0, (a, b) => a + b);
  var fewest = rows.length;
  for (var place = 1; place < width; place++) {
    fewest = min(fewest, joints.where((row) => !row.contains(place)).length);
  }
  return fewest;
}

Map<String, Object?> plankWallSample(Random r) {
  final width = between(r, 1, 9);
  List<int> row() {
    final cuts = {for (var k = between(r, 0, 4); k > 0; k--) between(r, 0, width)}.where((c) => c > 0 && c < width).toList()..sort();
    final edges = [0, ...cuts, width];
    return [for (var i = 1; i < edges.length; i++) edges[i] - edges[i - 1]];
  }

  return {
    'rows': [for (var k = between(r, 1, 5); k > 0; k--) row()],
  };
}

// After the Rain — above every tower, up to the lower of the tallest tower
// on its left and the tallest on its right.
Object? afterRain(Map<String, Object?> input) {
  final towers = ints(input['towers']);
  var water = 0;
  for (var i = 0; i < towers.length; i++) {
    final left = towers.sublist(0, i + 1).reduce(max);
    final right = towers.sublist(i).reduce(max);
    water += min(left, right) - towers[i];
  }
  return water;
}

Map<String, Object?> afterRainSample(Random r) => {'towers': randomInts(r, between(r, 0, 10), 0, between(r, 1, 7))};

// Rod Triangles — every set of three.
Object? rodTriangles(Map<String, Object?> input) {
  final rods = ints(input['rods']);
  var count = 0;
  for (var a = 0; a < rods.length; a++) {
    for (var b = a + 1; b < rods.length; b++) {
      for (var c = b + 1; c < rods.length; c++) {
        if (rods[a] + rods[b] > rods[c]) count++;
      }
    }
  }
  return count;
}

Map<String, Object?> rodTrianglesSample(Random r) => {'rods': sortedInts(r, between(r, 0, 9), 1, between(r, 3, 12))};

// Shared Watch — minute by minute.
Object? sharedWatch(Map<String, Object?> input) {
  Set<int> minutes(List<int> starts, List<int> ends) => {
        for (var k = 0; k < starts.length; k++)
          for (var m = starts[k]; m < ends[k]; m++) m,
      };
  final first = minutes(ints(input['startsA']), ints(input['endsA']));
  final second = minutes(ints(input['startsB']), ints(input['endsB']));
  return first.intersection(second).length;
}

Map<String, Object?> sharedWatchSample(Random r) {
  // Different sorted minutes taken two at a time: watches that neither
  // overlap nor touch.
  (List<int>, List<int>) guard() {
    final marks = ({for (var k = between(r, 0, 5) * 2; k > 0; k--) r.nextInt(30)}.toList()..sort());
    final pairs = marks.length ~/ 2;
    return ([for (var k = 0; k < pairs; k++) marks[2 * k]], [for (var k = 0; k < pairs; k++) marks[2 * k + 1]]);
  }

  final a = guard();
  final b = guard();
  return {'startsA': a.$1, 'endsA': a.$2, 'startsB': b.$1, 'endsB': b.$2};
}

// Far from Zero — the distances, sorted.
Object? farFromZero(Map<String, Object?> input) {
  final far = [for (final x in ints(input['log'])) x.abs()]..sort();
  return far.reversed.toList();
}

Map<String, Object?> farFromZeroSample(Random r) => {'log': sortedInts(r, between(r, 0, 10), -9, 9)};

const Map<String, Oracle> batch7Oracles = {
  'turned_belt': Oracle(id: 'turned_belt', solve: turnedBelt, sample: turnedBeltSample),
  'fence_coats': Oracle(id: 'fence_coats', solve: fenceCoats, sample: fenceCoatsSample),
  'cheap_seats': Oracle(id: 'cheap_seats', solve: cheapSeats, sample: cheapSeatsSample),
  'next_lineup': Oracle(id: 'next_lineup', solve: nextLineup, sample: nextLineupSample),
  'level_score': Oracle(id: 'level_score', solve: levelScore, sample: levelScoreSample),
  'spy_cipher': Oracle(id: 'spy_cipher', solve: spyCipher, sample: spyCipherSample),
  'four_shelves': Oracle(id: 'four_shelves', solve: fourShelves, sample: fourShelvesSample),
  'plank_wall': Oracle(id: 'plank_wall', solve: plankWall, sample: plankWallSample),
  'after_rain': Oracle(id: 'after_rain', solve: afterRain, sample: afterRainSample),
  'rod_triangles': Oracle(id: 'rod_triangles', solve: rodTriangles, sample: rodTrianglesSample),
  'shared_watch': Oracle(id: 'shared_watch', solve: sharedWatch, sample: sharedWatchSample),
  'far_from_zero': Oracle(id: 'far_from_zero', solve: farFromZero, sample: farFromZeroSample),
};
