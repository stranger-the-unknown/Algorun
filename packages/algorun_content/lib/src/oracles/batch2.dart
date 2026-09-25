import 'dart:math';

import 'oracle.dart';

// --- arrays -----------------------------------------------------------------

Object? firstDescent(Map<String, Object?> input) {
  final a = ints(input['values']);
  for (var i = 1; i < a.length; i++) {
    if (a[i] < a[i - 1]) return i;
  }
  return -1;
}

Map<String, Object?> firstDescentSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), -5, 5)};

Object? secondHighest(Map<String, Object?> input) {
  // By the definition: the distinct scores, highest first; take the second.
  final distinct = ints(input['values']).toSet().toList()..sort((a, b) => b.compareTo(a));
  return distinct.length < 2 ? -1 : distinct[1];
}

Map<String, Object?> secondHighestSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), -4, 6)};

Object? evenPrefixes(Map<String, Object?> input) {
  final a = ints(input['values']);
  var sum = 0;
  var count = 1;
  for (final v in a) {
    sum += v;
    if (sum % 2 == 0) count++;
  }
  return count;
}

Map<String, Object?> evenPrefixesSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), -3, 3)};

Object? nestedDistinct(Map<String, Object?> input) => ints(input['values']).toSet().length;

Map<String, Object?> nestedDistinctSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), 0, 4)};

Object? maxProductTwo(Map<String, Object?> input) {
  final a = ints(input['values']);
  if (a.length < 2) return 0;
  var best = a[0] * a[1];
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      final product = a[i] * a[j];
      if (product > best) best = product;
    }
  }
  return best;
}

Map<String, Object?> maxProductTwoSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), -6, 6)};

Object? pairSumCount(Map<String, Object?> input) {
  // Every pair of positions, one by one.
  final a = ints(input['values']);
  final target = integer(input['target']);
  var count = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      if (a[i] + a[j] == target) count++;
    }
  }
  return count;
}

Map<String, Object?> pairSumCountSample(Random r) => {
      'values': randomInts(r, between(r, 0, 8), -3, 4),
      'target': between(r, -2, 6),
    };

Object? sameValueSpan(Map<String, Object?> input) {
  // Every pair of equal codes, one by one.
  final a = ints(input['values']);
  var best = -1;
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      if (a[i] == a[j] && j - i > best) best = j - i;
    }
  }
  return best;
}

Map<String, Object?> sameValueSpanSample(Random r) =>
    {'values': randomInts(r, between(r, 0, 8), 0, 3)};

Object? sharedValues(Map<String, Object?> input) {
  final right = ints(input['right']).toSet();
  return ints(input['left']).toSet().where(right.contains).length;
}

Map<String, Object?> sharedValuesSample(Random r) => {
      'left': randomInts(r, between(r, 0, 6), 0, 4),
      'right': randomInts(r, between(r, 0, 6), 0, 4),
    };

Object? exactGaps(Map<String, Object?> input) {
  // Every pair of markers, one by one.
  final a = ints(input['values']);
  final gap = integer(input['gap']);
  var count = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      if (a[j] - a[i] == gap) count++;
    }
  }
  return count;
}

Map<String, Object?> exactGapsSample(Random r) {
  final a = sortedInts(r, between(r, 0, 8), 0, 12);
  final strict = <int>[];
  for (final v in a) {
    if (strict.isEmpty || v > strict.last) strict.add(v);
  }
  return {'values': strict, 'gap': between(r, 1, 4)};
}

Object? pairsUnder(Map<String, Object?> input) {
  // Every pair of positions, one by one.
  final a = ints(input['values']);
  final limit = integer(input['limit']);
  var count = 0;
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      if (a[i] + a[j] <= limit) count++;
    }
  }
  return count;
}

Map<String, Object?> pairsUnderSample(Random r) => {
      'values': sortedInts(r, between(r, 0, 8), -2, 8),
      'limit': between(r, 0, 10),
    };

Object? sortedUnion(Map<String, Object?> input) =>
    {...ints(input['left']), ...ints(input['right'])}.length;

