import 'dart:collection';
import 'dart:math';

import 'oracle.dart';

// L2, world 12 second batch. The references recurse; these answers come
// another way: a closed form, bit masks, iteration, an in-order walk, BFS
// with a queue, modPow, every path explored on a copy, and a table over
// sets of guests.

// Digit Root — the closed form 1 + (n - 1) mod 9.
Object? digitRoot(Map<String, Object?> input) {
  final n = integer(input['n']);
  return n == 0 ? 0 : 1 + (n - 1) % 9;
}

Map<String, Object?> digitRootSample(Random r) => {'n': r.nextBool() ? between(r, 0, 120) : between(r, 0, 999999999)};

// Lucky Picks — every subset of 1..9 as a bit mask.
Object? luckyPicks(Map<String, Object?> input) {
  final k = integer(input['k']);
  final total = integer(input['total']);
  var count = 0;
  for (var mask = 0; mask < 1 << 9; mask++) {
    var size = 0;
    var sum = 0;
    for (var d = 1; d <= 9; d++) {
      if (mask & (1 << (d - 1)) != 0) {
        size++;
        sum += d;
      }
    }
    if (size == k && sum == total) count++;
  }
  return count;
}

Map<String, Object?> luckyPicksSample(Random r) => {'k': between(r, 0, 5), 'total': between(r, 0, 30)};

// Lantern Rows — patterns ending off / on, row by row.
Object? lanternRows(Map<String, Object?> input) {
  var off = 1;
  var on = 0;
  for (var i = 0; i < integer(input['n']); i++) {
    final nextOff = off + on;
    on = off;
    off = nextOff;
  }
  return off + on;
}

Map<String, Object?> lanternRowsSample(Random r) => {'n': between(r, 0, 14)};

// Catalogue Check — the labels in order (left, node, right) must rise.
Object? catalogueCheck(Map<String, Object?> input) {
  final labels = <int>[];
  void walk(TreeView? t) {
    if (t == null) return;
    walk(t.left);
    labels.add(t.value);
    walk(t.right);
  }

  walk(TreeView.of(input['root']));
  for (var i = 1; i < labels.length; i++) {
    if (labels[i] <= labels[i - 1]) return false;
  }
  return true;
}

Map<String, Object?> catalogueCheckSample(Random r) {
  // Half the time a real search tree, half the time any tree.
  if (r.nextBool()) return {'root': treeJson(randomTree(r, between(r, 0, 9), 1, 30))};
  TreeView? insert(TreeView? t, int v) => t == null
      ? TreeView(v, null, null)
      : v < t.value
          ? TreeView(t.value, insert(t.left, v), t.right)
          : TreeView(t.value, t.left, insert(t.right, v));
  TreeView? root;
  for (final v in ({for (var i = between(r, 0, 9); i > 0; i--) between(r, 1, 30)}.toList()..shuffle(r))) {
    root = insert(root, v);
  }
  return {'root': treeJson(root)};
}

// Island Size — breadth-first search with a queue on a copy of the map.
Object? islandSize(Map<String, Object?> input) {
  final grid = intRows(input['grid']);
  final r0 = integer(input['row']);
  final c0 = integer(input['col']);
  if (grid[r0][c0] == 0) return 0;
  final seen = {(r0, c0)};
  final queue = Queue.of([(r0, c0)]);
  while (queue.isNotEmpty) {
    final (r, c) = queue.removeFirst();
    for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nc < 0 || nr >= grid.length || nc >= grid[nr].length) continue;
      if (grid[nr][nc] == 1 && seen.add((nr, nc))) queue.add((nr, nc));
    }
  }
  return seen.length;
}

Map<String, Object?> islandSizeSample(Random r) {
  final rows = between(r, 1, 5);
  final cols = between(r, 1, 5);
  return {
    'grid': [for (var i = 0; i < rows; i++) randomInts(r, cols, 0, 1)],
    'row': r.nextInt(rows),
    'col': r.nextInt(cols),
  };
}

// Power Steps — the language's own modular power.
Object? powerSteps(Map<String, Object?> input) => integer(input['base']).modPow(integer(input['exp']), 10000);