Map<String, Object?> sortedUnionSample(Random r) => {
      'left': sortedInts(r, between(r, 0, 6), 0, 6),
      'right': sortedInts(r, between(r, 0, 6), 0, 6),
    };

Object? closestGap(Map<String, Object?> input) {
  final a = ints(input['values']);
  final target = integer(input['target']);
  var best = (a[0] + a[1] - target).abs();
  for (var i = 0; i < a.length; i++) {
    for (var j = i + 1; j < a.length; j++) {
      final d = (a[i] + a[j] - target).abs();
      if (d < best) best = d;
    }
  }
  return best;
}

Map<String, Object?> closestGapSample(Random r) {
  final a = sortedInts(r, between(r, 2, 8), -4, 8);
  return {'values': a, 'target': between(r, -2, 10)};
}

Object? windowsAtLeast(Map<String, Object?> input) {
  // Every window summed from scratch.
  final a = ints(input['values']);
  final width = integer(input['width']);
  final goal = integer(input['goal']);
  if (width <= 0 || width > a.length) return 0;
  var count = 0;
  for (var start = 0; start + width <= a.length; start++) {
    var sum = 0;
    for (var k = start; k < start + width; k++) {
      sum += a[k];
    }
    if (sum >= goal) count++;
  }
  return count;
}

Map<String, Object?> windowsAtLeastSample(Random r) {
  final a = randomInts(r, between(r, 0, 8), 0, 5);
  return {'values': a, 'width': between(r, 1, a.isEmpty ? 1 : a.length), 'goal': between(r, 0, 8)};
}

Object? oneDropout(Map<String, Object?> input) {
  // Every stretch, counting its zeros.
  final a = ints(input['values']);
  var best = 0;
  for (var left = 0; left < a.length; left++) {
    var zeros = 0;
    for (var right = left; right < a.length; right++) {
      if (a[right] == 0) zeros++;
      if (zeros > 1) break;
      if (right - left + 1 > best) best = right - left + 1;
    }
  }
  return best;
}

Map<String, Object?> oneDropoutSample(Random r) =>
    {'values': [for (var i = 0; i < between(r, 0, 10); i++) r.nextInt(2)]};

Object? peakWindows(Map<String, Object?> input) {
  final a = ints(input['values']);
  final width = integer(input['width']);
  if (width <= 0 || width > a.length) return 0;
  var sum = 0;
  for (var start = 0; start + width <= a.length; start++) {
    var m = a[start];
    for (var k = 1; k < width; k++) {
      if (a[start + k] > m) m = a[start + k];
    }
    sum += m;
  }
  return sum;
}

Map<String, Object?> peakWindowsSample(Random r) {
  final a = randomInts(r, between(r, 0, 8), 0, 9);
  return {'values': a, 'width': a.isEmpty ? 1 : between(r, 1, a.length)};
}

// --- queue, stack -----------------------------------------------------------

Object? counterSum(Map<String, Object?> input) {
  final actions = ints(input['actions']);
  final line = <int>[];
  var sum = 0;
  for (final a in actions) {
    if (a > 0) {
      line.add(a);
    } else if (a == 0 && line.isNotEmpty) {
      sum += line.removeAt(0);
    }
  }
  return sum;
}

Map<String, Object?> counterSumSample(Random r) => {
      'actions': [for (var i = 0; i < between(r, 0, 8); i++) r.nextBool() ? 0 : between(r, 1, 6)],
    };

Object? josephusLine(Map<String, Object?> input) {
  final n = integer(input['people']);
  final k = integer(input['count']);
  final line = [for (var i = 1; i <= n; i++) i];
  var left = n;
  while (left > 1) {
    for (var t = 0; t < k - 1; t++) {
      line.add(line.removeAt(0));
    }
    line.removeAt(0);
    left--;
  }
  return line.first;
}

Map<String, Object?> josephusLineSample(Random r) =>
    {'people': between(r, 1, 8), 'count': between(r, 1, 4)};

Object? ticketMinutes(Map<String, Object?> input) {
  // The line itself, one minute at a time.
  final left = ints(input['tickets']);
  final person = integer(input['person']);
  final line = [for (var i = 0; i < left.length; i++) i];
  var minute = 0;
  while (true) {
    final front = line.removeAt(0);
    left[front]--;
    minute++;
    if (front == person && left[front] == 0) return minute;
    if (left[front] > 0) line.add(front);
  }
}

Map<String, Object?> ticketMinutesSample(Random r) {
  final n = between(r, 1, 6);
  return {'tickets': randomInts(r, n, 1, 5), 'person': r.nextInt(n)};
}

Object? stackSorted(Map<String, Object?> input) {
  // Search every sequence of pushes and pops.
  final want = ints(input['want']);
  final n = want.length;
  final tried = <String>{};
  bool go(int next, List<int> stack, int out) {
    if (out == n) return true;
    if (!tried.add('$next|$out|${stack.join(',')}')) return false;
    if (stack.isNotEmpty && stack.last == want[out] && go(next, stack.sublist(0, stack.length - 1), out + 1)) {
      return true;
    }
    return next <= n && go(next + 1, [...stack, next], out);
  }

  return go(1, const [], 0);
}

Map<String, Object?> stackSortedSample(Random r) {
  final n = between(r, 0, 6);
  final want = [for (var i = 1; i <= n; i++) i]..shuffle(r);
  return {'want': want};
}

// --- linked lists -----------------------------------------------------------

Object? tailLamp(Map<String, Object?> input) {
  final values = chainValues(input['head']);
  return values.isEmpty ? -1 : values.last;
}

Map<String, Object?> tailLampSample(Random r) =>
    {'head': chainJson(randomInts(r, between(r, 0, 8), -5, 5))};

Object? coldCars(Map<String, Object?> input) {
  final limit = integer(input['limit']);
  return chainValues(input['head']).where((v) => v < limit).length;
}

Map<String, Object?> coldCarsSample(Random r) => {
      'head': chainJson(randomInts(r, between(r, 0, 8), -4, 4)),
      'limit': between(r, -2, 3),
    };

Object? namedCar(Map<String, Object?> input) {
  final target = integer(input['target']);
  return chainValues(input['head']).contains(target);
}

Map<String, Object?> namedCarSample(Random r) => {
      'head': chainJson(randomInts(r, between(r, 0, 8), 0, 4)),
      'target': between(r, 0, 4),
    };

Object? endGap(Map<String, Object?> input) {
  final values = chainValues(input['head']);
  if (values.length < 2) return 0;
  return values.last - values.first;
}

Map<String, Object?> endGapSample(Random r) =>
    {'head': chainJson(randomInts(r, between(r, 0, 8), -4, 4))};

Object? risingLinks(Map<String, Object?> input) {
  final values = chainValues(input['head']);
  var count = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] > values[i - 1]) count++;
  }
  return count;
}

Map<String, Object?> risingLinksSample(Random r) =>
    {'head': chainJson(randomInts(r, between(r, 0, 8), -3, 3))};

// --- trees ------------------------------------------------------------------

int _spine(TreeView? node, bool left) {
  var count = 0;
  var sum = 0;
  while (node != null) {
    count++;
    sum += node.value;
    node = left ? node.left : node.right;
  }
  return left ? count : sum;
}

Object? leftVine(Map<String, Object?> input) => _spine(TreeView.of(input['root']), true);

Object? rightMarks(Map<String, Object?> input) => _spine(TreeView.of(input['root']), false);

Map<String, Object?> _treeSample(Random r) =>
    {'root': treeJson(randomTree(r, between(r, 0, 7), -3, 3))};

Object? loneTree(Map<String, Object?> input) {
  final root = TreeView.of(input['root']);
  return root != null && root.leaf;
}

int _countNodes(TreeView? node) => node == null ? 0 : 1 + _countNodes(node.left) + _countNodes(node.right);

Object? nodeCensus(Map<String, Object?> input) => _countNodes(TreeView.of(input['root']));

int _countLeaves(TreeView? node) {
  if (node == null) return 0;
  if (node.leaf) return 1;
  return _countLeaves(node.left) + _countLeaves(node.right);
}