Map<String, Object?> powerStepsSample(Random r) => {'base': between(r, 0, 9999), 'exp': between(r, 0, 60)};

// Rabbit Generations — month by month.
Object? rabbitMonths(Map<String, Object?> input) {
  var a = 0;
  var b = 1;
  for (var i = 0; i < integer(input['n']); i++) {
    final c = a + b;
    a = b;
    b = c;
  }
  return a;
}

Map<String, Object?> rabbitMonthsSample(Random r) => {'n': between(r, 0, 20)};

// Maze Paths — every simple path explored with an explicit stack of states.
Object? mazePaths(Map<String, Object?> input) {
  final grid = intRows(input['maze']);
  final rows = grid.length;
  final cols = grid.first.length;
  if (grid[0][0] == 0 || grid[rows - 1][cols - 1] == 0) return 0;
  var count = 0;
  final stack = <(int, int, Set<(int, int)>)>[(0, 0, {(0, 0)})];
  while (stack.isNotEmpty) {
    final (r, c, path) = stack.removeLast();
    if (r == rows - 1 && c == cols - 1) {
      count++;
      continue;
    }
    for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
      if (grid[nr][nc] == 1 && !path.contains((nr, nc))) stack.add((nr, nc, {...path, (nr, nc)}));
    }
  }
  return count;
}

Map<String, Object?> mazePathsSample(Random r) {
  final rows = between(r, 1, 3);
  final cols = between(r, 1, 3);
  return {
    'maze': [
      for (var i = 0; i < rows; i++) [for (var j = 0; j < cols; j++) r.nextInt(4) == 0 ? 0 : 1],
    ],
  };
}

// Seating Plan — orders counted over sets of seated guests (bit masks):
// ways[mask][last] = orders of the guests in mask that end with last.
Object? seatingPlan(Map<String, Object?> input) {
  final clash = intRows(input['clash']);
  final n = clash.length;
  final ways = List.generate(1 << n, (_) => List.filled(n, 0));
  for (var g = 0; g < n; g++) {
    ways[1 << g][g] = 1;
  }
  for (var mask = 1; mask < 1 << n; mask++) {
    for (var last = 0; last < n; last++) {
      final here = ways[mask][last];
      if (here == 0) continue;
      for (var g = 0; g < n; g++) {
        if (mask & (1 << g) == 0 && clash[last][g] == 0) ways[mask | (1 << g)][g] += here;
      }
    }
  }
  return ways[(1 << n) - 1].fold<int>(0, (a, b) => a + b);
}

Map<String, Object?> seatingPlanSample(Random r) {
  final n = between(r, 1, 5);
  final clash = List.generate(n, (_) => List.filled(n, 0));
  for (var a = 0; a < n; a++) {
    for (var b = a + 1; b < n; b++) {
      if (r.nextInt(10) < 3) clash[a][b] = clash[b][a] = 1;
    }
  }
  return {'clash': clash};
}

const batch6Oracles = {
  'digit_root': Oracle(id: 'digit_root', solve: digitRoot, sample: digitRootSample),
  'lucky_picks': Oracle(id: 'lucky_picks', solve: luckyPicks, sample: luckyPicksSample),
  'lantern_rows': Oracle(id: 'lantern_rows', solve: lanternRows, sample: lanternRowsSample),
  'catalogue_check': Oracle(id: 'catalogue_check', solve: catalogueCheck, sample: catalogueCheckSample),
  'island_size': Oracle(id: 'island_size', solve: islandSize, sample: islandSizeSample),
  'power_steps': Oracle(id: 'power_steps', solve: powerSteps, sample: powerStepsSample),
  'rabbit_months': Oracle(id: 'rabbit_months', solve: rabbitMonths, sample: rabbitMonthsSample),
  'maze_paths': Oracle(id: 'maze_paths', solve: mazePaths, sample: mazePathsSample),
  'seating_plan': Oracle(id: 'seating_plan', solve: seatingPlan, sample: seatingPlanSample),
};