Object? leafCensus(Map<String, Object?> input) => _countLeaves(TreeView.of(input['root']));

Object? lowestLeaf(Map<String, Object?> input) {
  int? best;
  void walk(TreeView? node) {
    if (node == null) return;
    if (node.leaf) {
      if (best == null || node.value < best!) best = node.value;
    } else {
      walk(node.left);
      walk(node.right);
    }
  }

  walk(TreeView.of(input['root']));
  return best ?? -1;
}

// --- graphs -----------------------------------------------------------------

Object? platformDoors(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  return (adj[integer(input['station'])] ?? const []).length;
}

Map<String, Object?> platformDoorsSample(Random r) {
  final n = between(r, 1, 5);
  return {'roads': graphJson(randomDigraph(r, n, 2)), 'station': r.nextInt(n)};
}

Object? directHop(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  final goal = integer(input['goal']);
  return (adj[integer(input['start'])] ?? const []).contains(goal);
}

Map<String, Object?> directHopSample(Random r) {
  final n = between(r, 1, 5);
  return {'roads': graphJson(randomDigraph(r, n, 2)), 'start': r.nextInt(n), 'goal': r.nextInt(n)};
}

Object? silentStops(Map<String, Object?> input) {
  final adj = adjacency(input['roads']);
  return adj.values.where((n) => n.isEmpty).length;
}

Map<String, Object?> silentStopsSample(Random r) =>
    {'roads': graphJson(randomDigraph(r, between(r, 1, 6), 2))};

List<int> _dfsOrder(Map<int, List<int>> adj, int start) {
  final seen = <int>{start};
  final stack = <int>[start];
  final popped = <int>[];
  while (stack.isNotEmpty) {
    final here = stack.removeLast();
    popped.add(here);
    final next = adj[here] ?? const <int>[];
    for (final n in next) {
      if (seen.add(n)) stack.add(n);
    }
  }
  return popped;
}

Object? scoutReach(Map<String, Object?> input) {
  // Grow the reached set until nothing new appears (no stack, no order).
  final adj = adjacency(input['roads']);
  final reached = <int>{integer(input['start'])};
  var grew = true;
  while (grew) {
    grew = false;
    for (final at in reached.toList()) {
      for (final n in adj[at] ?? const <int>[]) {
        if (reached.add(n)) grew = true;
      }
    }
  }
  return reached.length;
}

Object? scoutLast(Map<String, Object?> input) {
  final order = _dfsOrder(adjacency(input['roads']), integer(input['start']));
  return order.last;
}

Map<String, Object?> _startGraph(Random r) {
  final n = between(r, 1, 6);
  return {'roads': graphJson(randomDigraph(r, n, 2)), 'start': r.nextInt(n)};
}

Object? biggestPatch(Map<String, Object?> input) {
  // Union-find over the rides.
  final adj = adjacency(input['roads']);
  final parent = {for (final n in adj.keys) n: n};
  int root(int n) => parent[n] == n ? n : parent[n] = root(parent[n]!);
  for (final e in adj.entries) {
    for (final m in e.value) {
      parent[root(e.key)] = root(m);
    }
  }
  final sizes = <int, int>{};
  for (final n in adj.keys) {
    sizes[root(n)] = (sizes[root(n)] ?? 0) + 1;
  }
  return sizes.values.fold<int>(0, max);
}

Map<String, Object?> biggestPatchSample(Random r) =>
    {'roads': graphJson(randomUndirected(r, between(r, 1, 6), between(r, 0, 6)))};

/// Hop distances from [start] by relaxing every ride until nothing changes
/// (Bellman-Ford on unit weights), not by a queue.
Map<int, int> _hops(Map<int, List<int>> adj, int start) {
  final dist = <int, int>{start: 0};
  var changed = true;
  while (changed) {
    changed = false;
    for (final e in adj.entries) {
      final here = dist[e.key];
      if (here == null) continue;
      for (final n in e.value) {
        final seen = dist[n];
        if (seen == null || here + 1 < seen) {
          dist[n] = here + 1;
          changed = true;
        }
      }
    }
  }
  return dist;
}

Object? sourceRadius(Map<String, Object?> input) =>
    _hops(adjacency(input['roads']), integer(input['start'])).values.fold<int>(0, max);

Object? lastLayer(Map<String, Object?> input) {
  final dist = _hops(adjacency(input['roads']), integer(input['start'])).values;
  final far = dist.fold<int>(0, max);
  return dist.where((d) => d == far).length;
}

// --- greedy -----------------------------------------------------------------

Object? cookieGifts(Map<String, Object?> input) {
  // A maximum matching of children to cookies that fit (augmenting paths),
  // not the sorted greedy walk.
  final children = ints(input['children']);
  final cookies = ints(input['cookies']);
  final owner = List<int?>.filled(cookies.length, null);
  bool feed(int child, Set<int> tried) {
    for (var c = 0; c < cookies.length; c++) {
      if (cookies[c] < children[child] || !tried.add(c)) continue;
      if (owner[c] == null || feed(owner[c]!, tried)) {
        owner[c] = child;
        return true;
      }
    }
    return false;
  }

  var fed = 0;
  for (var child = 0; child < children.length; child++) {
    if (feed(child, <int>{})) fed++;
  }
  return fed;
}

Map<String, Object?> cookieGiftsSample(Random r) => {
      'children': sortedInts(r, between(r, 0, 6), 1, 8),
      'cookies': sortedInts(r, between(r, 0, 6), 1, 8),
    };

Object? dockOverlap(Map<String, Object?> input) {
  // Count the ships in berth at every moment that matters.
  final starts = ints(input['starts']);
  final ends = ints(input['ends']);
  var best = 0;
  for (final t in {...starts, ...ends}) {
    final inBerth = starts.where((s) => s <= t).length - ends.where((e) => e <= t).length;
    if (inBerth > best) best = inBerth;
  }
  return best;
}

Map<String, Object?> dockOverlapSample(Random r) {
  final n = between(r, 0, 5);
  final starts = sortedInts(r, n, 0, 8);
  final ends = <int>[];
  for (final s in starts) {
    ends.add(s + between(r, 1, 4));
  }
  ends.sort();
  return {'starts': starts, 'ends': ends};
}

Object? leapReach(Map<String, Object?> input) {
  // Every stone reachable by some sequence of leaps.
  final jumps = ints(input['jumps']);
  if (jumps.isEmpty) return false;
  final reached = <int>{0};
  final todo = [0];
  while (todo.isNotEmpty) {
    final at = todo.removeLast();
    for (var d = 1; d <= jumps[at]; d++) {
      if (at + d < jumps.length && reached.add(at + d)) todo.add(at + d);
    }
  }
  return reached.contains(jumps.length - 1);
}

Map<String, Object?> leapReachSample(Random r) =>
    {'jumps': randomInts(r, between(r, 1, 7), 0, 3)};

// --- dp ---------------------------------------------------------------------

Object? plankWays(Map<String, Object?> input) {
  // Count the step sequences themselves.
  int ways(int left) => left < 0 ? 0 : (left == 0 ? 1 : ways(left - 1) + ways(left - 2));
  return ways(integer(input['length']));
}

Map<String, Object?> plankWaysSample(Random r) => {'length': between(r, 0, 12)};

Object? stepToll(Map<String, Object?> input) {
  // Every sequence of jumps from the first stone to the last.
  final costs = ints(input['costs']);
  if (costs.isEmpty) return 0;
  int? best;
  void go(int at, int paid) {
    if (at == costs.length - 1) {
      if (best == null || paid < best!) best = paid;
      return;
    }
    for (final d in const [1, 2]) {
      if (at + d < costs.length) go(at + d, paid + costs[at + d]);
    }
  }

  go(0, costs[0]);
  return best;
}

Map<String, Object?> stepTollSample(Random r) =>
    {'costs': randomInts(r, between(r, 0, 7), 0, 6)};

List<List<int>> _grid(Object? json) => intRows(json);

Object? aisleCost(Map<String, Object?> input) {
  final g = _grid(input['grid']);
  int? best;
  _paths(g, const [(0, 1), (1, 0)], (cells) {
    final sum = cells.fold<int>(0, (s, c) => s + g[c.$1][c.$2]);
    if (best == null || sum < best!) best = sum;
  });
  return best;
}

/// Every path from the top-left to the bottom-right with the given [moves].
void _paths(List<List<int>> g, List<(int, int)> moves, void Function(List<(int, int)>) visit) {
  final rows = g.length;
  final cols = g[0].length;
  void go(int r, int c, List<(int, int)> path) {
    if (r == rows - 1 && c == cols - 1) {
      visit(path);
      return;
    }
    for (final (dr, dc) in moves) {
      if (r + dr < rows && c + dc < cols) go(r + dr, c + dc, [...path, (r + dr, c + dc)]);
    }
  }

  go(0, 0, [(0, 0)]);
}

Map<String, Object?> aisleCostSample(Random r) {
  final rows = between(r, 1, 3);
  final cols = between(r, 1, 3);
  return {
    'grid': [for (var i = 0; i < rows; i++) randomInts(r, cols, 0, 4)],
  };
}

Object? openLanes(Map<String, Object?> input) {
  final g = _grid(input['grid']);
  var count = 0;
  _paths(g, const [(0, 1), (1, 0)], (cells) {
    if (cells.every((c) => g[c.$1][c.$2] == 0)) count++;
  });
  return count;
}

Map<String, Object?> openLanesSample(Random r) {
  final rows = between(r, 1, 3);
  final cols = between(r, 1, 3);
  final grid = [
    for (var i = 0; i < rows; i++) [for (var j = 0; j < cols; j++) r.nextInt(2)],
  ];
  grid[0][0] = 0;
  grid[rows - 1][cols - 1] = 0;
  return {'grid': grid};
}

Object? diagonalHaul(Map<String, Object?> input) {
  final g = _grid(input['grid']);
  int? best;
  _paths(g, const [(0, 1), (1, 0), (1, 1)], (cells) {
    final sum = cells.fold<int>(0, (s, c) => s + g[c.$1][c.$2]);
    if (best == null || sum > best!) best = sum;
  });
  return best;
}

Object? packBins(Map<String, Object?> input) {
  // Every subset of crates.
  final weights = ints(input['weights']);
  final values = ints(input['values']);
  final cap = integer(input['cap']);
  var best = 0;
  for (var mask = 0; mask < 1 << weights.length; mask++) {
    var w = 0;
    var v = 0;
    for (var i = 0; i < weights.length; i++) {
      if (mask >> i & 1 == 1) {
        w += weights[i];
        v += values[i];
      }
    }
    if (w <= cap && v > best) best = v;
  }
  return best;
}

Map<String, Object?> packBinsSample(Random r) {
  final n = between(r, 0, 4);
  return {
    'weights': randomInts(r, n, 1, 4),
    'values': randomInts(r, n, 0, 6),
    'cap': between(r, 0, 7),
  };
}

const batch2Oracles = {
  'first_descent': Oracle(id: 'first_descent', solve: firstDescent, sample: firstDescentSample),
  'second_highest': Oracle(id: 'second_highest', solve: secondHighest, sample: secondHighestSample),
  'even_prefixes': Oracle(id: 'even_prefixes', solve: evenPrefixes, sample: evenPrefixesSample),
  'nested_distinct': Oracle(id: 'nested_distinct', solve: nestedDistinct, sample: nestedDistinctSample),
  'max_product_two': Oracle(id: 'max_product_two', solve: maxProductTwo, sample: maxProductTwoSample),
  'pair_sum_count': Oracle(id: 'pair_sum_count', solve: pairSumCount, sample: pairSumCountSample),
  'same_value_span': Oracle(id: 'same_value_span', solve: sameValueSpan, sample: sameValueSpanSample),
  'shared_values': Oracle(id: 'shared_values', solve: sharedValues, sample: sharedValuesSample),
  'exact_gaps': Oracle(id: 'exact_gaps', solve: exactGaps, sample: exactGapsSample),
  'pairs_under': Oracle(id: 'pairs_under', solve: pairsUnder, sample: pairsUnderSample),
  'sorted_union': Oracle(id: 'sorted_union', solve: sortedUnion, sample: sortedUnionSample),
  'closest_gap': Oracle(id: 'closest_gap', solve: closestGap, sample: closestGapSample),
  'windows_at_least': Oracle(id: 'windows_at_least', solve: windowsAtLeast, sample: windowsAtLeastSample),
  'one_dropout': Oracle(id: 'one_dropout', solve: oneDropout, sample: oneDropoutSample),
  'peak_windows': Oracle(id: 'peak_windows', solve: peakWindows, sample: peakWindowsSample),
  'counter_sum': Oracle(id: 'counter_sum', solve: counterSum, sample: counterSumSample),
  'josephus_line': Oracle(id: 'josephus_line', solve: josephusLine, sample: josephusLineSample),
  'ticket_minutes': Oracle(id: 'ticket_minutes', solve: ticketMinutes, sample: ticketMinutesSample),
  'stack_sorted': Oracle(id: 'stack_sorted', solve: stackSorted, sample: stackSortedSample),
  'tail_lamp': Oracle(id: 'tail_lamp', solve: tailLamp, sample: tailLampSample),
  'cold_cars': Oracle(id: 'cold_cars', solve: coldCars, sample: coldCarsSample),
  'named_car': Oracle(id: 'named_car', solve: namedCar, sample: namedCarSample),
  'end_gap': Oracle(id: 'end_gap', solve: endGap, sample: endGapSample),
  'rising_links': Oracle(id: 'rising_links', solve: risingLinks, sample: risingLinksSample),
  'left_vine': Oracle(id: 'left_vine', solve: leftVine, sample: _treeSample),
  'right_marks': Oracle(id: 'right_marks', solve: rightMarks, sample: _treeSample),
  'lone_tree': Oracle(id: 'lone_tree', solve: loneTree, sample: _treeSample),
  'node_census': Oracle(id: 'node_census', solve: nodeCensus, sample: _treeSample),
  'leaf_census': Oracle(id: 'leaf_census', solve: leafCensus, sample: _treeSample),
  'lowest_leaf': Oracle(id: 'lowest_leaf', solve: lowestLeaf, sample: _treeSample),
  'platform_doors': Oracle(id: 'platform_doors', solve: platformDoors, sample: platformDoorsSample),
  'direct_hop': Oracle(id: 'direct_hop', solve: directHop, sample: directHopSample),
  'silent_stops': Oracle(id: 'silent_stops', solve: silentStops, sample: silentStopsSample),
  'scout_reach': Oracle(id: 'scout_reach', solve: scoutReach, sample: _startGraph),
  'scout_last': Oracle(id: 'scout_last', solve: scoutLast, sample: _startGraph),
  'biggest_patch': Oracle(id: 'biggest_patch', solve: biggestPatch, sample: biggestPatchSample),
  'source_radius': Oracle(id: 'source_radius', solve: sourceRadius, sample: _startGraph),
  'last_layer': Oracle(id: 'last_layer', solve: lastLayer, sample: _startGraph),
  'cookie_gifts': Oracle(id: 'cookie_gifts', solve: cookieGifts, sample: cookieGiftsSample),
  'dock_overlap': Oracle(id: 'dock_overlap', solve: dockOverlap, sample: dockOverlapSample),
  'leap_reach': Oracle(id: 'leap_reach', solve: leapReach, sample: leapReachSample),
  'plank_ways': Oracle(id: 'plank_ways', solve: plankWays, sample: plankWaysSample),
  'step_toll': Oracle(id: 'step_toll', solve: stepToll, sample: stepTollSample),
  'aisle_cost': Oracle(id: 'aisle_cost', solve: aisleCost, sample: aisleCostSample),
  'open_lanes': Oracle(id: 'open_lanes', solve: openLanes, sample: openLanesSample),
  'diagonal_haul': Oracle(id: 'diagonal_haul', solve: diagonalHaul, sample: aisleCostSample),
  'pack_bins': Oracle(id: 'pack_bins', solve: packBins, sample: packBinsSample),
};
